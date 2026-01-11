#include "wifi_manager.h"
#include "esp_log.h"
#include "esp_netif.h"
#include "esp_wifi.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/event_groups.h"
#include "ble_provisioning.h"
#include <string.h>

static const char *TAG = "WIFI_MANAGER";

// Event bits
#define WIFI_CONNECTED_BIT BIT0
#define WIFI_FAIL_BIT BIT1

static EventGroupHandle_t s_wifi_event_group;
static esp_netif_t* s_netif_sta = NULL;
static esp_netif_t* s_netif_ap = NULL;
static wifi_state_t s_wifi_state = WIFI_STATE_IDLE;
static int s_retry_num = 0;
static const int WIFI_MAXIMUM_RETRY = 5;
static bool s_ble_prov_active = false;

static void wifi_event_handler(void* arg, esp_event_base_t event_base,
                              int32_t event_id, void* event_data)
{
    if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_START) {
        esp_wifi_connect();
        s_wifi_state = WIFI_STATE_CONNECTING;
        ESP_LOGI(TAG, "WiFi STA started, connecting...");
    } else if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_DISCONNECTED) {
        if (s_retry_num < WIFI_MAXIMUM_RETRY) {
            esp_wifi_connect();
            s_retry_num++;
            ESP_LOGI(TAG, "WiFi disconnected, retry %d/%d", s_retry_num, WIFI_MAXIMUM_RETRY);
        } else {
            xEventGroupSetBits(s_wifi_event_group, WIFI_FAIL_BIT);
            s_wifi_state = WIFI_STATE_FAILED;
            ESP_LOGE(TAG, "WiFi connection failed after %d retries", WIFI_MAXIMUM_RETRY);
        }
    } else if (event_base == IP_EVENT && event_id == IP_EVENT_STA_GOT_IP) {
        ip_event_got_ip_t* event = (ip_event_got_ip_t*) event_data;
        ESP_LOGI(TAG, "Got IP:" IPSTR, IP2STR(&event->ip_info.ip));
        s_retry_num = 0;
        s_wifi_state = WIFI_STATE_CONNECTED;
        xEventGroupSetBits(s_wifi_event_group, WIFI_CONNECTED_BIT);
    } else if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_AP_STACONNECTED) {
        wifi_event_ap_staconnected_t* event = (wifi_event_ap_staconnected_t*) event_data;
        ESP_LOGI(TAG, "Station joined, AID=%d", event->aid);
    } else if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_AP_STADISCONNECTED) {
        wifi_event_ap_stadisconnected_t* event = (wifi_event_ap_stadisconnected_t*) event_data;
        ESP_LOGI(TAG, "Station left, AID=%d", event->aid);
    }
}

// Callback для BLE provisioning событий
static void ble_prov_event_callback(ble_prov_state_t state, void *data)
{
    switch (state) {
        case BLE_PROV_STATE_STARTED:
            ESP_LOGI(TAG, "BLE provisioning started");
            s_wifi_state = WIFI_STATE_BLE_PROVISIONING;
            break;
        case BLE_PROV_STATE_COMPLETED:
            ESP_LOGI(TAG, "BLE provisioning completed successfully");
            s_ble_prov_active = false;
            s_wifi_state = WIFI_STATE_CONNECTED; // Устанавливаем состояние как подключенное
            
            // Сохраняем WiFi конфигурацию в NVS для следующих загрузок
            wifi_config_t wifi_cfg;
            if (esp_wifi_get_config(WIFI_IF_STA, &wifi_cfg) == ESP_OK) {
                device_config_t config = {0};
                // Загружаем существующую конфигурацию
                config_storage_load(&config);
                
                // Обновляем WiFi данные
                strncpy(config.wifi_ssid, (char*)wifi_cfg.sta.ssid, sizeof(config.wifi_ssid) - 1);
                strncpy(config.wifi_pass, (char*)wifi_cfg.sta.password, sizeof(config.wifi_pass) - 1);
                config.wifi_ssid[sizeof(config.wifi_ssid) - 1] = '\0';
                config.wifi_pass[sizeof(config.wifi_pass) - 1] = '\0';
                
                // Генерируем device_id если его нет
                if (strlen(config.device_id) == 0) {
                    uint8_t mac[6];
                    esp_wifi_get_mac(WIFI_IF_STA, mac);
                    snprintf(config.device_id, sizeof(config.device_id), 
                            "smartlight_%02x%02x%02x", mac[3], mac[4], mac[5]);
                }
                
                // Сохраняем конфигурацию
                esp_err_t ret = config_storage_save(&config);
                if (ret == ESP_OK) {
                    ESP_LOGI(TAG, "WiFi configuration saved to NVS");
                } else {
                    ESP_LOGW(TAG, "Failed to save WiFi configuration: %s", esp_err_to_name(ret));
                }
            }
            
            ESP_LOGI(TAG, "BLE provisioning completed - device will continue running");
            // Не перезагружаемся сразу - даем Flutter получить подтверждение
            // Устройство продолжит работать с новой конфигурацией
            break;
        case BLE_PROV_STATE_FAILED:
            ESP_LOGE(TAG, "BLE provisioning failed");
            s_wifi_state = WIFI_STATE_FAILED;
            s_ble_prov_active = false;
            break;
        default:
            break;
    }
}

esp_err_t wifi_manager_init(const device_config_t* config)
{
    esp_err_t ret = ESP_OK;
    
    // Создаем event group
    s_wifi_event_group = xEventGroupCreate();
    
    // Инициализация netif
    ESP_ERROR_CHECK(esp_netif_init());
    
    // Создание event loop
    ESP_ERROR_CHECK(esp_event_loop_create_default());
    
    // Инициализация WiFi
    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
    ESP_ERROR_CHECK(esp_wifi_init(&cfg));
    
    // Регистрация обработчиков событий
    ESP_ERROR_CHECK(esp_event_handler_register(WIFI_EVENT, ESP_EVENT_ANY_ID, &wifi_event_handler, NULL));
    ESP_ERROR_CHECK(esp_event_handler_register(IP_EVENT, IP_EVENT_STA_GOT_IP, &wifi_event_handler, NULL));
    
    // Запуск в зависимости от валидности конфигурации
    if (config->is_valid) {
        ret = wifi_manager_start_sta(config);
    } else {
        ret = wifi_manager_start_ap();
    }
    
    return ret;
}

esp_err_t wifi_manager_start_sta(const device_config_t* config)
{
    // Создание STA netif если еще не создан
    if (s_netif_sta == NULL) {
        s_netif_sta = esp_netif_create_default_wifi_sta();
    }
    
    wifi_config_t wifi_config = {};
    strncpy((char*)wifi_config.sta.ssid, config->wifi_ssid, sizeof(wifi_config.sta.ssid));
    strncpy((char*)wifi_config.sta.password, config->wifi_pass, sizeof(wifi_config.sta.password));
    wifi_config.sta.threshold.authmode = WIFI_AUTH_WPA2_PSK;
    wifi_config.sta.pmf_cfg.capable = true;
    wifi_config.sta.pmf_cfg.required = false;
    
    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA));
    ESP_ERROR_CHECK(esp_wifi_set_config(WIFI_IF_STA, &wifi_config));
    ESP_ERROR_CHECK(esp_wifi_start());
    
    ESP_LOGI(TAG, "WiFi STA mode started. SSID: %s", config->wifi_ssid);
    
    return ESP_OK;
}

esp_err_t wifi_manager_start_ap(void)
{
    // Создание AP netif если еще не создан
    if (s_netif_ap == NULL) {
        s_netif_ap = esp_netif_create_default_wifi_ap();
    }
    
    wifi_config_t wifi_config = {
        .ap = {
            .ssid_len = strlen(DEFAULT_AP_SSID),
            .channel = 1,
            .password = DEFAULT_AP_PASS,
            .max_connection = 4,
            .authmode = WIFI_AUTH_WPA_WPA2_PSK
        },
    };
    strcpy((char*)wifi_config.ap.ssid, DEFAULT_AP_SSID);
    
    if (strlen(DEFAULT_AP_PASS) == 0) {
        wifi_config.ap.authmode = WIFI_AUTH_OPEN;
    }
    
    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_AP));
    ESP_ERROR_CHECK(esp_wifi_set_config(WIFI_IF_AP, &wifi_config));
    ESP_ERROR_CHECK(esp_wifi_start());
    
    s_wifi_state = WIFI_STATE_AP_MODE;
    
    ESP_LOGI(TAG, "WiFi AP mode started. SSID: %s, password: %s", DEFAULT_AP_SSID, DEFAULT_AP_PASS);
    
    return ESP_OK;
}

wifi_state_t wifi_manager_get_state(void)
{
    return s_wifi_state;
}

bool wifi_manager_is_connected(void)
{
    return s_wifi_state == WIFI_STATE_CONNECTED;
}

esp_err_t wifi_manager_get_ip(esp_netif_ip_info_t* ip)
{
    if (s_netif_sta == NULL) {
        return ESP_ERR_INVALID_STATE;
    }
    return esp_netif_get_ip_info(s_netif_sta, ip);
}

esp_err_t wifi_manager_get_ap_ip(esp_netif_ip_info_t* ip)
{
    if (s_netif_ap == NULL) {
        return ESP_ERR_INVALID_STATE;
    }
    return esp_netif_get_ip_info(s_netif_ap, ip);
}

esp_err_t wifi_manager_start_ble_provisioning(void)
{
    ESP_LOGI(TAG, "Starting BLE provisioning mode");
    
    // Останавливаем текущий WiFi если активен
    if (s_wifi_state != WIFI_STATE_IDLE) {
        esp_wifi_stop();
    }
    
    // Убеждаемся что STA netif создан для получения IP адреса
    if (s_netif_sta == NULL) {
        ESP_LOGI(TAG, "Creating STA netif for BLE provisioning");
        s_netif_sta = esp_netif_create_default_wifi_sta();
    }
    
    // Инициализируем и запускаем BLE provisioning
    esp_err_t ret = ble_provisioning_init();
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Failed to initialize BLE provisioning: %s", esp_err_to_name(ret));
        return ret;
    }
    
    ret = ble_provisioning_start(ble_prov_event_callback);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Failed to start BLE provisioning: %s", esp_err_to_name(ret));
        ble_provisioning_deinit();
        return ret;
    }
    
    s_ble_prov_active = true;
    s_wifi_state = WIFI_STATE_BLE_PROVISIONING;
    
    return ESP_OK;
}

void wifi_manager_deinit(void)
{
    // Останавливаем BLE provisioning если активен
    if (s_ble_prov_active) {
        ble_provisioning_stop();
        ble_provisioning_deinit();
        s_ble_prov_active = false;
    }
    
    esp_wifi_stop();
    esp_wifi_deinit();
    
    if (s_wifi_event_group) {
        vEventGroupDelete(s_wifi_event_group);
        s_wifi_event_group = NULL;
    }
    
    s_netif_sta = NULL;
    s_netif_ap = NULL;
    s_wifi_state = WIFI_STATE_IDLE;
}
