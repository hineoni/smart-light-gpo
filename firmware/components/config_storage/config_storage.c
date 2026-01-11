#include "config_storage.h"
#include "nvs_flash.h"
#include "nvs.h"
#include "esp_log.h"
#include "esp_mac.h"
#include <string.h>
#include <stdio.h>

static const char *TAG = "CONFIG_STORAGE";

esp_err_t config_storage_init(void)
{
    esp_err_t ret = nvs_flash_init();
    if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        ret = nvs_flash_init();
    }
    ESP_ERROR_CHECK(ret);
    
    ESP_LOGI(TAG, "NVS Flash initialized");
    return ESP_OK;
}

void config_generate_device_id(char* device_id)
{
    uint8_t mac[6];
    esp_read_mac(mac, ESP_MAC_WIFI_STA);
    
    // Создаем device_id из последних 3 байт MAC адреса
    snprintf(device_id, 32, "smartlight_%02x%02x%02x", mac[3], mac[4], mac[5]);
}

esp_err_t config_storage_load(device_config_t* config)
{
    nvs_handle_t nvs_handle;
    esp_err_t err;
    
    // Инициализация структуры по умолчанию
    memset(config, 0, sizeof(device_config_t));
    config->is_valid = false;
    
    err = nvs_open(CONFIG_NAMESPACE, NVS_READONLY, &nvs_handle);
    if (err != ESP_OK) {
        ESP_LOGW(TAG, "Error opening NVS handle: %s", esp_err_to_name(err));
        return err;
    }
    
    size_t required_size;
    
    // Загружаем WiFi SSID
    required_size = sizeof(config->wifi_ssid);
    err = nvs_get_str(nvs_handle, "wifi_ssid", config->wifi_ssid, &required_size);
    if (err != ESP_OK && err != ESP_ERR_NVS_NOT_FOUND) {
        ESP_LOGE(TAG, "Error reading wifi_ssid: %s", esp_err_to_name(err));
        nvs_close(nvs_handle);
        return err;
    }
    
    // Загружаем WiFi Password
    required_size = sizeof(config->wifi_pass);
    err = nvs_get_str(nvs_handle, "wifi_pass", config->wifi_pass, &required_size);
    if (err != ESP_OK && err != ESP_ERR_NVS_NOT_FOUND) {
        ESP_LOGE(TAG, "Error reading wifi_pass: %s", esp_err_to_name(err));
        nvs_close(nvs_handle);
        return err;
    }
    
    // Загружаем Backend URL
    required_size = sizeof(config->backend_url);
    err = nvs_get_str(nvs_handle, "backend_url", config->backend_url, &required_size);
    if (err != ESP_OK && err != ESP_ERR_NVS_NOT_FOUND) {
        ESP_LOGE(TAG, "Error reading backend_url: %s", esp_err_to_name(err));
        nvs_close(nvs_handle);
        return err;
    }
    
    // Загружаем Device ID
    required_size = sizeof(config->device_id);
    err = nvs_get_str(nvs_handle, "device_id", config->device_id, &required_size);
    if (err != ESP_OK && err != ESP_ERR_NVS_NOT_FOUND) {
        ESP_LOGE(TAG, "Error reading device_id: %s", esp_err_to_name(err));
        nvs_close(nvs_handle);
        return err;
    }
    
    nvs_close(nvs_handle);
    
    // Генерируем device_id если он отсутствует
    if (strlen(config->device_id) == 0) {
        config_generate_device_id(config->device_id);
        ESP_LOGI(TAG, "Generated device_id: %s", config->device_id);
        // Сохраняем сгенерированный device_id
        device_config_t temp_config = *config;
        config_storage_save(&temp_config);
    }
    
    // Проверяем валидность конфигурации
    config->is_valid = (strlen(config->wifi_ssid) > 0) && (strlen(config->backend_url) > 0);
    
    ESP_LOGI(TAG, "Configuration loaded:");
    ESP_LOGI(TAG, "  WiFi SSID: %s", config->wifi_ssid);
    ESP_LOGI(TAG, "  Backend URL: %s", config->backend_url);
    ESP_LOGI(TAG, "  Device ID: %s", config->device_id);
    ESP_LOGI(TAG, "  Valid: %s", config->is_valid ? "Yes" : "No");
    
    return ESP_OK;
}

esp_err_t config_storage_save(const device_config_t* config)
{
    nvs_handle_t nvs_handle;
    esp_err_t err;
    
    err = nvs_open(CONFIG_NAMESPACE, NVS_READWRITE, &nvs_handle);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "Error opening NVS handle: %s", esp_err_to_name(err));
        return err;
    }
    
    // Сохраняем WiFi SSID
    err = nvs_set_str(nvs_handle, "wifi_ssid", config->wifi_ssid);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "Error saving wifi_ssid: %s", esp_err_to_name(err));
        nvs_close(nvs_handle);
        return err;
    }
    
    // Сохраняем WiFi Password
    err = nvs_set_str(nvs_handle, "wifi_pass", config->wifi_pass);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "Error saving wifi_pass: %s", esp_err_to_name(err));
        nvs_close(nvs_handle);
        return err;
    }
    
    // Сохраняем Backend URL
    err = nvs_set_str(nvs_handle, "backend_url", config->backend_url);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "Error saving backend_url: %s", esp_err_to_name(err));
        nvs_close(nvs_handle);
        return err;
    }
    
    // Сохраняем Device ID
    err = nvs_set_str(nvs_handle, "device_id", config->device_id);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "Error saving device_id: %s", esp_err_to_name(err));
        nvs_close(nvs_handle);
        return err;
    }
    
    // Применяем изменения
    err = nvs_commit(nvs_handle);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "Error committing to NVS: %s", esp_err_to_name(err));
    } else {
        ESP_LOGI(TAG, "Configuration saved successfully");
    }
    
    nvs_close(nvs_handle);
    return err;
}