#include <stdio.h>
#include <stdint.h>
#include <stddef.h>
#include <string.h>

#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/event_groups.h"
#include "freertos/queue.h"

#include "esp_wifi.h"
#include "esp_system.h"
#include "esp_event.h"
#include "esp_log.h"

#include "config_storage.h"
#include "wifi_manager.h"
#include "servo_controller.h"
#include "led_controller.h"
#include "web_server.h"
#include "websocket_client.h"
#include "driver/gpio.h"

#define RESET_BUTTON_PIN GPIO_NUM_0  // GPIO0 - кнопка BOOT на большинстве ESP32

static const char *TAG = "SMARTLIGHT_MAIN";

// Глобальная конфигурация устройства
static device_config_t g_device_config = {0};

// Флаги состояния
static bool g_websocket_started = false;

/**
 * @brief Задача для мониторинга кнопки сброса
 */
static void reset_button_task(void *pvParameters)
{
    // Настраиваем GPIO для кнопки
    gpio_config_t io_conf = {
        .intr_type = GPIO_INTR_DISABLE,
        .mode = GPIO_MODE_INPUT,
        .pin_bit_mask = (1ULL << RESET_BUTTON_PIN),
        .pull_down_en = 0,
        .pull_up_en = 1
    };
    gpio_config(&io_conf);
    
    ESP_LOGI(TAG, "Reset button monitoring task started (GPIO%d)", RESET_BUTTON_PIN);
    
    while (1) {
        // Проверяем нажата ли кнопка (низкий уровень из-за pull-up)
        if (gpio_get_level(RESET_BUTTON_PIN) == 0) {
            ESP_LOGI(TAG, "Reset button pressed, counting...");
            
            int press_time = 0;
            // Считаем время удержания кнопки
            while (gpio_get_level(RESET_BUTTON_PIN) == 0 && press_time < 50) { // Максимум 5 секунд
                vTaskDelay(pdMS_TO_TICKS(100));
                press_time++;
            }
            
            // Если кнопку держали 3+ секунды - сбрасываем конфигурацию
            if (press_time >= 30) { // 30 * 100ms = 3 секунды
                ESP_LOGW(TAG, "Reset button held for 3+ seconds - RESETTING CONFIGURATION!");
                
                // Корректно останавливаем все сервисы
                if (g_websocket_started) {
                    ESP_LOGI(TAG, "Stopping WebSocket client...");
                    websocket_client_stop();
                    websocket_client_deinit();
                    g_websocket_started = false;
                }
                
                // Останавливаем WiFi
                ESP_LOGI(TAG, "Deinitializing WiFi...");
                wifi_manager_deinit();
                
                // Сбрасываем конфигурацию
                ESP_LOGI(TAG, "Clearing device configuration...");
                memset(&g_device_config, 0, sizeof(g_device_config));
                config_storage_save(&g_device_config);
                
                ESP_LOGI(TAG, "Configuration reset complete. Restarting in BLE provisioning mode...");
                vTaskDelay(pdMS_TO_TICKS(1000)); // Даём время для записи в NVS и cleanup
                esp_restart();
            }
        }
        
        vTaskDelay(pdMS_TO_TICKS(100));
    }
}

/**
 * @brief Задача для периодических операций (сервоприводы, heartbeat)
 */
static void periodic_task(void *pvParameters)
{
    TickType_t xLastWakeTime = xTaskGetTickCount();
    const TickType_t xFrequency = pdMS_TO_TICKS(10); // 10ms period
    
    ESP_LOGI(TAG, "Periodic task started");
    
    while (1) {
        // Обновление сервоприводов для плавного движения
        servo_controller_task();
        
        // Отправка heartbeat сообщений через WebSocket
        if (g_websocket_started && websocket_client_is_connected()) {
            websocket_client_heartbeat_task();
        }
        
        vTaskDelayUntil(&xLastWakeTime, xFrequency);
    }
}

/**
 * @brief Задача для мониторинга WiFi и WebSocket подключений
 */
static void connection_monitor_task(void *pvParameters)
{
    TickType_t xLastWakeTime = xTaskGetTickCount();
    const TickType_t xFrequency = pdMS_TO_TICKS(1000); // 1 second period
    
    ESP_LOGI(TAG, "Connection monitor task started");
    
    while (1) {
        // Проверяем состояние WiFi
        wifi_state_t wifi_state = wifi_manager_get_state();
        
        // Логируем состояние каждые 10 секунд
        static int log_counter = 0;
        static bool config_reloaded_after_provisioning = false;
        
        if (++log_counter >= 10) {
            ESP_LOGI(TAG, "Status - WiFi: %s, WebSocket: %s, Config valid: %s, Backend URL: %s",
                (wifi_state == WIFI_STATE_CONNECTED) ? "Connected" : 
                (wifi_state == WIFI_STATE_CONNECTING) ? "Connecting" :
                (wifi_state == WIFI_STATE_FAILED) ? "Failed" : 
                (wifi_state == WIFI_STATE_BLE_PROVISIONING) ? "BLE Provisioning" : "Idle",
                g_websocket_started ? "Started" : "Stopped",
                g_device_config.is_valid ? "Valid" : "Invalid",
                (strlen(g_device_config.backend_url) > 0) ? g_device_config.backend_url : "Not set"
            );
            log_counter = 0;
        }
        
        // Перезагружаем конфигурацию после успешного BLE provisioning
        if (!config_reloaded_after_provisioning && wifi_state == WIFI_STATE_CONNECTED && !g_device_config.is_valid) {
            ESP_LOGI(TAG, "Reloading configuration after BLE provisioning...");
            
            // Ждем чтобы задача config_save_task успела завершиться
            vTaskDelay(pdMS_TO_TICKS(2000)); // 2 секунды задержки
            
            esp_err_t ret = config_storage_load(&g_device_config);
            if (ret == ESP_OK && strlen(g_device_config.wifi_ssid) > 0) {
                ESP_LOGI(TAG, "Configuration reloaded successfully:");
                ESP_LOGI(TAG, "  WiFi SSID: %s", g_device_config.wifi_ssid);
                ESP_LOGI(TAG, "  Device ID: %s", g_device_config.device_id);
                ESP_LOGI(TAG, "  Backend URL: %s", strlen(g_device_config.backend_url) > 0 ? g_device_config.backend_url : "Not set");
                config_reloaded_after_provisioning = true;
            } else {
                ESP_LOGI(TAG, "Configuration still not ready, will retry next cycle");
            }
        }
        
        // Инициализация WebSocket клиента после подключения к WiFi
        if (!g_websocket_started && wifi_state == WIFI_STATE_CONNECTED && 
            g_device_config.is_valid && strlen(g_device_config.backend_url) > 0) {
            ESP_LOGI(TAG, "WiFi connected and backend URL configured, starting WebSocket client...");
            ESP_LOGI(TAG, "Backend URL: %s", g_device_config.backend_url);
            
            esp_err_t ws_ret = websocket_client_init(&g_device_config);
            if (ws_ret == ESP_OK) {
                ws_ret = websocket_client_start();
                if (ws_ret == ESP_OK) {
                    g_websocket_started = true;
                    ESP_LOGI(TAG, "WebSocket client started successfully");
                } else {
                    ESP_LOGE(TAG, "Failed to start WebSocket client: %s", esp_err_to_name(ws_ret));
                }
            } else {
                ESP_LOGE(TAG, "Failed to initialize WebSocket client: %s", esp_err_to_name(ws_ret));
            }
        } else if (!g_websocket_started && wifi_state == WIFI_STATE_CONNECTED) {
            // Логируем почему WebSocket не запускается
            if (!g_device_config.is_valid) {
                ESP_LOGD(TAG, "WebSocket not started: device config invalid");
            } else if (strlen(g_device_config.backend_url) == 0) {
                ESP_LOGD(TAG, "WebSocket not started: backend URL not configured");
            }
        }
        
        // Если WebSocket запущен, но WiFi отключен - останавливаем WebSocket
        if (g_websocket_started && wifi_state != WIFI_STATE_CONNECTED) {
            ESP_LOGW(TAG, "WiFi disconnected, stopping WebSocket client");
            websocket_client_stop();
            websocket_client_deinit();
            g_websocket_started = false;
        }
        
        // Переключение в BLE provisioning режим если соединение не удалось
        if (wifi_state == WIFI_STATE_FAILED) {
            ESP_LOGW(TAG, "WiFi connection failed, starting BLE provisioning mode");
            wifi_manager_start_ble_provisioning();
        }
        
        vTaskDelayUntil(&xLastWakeTime, xFrequency);
    }
}

/**
 * @brief Инициализация всех компонентов системы
 */
static esp_err_t init_system(void)
{
    esp_err_t ret;
    
    // Инициализация конфигурации и хранилища
    ESP_LOGI(TAG, "Initializing configuration storage...");
    ret = config_storage_init();
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Failed to initialize config storage: %s", esp_err_to_name(ret));
        return ret;
    }
    
    // Загружаем конфигурацию
    ret = config_storage_load(&g_device_config);
    if (ret != ESP_OK) {
        ESP_LOGW(TAG, "No configuration found, will start in AP mode for setup: %s", esp_err_to_name(ret));
        g_device_config.is_valid = false;
    }
    
    if (g_device_config.is_valid) {
        ESP_LOGI(TAG, "Configuration loaded:");
        ESP_LOGI(TAG, "  WiFi SSID: %s", g_device_config.wifi_ssid);
        ESP_LOGI(TAG, "  Backend URL: %s", g_device_config.backend_url);
        ESP_LOGI(TAG, "  Device ID: %s", g_device_config.device_id);
    } else {
        ESP_LOGW(TAG, "Configuration invalid, will start in AP mode for setup");
    }
    
    // Инициализация WiFi менеджера
    ESP_LOGI(TAG, "Initializing WiFi manager...");
    ret = wifi_manager_init(&g_device_config);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Failed to initialize WiFi manager: %s", esp_err_to_name(ret));
        return ret;
    }
    
    // Проверяем, нужно ли запускать provisioning
    if (!g_device_config.is_valid) {
        ESP_LOGI(TAG, "No valid configuration, starting BLE provisioning...");
        ret = wifi_manager_start_ble_provisioning();
        if (ret != ESP_OK) {
            ESP_LOGW(TAG, "Failed to start BLE provisioning, starting AP mode: %s", esp_err_to_name(ret));
            wifi_manager_start_ap();
        }
    }
    
    // Инициализация сервоконтроллера
    ESP_LOGI(TAG, "Initializing servo controller...");
    ret = servo_controller_init();
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Failed to initialize servo controller: %s", esp_err_to_name(ret));
        return ret;
    }
    
    // Инициализация LED контроллера
    ESP_LOGI(TAG, "Initializing LED controller...");
    led_controller_config_t led_config = {
        .gpio_pin = 33,    // GPIO пин для DATA сигнала WS2812
        .led_count = 7     // Количество светодиодов в ленте
    };
    ret = led_controller_init(&led_config);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Failed to initialize LED controller: %s", esp_err_to_name(ret));
        return ret;
    }
    
    // Инициализация веб-сервера
    ESP_LOGI(TAG, "Initializing web server...");
    ret = web_server_init(&g_device_config);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Failed to initialize web server: %s", esp_err_to_name(ret));
        return ret;
    }
    
    ESP_LOGI(TAG, "All components initialized successfully");
    return ESP_OK;
}

/**
 * @brief Создание FreeRTOS задач
 */
static void create_tasks(void)
{
    // Создаем задачу для периодических операций
    xTaskCreate(
        periodic_task,
        "periodic_task",
        4096,
        NULL,
        5,  // Высокий приоритет для точного управления сервоприводами
        NULL
    );
    
    // Создаем задачу для мониторинга соединений
    xTaskCreate(
        connection_monitor_task,
        "connection_monitor",
        4096,
        NULL,
        3,  // Средний приоритет
        NULL
    );
    
    // Создаем задачу для мониторинга кнопки сброса
    xTaskCreate(
        reset_button_task,
        "reset_button",
        2048,
        NULL,
        2,  // Низкий приоритет
        NULL
    );
    
    ESP_LOGI(TAG, "FreeRTOS tasks created");
}

/**
 * @brief Основная функция приложения
 */
void app_main(void)
{
    ESP_LOGI(TAG, "SmartLight firmware starting...");
    ESP_LOGI(TAG, "ESP-IDF version: %s", esp_get_idf_version());
    
    // Инициализация всех компонентов
    esp_err_t ret = init_system();
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "System initialization failed!");
        esp_restart();
        return;
    }
    
    // Создание задач
    create_tasks();
    
    ESP_LOGI(TAG, "SmartLight firmware initialized successfully");
    ESP_LOGI(TAG, "System ready - check web interface at device IP or AP IP (192.168.4.1)");
    
    // Основной цикл - просто мониторинг свободной памяти
    while (1) {
        ESP_LOGI(TAG, "Free heap memory: %d bytes", esp_get_free_heap_size());
        vTaskDelay(pdMS_TO_TICKS(30000)); // Логируем каждые 30 секунд
    }
}