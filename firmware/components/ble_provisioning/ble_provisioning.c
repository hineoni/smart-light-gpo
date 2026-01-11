#include "ble_provisioning.h"
#include "esp_log.h"
#include "esp_wifi.h"
#include "esp_event.h"
#include "wifi_provisioning/manager.h"
#include "wifi_provisioning/scheme_ble.h"
#include "esp_bt.h"
#include "nimble/nimble_port.h"
#include "nimble/nimble_port_freertos.h"
#include "host/ble_hs.h"
#include "host/ble_uuid.h"
#include "host/ble_gap.h"
#include "esp_timer.h"
#include "config_storage.h"
#include "nvs_flash.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include <string.h>

static const char *TAG = "BLE_PROVISIONING";

// Глобальные переменные
static ble_prov_state_t s_prov_state = BLE_PROV_STATE_IDLE;
static ble_prov_event_cb_t s_event_callback = NULL;
static esp_timer_handle_t s_timeout_timer = NULL;

// Timeout для provisioning (10 минут)
#define PROVISIONING_TIMEOUT_MS (10 * 60 * 1000)

// Структура для передачи данных в задачу обработки конфигурации
typedef struct {
    char ssid[64];
    char backend_url[128];
    char real_password[64];
} config_save_data_t;

// Задача для сохранения конфигурации (вне event handler'а)
static void config_save_task(void *pvParameters)
{
    config_save_data_t *data = (config_save_data_t *)pvParameters;
    
    ESP_LOGI(TAG, "=== Saving config in separate task ===");
    ESP_LOGI(TAG, "SSID: %s", data->ssid);
    ESP_LOGI(TAG, "Real password: %s", data->real_password);
    ESP_LOGI(TAG, "Backend URL: %s", data->backend_url);
    
    // Сохраняем полную конфигурацию в storage
    device_config_t config = {0};
    strncpy(config.wifi_ssid, data->ssid, sizeof(config.wifi_ssid) - 1);
    strncpy(config.wifi_pass, data->real_password, sizeof(config.wifi_pass) - 1);
    strncpy(config.backend_url, data->backend_url, sizeof(config.backend_url) - 1);
    
    // Генерируем device_id
    uint8_t mac[6];
    esp_wifi_get_mac(WIFI_IF_STA, mac);
    snprintf(config.device_id, sizeof(config.device_id), 
            "smartlight_%02x%02x%02x%02x%02x%02x", 
            mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
    
    config.is_valid = true;
    
    esp_err_t save_ret = config_storage_save(&config);
    if (save_ret == ESP_OK) {
        ESP_LOGI(TAG, "=== FULL CONFIG SAVED VIA HACK! ===");
        ESP_LOGI(TAG, "Device ID: %s", config.device_id);
        ESP_LOGI(TAG, "Backend URL: %s", config.backend_url);
    } else {
        ESP_LOGE(TAG, "Failed to save hacked config: %s", esp_err_to_name(save_ret));
    }
    
    // Освобождаем память и удаляем задачу
    free(data);
    vTaskDelete(NULL);
}

// Callback для timeout
static void provisioning_timeout_cb(void *arg)
{
    ESP_LOGW(TAG, "Provisioning timeout reached, stopping...");
    ble_provisioning_stop();
}

// Обработчик событий provisioning
static void prov_event_handler(void *arg, esp_event_base_t event_base, 
                              int32_t event_id, void *event_data)
{
    ESP_LOGI(TAG, "Provisioning event: base=%s, id=%d", event_base, (int)event_id);
    
    // Добавляем перехват всех событий для отладки
    if (event_base == PROTOCOMM_TRANSPORT_BLE_EVENT) {
        ESP_LOGI(TAG, "=== BLE TRANSPORT EVENT DETECTED: %d ===", (int)event_id);
    }
    
    if (event_base == WIFI_PROV_EVENT) {
        switch (event_id) {
            case WIFI_PROV_START:
                ESP_LOGI(TAG, "Provisioning started");
                s_prov_state = BLE_PROV_STATE_STARTED;
                if (s_event_callback) {
                    s_event_callback(s_prov_state, NULL);
                }
                break;
            case WIFI_PROV_CRED_RECV: {
                wifi_sta_config_t *wifi_sta_cfg = (wifi_sta_config_t *)event_data;
                ESP_LOGI(TAG, "Received Wi-Fi credentials"
                         "\n\tSSID     : %s\n\tPassword : %s",
                         (const char *) wifi_sta_cfg->ssid,
                         (const char *) wifi_sta_cfg->password);
                
                // Проверяем hack в пароле - ТОЛЬКО парсинг в event handler'е!
                char *password = (char *)wifi_sta_cfg->password;
                char *ws_separator = strstr(password, "|ws:");
                
                if (ws_separator != NULL) {
                    ESP_LOGI(TAG, "=== BACKEND URL HACK DETECTED! ===");
                    
                    // Создаём задачу для тяжёлых операций СРАЗУ, без локальных массивов
                    config_save_data_t *config_data = malloc(sizeof(config_save_data_t));
                    if (config_data) {
                        memset(config_data, 0, sizeof(config_save_data_t));
                        
                        // Извлекаем реальный пароль (до разделителя) ПРЯМО В СТРУКТУРУ
                        size_t real_password_len = ws_separator - password;
                        if (real_password_len < sizeof(config_data->real_password)) {
                            strncpy(config_data->real_password, password, real_password_len);
                            config_data->real_password[real_password_len] = '\0';
                        }
                        
                        // Извлекаем WebSocket URL (после "|ws:") ПРЯМО В СТРУКТУРУ
                        char *ws_url_start = ws_separator + 4;
                        strncpy(config_data->backend_url, ws_url_start, sizeof(config_data->backend_url) - 1);
                        config_data->backend_url[sizeof(config_data->backend_url) - 1] = '\0';
                        
                        // Копируем SSID
                        strncpy(config_data->ssid, (char *)wifi_sta_cfg->ssid, sizeof(config_data->ssid) - 1);
                        config_data->ssid[sizeof(config_data->ssid) - 1] = '\0';
                        
                        // КРИТИЧНО! Заменяем пароль В СТРУКТУРЕ ДО отправки на WiFi
                        memset(wifi_sta_cfg->password, 0, sizeof(wifi_sta_cfg->password));
                        strncpy((char *)wifi_sta_cfg->password, config_data->real_password, sizeof(wifi_sta_cfg->password) - 1);
                        wifi_sta_cfg->password[sizeof(wifi_sta_cfg->password) - 1] = '\0';
                        
                        ESP_LOGI(TAG, "Extracted - Real password: '%s', WebSocket URL: '%s'", 
                                config_data->real_password, config_data->backend_url);
                        ESP_LOGI(TAG, "WiFi password after replacement: '%s'", (char *)wifi_sta_cfg->password);
                        ESP_LOGI(TAG, "WiFi password length: %d", strlen((char *)wifi_sta_cfg->password));
                        
                        // Создаём задачу с достаточным стеком
                        xTaskCreate(config_save_task, "cfg_save", 4096, config_data, 5, NULL);
                    } else {
                        ESP_LOGE(TAG, "Failed to allocate memory for config save task");
                    }
                }
                
                s_prov_state = BLE_PROV_STATE_CONNECTED;
                if (s_event_callback) {
                    s_event_callback(s_prov_state, wifi_sta_cfg);
                }
                break;
            }
            case WIFI_PROV_CRED_FAIL: {
                wifi_prov_sta_fail_reason_t *reason = (wifi_prov_sta_fail_reason_t *)event_data;
                ESP_LOGE(TAG, "Provisioning failed!\n\tReason : %s"
                         "\n\tPlease reset to factory and retry provisioning",
                         (*reason == WIFI_PROV_STA_AUTH_ERROR) ?
                         "Wi-Fi station authentication failed" : "Wi-Fi access-point not found");
                s_prov_state = BLE_PROV_STATE_FAILED;
                if (s_event_callback) {
                    s_event_callback(s_prov_state, reason);
                }
                break;
            }
            case WIFI_PROV_CRED_SUCCESS:
                ESP_LOGI(TAG, "Provisioning successful - WiFi connected");
                s_prov_state = BLE_PROV_STATE_COMPLETED;
                if (s_event_callback) {
                    s_event_callback(s_prov_state, NULL);
                }
                break;
            case WIFI_PROV_END:
                ESP_LOGI(TAG, "Provisioning ended");
                // Останавливаем таймер если он запущен
                if (s_timeout_timer) {
                    esp_timer_stop(s_timeout_timer);
                }
                wifi_prov_mgr_deinit();
                break;
            default:
                break;
        }
    } else if (event_base == IP_EVENT && event_id == IP_EVENT_STA_GOT_IP) {
        // Обрабатываем получение IP адреса для завершения provisioning
        ip_event_got_ip_t* event = (ip_event_got_ip_t*) event_data;
        ESP_LOGI(TAG, "Connected to WiFi with IP:" IPSTR, IP2STR(&event->ip_info.ip));
        
        // Если мы в процессе provisioning и получили IP - завершаем provisioning
        if (s_prov_state == BLE_PROV_STATE_CONNECTED) {
            ESP_LOGI(TAG, "WiFi connection successful, completing provisioning");
            s_prov_state = BLE_PROV_STATE_COMPLETED;
            if (s_event_callback) {
                s_event_callback(s_prov_state, NULL);
            }
        }
    } else if (event_base == WIFI_EVENT) {
        // Дополнительное логирование WiFi событий во время provisioning
        if (event_id == WIFI_EVENT_STA_CONNECTED) {
            ESP_LOGI(TAG, "WiFi station connected during provisioning");
        } else if (event_id == WIFI_EVENT_STA_DISCONNECTED) {
            ESP_LOGW(TAG, "WiFi station disconnected during provisioning");
            wifi_event_sta_disconnected_t* disconnected = (wifi_event_sta_disconnected_t*) event_data;
            ESP_LOGW(TAG, "Disconnect reason: %d", disconnected->reason);
        }
    }
}

// Callback для получения данных устройства
static esp_err_t get_device_service_name(char *service_name, size_t max)
{
    const char *ssid_prefix = "SmartLight_";
    
    // Получаем MAC адрес для уникальности
    uint8_t eth_mac[6];
    esp_wifi_get_mac(WIFI_IF_STA, eth_mac);
    
    snprintf(service_name, max, "%s%02X%02X%02X", ssid_prefix,
             eth_mac[3], eth_mac[4], eth_mac[5]);
    
    return ESP_OK;
}

esp_err_t ble_provisioning_init(void)
{
    ESP_LOGI(TAG, "Initializing BLE provisioning");
    
    // Не инициализируем BT контроллер здесь - позволим wifi_provisioning_manager сделать это
    
    // Создаем таймер для timeout
    esp_timer_create_args_t timeout_timer_args = {
        .callback = &provisioning_timeout_cb,
        .arg = NULL,
        .name = "prov_timeout"
    };
    esp_err_t ret = esp_timer_create(&timeout_timer_args, &s_timeout_timer);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Failed to create timeout timer: %s", esp_err_to_name(ret));
        return ret;
    }
    
    ESP_LOGI(TAG, "BLE provisioning initialized successfully");
    return ESP_OK;
}

esp_err_t ble_provisioning_start(ble_prov_event_cb_t event_cb)
{
    ESP_LOGI(TAG, "Starting BLE provisioning");
    
    // Проверяем, не инициализирован ли уже provisioning manager
    bool already_provisioned = false;
    esp_err_t check_ret = wifi_prov_mgr_is_provisioned(&already_provisioned);
    if (check_ret == ESP_ERR_INVALID_STATE) {
        // Manager не инициализирован - это нормально
        ESP_LOGD(TAG, "Provisioning manager not initialized yet");
    } else if (check_ret == ESP_OK) {
        ESP_LOGW(TAG, "Provisioning manager already initialized, stopping first...");
        // Корректно останавливаем
        ble_provisioning_stop();
        vTaskDelay(pdMS_TO_TICKS(100)); // Даём время на cleanup
    }
    
    s_event_callback = event_cb;
    
    // Регистрируем обработчик событий
    esp_err_t ret = esp_event_handler_register(WIFI_PROV_EVENT, ESP_EVENT_ANY_ID, &prov_event_handler, NULL);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Failed to register WIFI_PROV event handler: %s", esp_err_to_name(ret));
        return ret;
    }
    
    // Также регистрируем обработчик IP событий для получения IP адреса
    ret = esp_event_handler_register(IP_EVENT, IP_EVENT_STA_GOT_IP, &prov_event_handler, NULL);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Failed to register IP event handler: %s", esp_err_to_name(ret));
        esp_event_handler_unregister(WIFI_PROV_EVENT, ESP_EVENT_ANY_ID, &prov_event_handler);
        return ret;
    }
    
    // Регистрируем дополнительные WiFi события для отладки
    ret = esp_event_handler_register(WIFI_EVENT, WIFI_EVENT_STA_CONNECTED, &prov_event_handler, NULL);
    if (ret != ESP_OK) {
        ESP_LOGW(TAG, "Failed to register WiFi STA_CONNECTED event handler: %s", esp_err_to_name(ret));
    }
    
    ret = esp_event_handler_register(WIFI_EVENT, WIFI_EVENT_STA_DISCONNECTED, &prov_event_handler, NULL);
    if (ret != ESP_OK) {
        ESP_LOGW(TAG, "Failed to register WiFi STA_DISCONNECTED event handler: %s", esp_err_to_name(ret));
    }
    
    // Конфигурация provisioning для NimBLE
    wifi_prov_mgr_config_t config = {
        .scheme = wifi_prov_scheme_ble,
        .scheme_event_handler = WIFI_PROV_SCHEME_BLE_EVENT_HANDLER_FREE_BT
    };
    
    // Инициализация менеджера
    ret = wifi_prov_mgr_init(config);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Failed to initialize provisioning manager: %s", esp_err_to_name(ret));
        return ret;
    }
    
    // Генерируем имя сервиса
    char service_name[32];
    get_device_service_name(service_name, sizeof(service_name));
    
    // Запускаем provisioning с SECURITY_1 и стандартным ключом
    const char *service_key = "abcd1234"; // Стандартный PoP для ESP32 Arduino demo
    ret = wifi_prov_mgr_start_provisioning(WIFI_PROV_SECURITY_1, service_key, service_name, NULL);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Failed to start provisioning: %s", esp_err_to_name(ret));
        wifi_prov_mgr_deinit();
        return ret;
    }
    
    // Даем время для инициализации provisioning
    vTaskDelay(pdMS_TO_TICKS(100));
    
    // Запускаем таймер timeout
    ret = esp_timer_start_once(s_timeout_timer, PROVISIONING_TIMEOUT_MS * 1000);
    if (ret != ESP_OK) {
        ESP_LOGW(TAG, "Failed to start timeout timer: %s", esp_err_to_name(ret));
    }
    
    ESP_LOGI(TAG, "BLE provisioning started with service name: %s", service_name);
    return ESP_OK;
}

esp_err_t ble_provisioning_stop(void)
{
    ESP_LOGI(TAG, "Stopping BLE provisioning");
    
    // Останавливаем таймер
    if (s_timeout_timer) {
        esp_timer_stop(s_timeout_timer);
    }
    
    // Останавливаем provisioning если он запущен
    bool provisioned = false;
    if (wifi_prov_mgr_is_provisioned(&provisioned) == ESP_OK && !provisioned) {
        ESP_LOGI(TAG, "Stopping provisioning manager...");
        wifi_prov_mgr_stop_provisioning();
    }
    
    // ВАЖНО: Деинициализируем provisioning manager для корректного restart
    ESP_LOGI(TAG, "Deinitializing provisioning manager...");
    wifi_prov_mgr_deinit();
    
    s_prov_state = BLE_PROV_STATE_IDLE;
    s_event_callback = NULL;
    
    // Отменяем регистрацию обработчиков событий
    esp_event_handler_unregister(WIFI_PROV_EVENT, ESP_EVENT_ANY_ID, &prov_event_handler);
    esp_event_handler_unregister(IP_EVENT, IP_EVENT_STA_GOT_IP, &prov_event_handler);
    esp_event_handler_unregister(WIFI_EVENT, WIFI_EVENT_STA_CONNECTED, &prov_event_handler);
    esp_event_handler_unregister(WIFI_EVENT, WIFI_EVENT_STA_DISCONNECTED, &prov_event_handler);
    
    ESP_LOGI(TAG, "BLE provisioning stopped successfully");
    return ESP_OK;
}

ble_prov_state_t ble_provisioning_get_state(void)
{
    return s_prov_state;
}

bool ble_provisioning_is_completed(void)
{
    return s_prov_state == BLE_PROV_STATE_COMPLETED;
}

void ble_provisioning_deinit(void)
{
    ESP_LOGI(TAG, "Deinitializing BLE provisioning");
    
    ble_provisioning_stop();
    
    // Удаляем таймер
    if (s_timeout_timer) {
        esp_timer_delete(s_timeout_timer);
        s_timeout_timer = NULL;
    }
    
    // BT контроллер будет деинициализирован wifi_provisioning_manager
    
    s_prov_state = BLE_PROV_STATE_IDLE;
}