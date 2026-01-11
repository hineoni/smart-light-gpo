#pragma once

#include "esp_err.h"
#include "esp_wifi.h"
#include "esp_event.h"
#include "config_storage.h"
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    WIFI_STATE_IDLE,
    WIFI_STATE_CONNECTING,
    WIFI_STATE_CONNECTED,
    WIFI_STATE_AP_MODE,
    WIFI_STATE_BLE_PROVISIONING,
    WIFI_STATE_FAILED
} wifi_state_t;

/**
 * @brief Инициализация WiFi и запуск подключения/AP
 * @param config Конфигурация устройства
 * @return ESP_OK при успехе
 */
esp_err_t wifi_manager_init(const device_config_t* config);

/**
 * @brief Запуск STA режима (подключение к WiFi)
 * @param config Конфигурация устройства
 * @return ESP_OK при успехе
 */
esp_err_t wifi_manager_start_sta(const device_config_t* config);

/**
 * @brief Запуск AP режима (точка доступа)
 * @return ESP_OK при успехе
 */
esp_err_t wifi_manager_start_ap(void);

/**
 * @brief Получить текущее состояние WiFi
 * @return Текущее состояние
 */
wifi_state_t wifi_manager_get_state(void);

/**
 * @brief Проверить, подключен ли WiFi
 * @return true если подключен
 */
bool wifi_manager_is_connected(void);

/**
 * @brief Получить IP адрес в STA режиме
 * @param ip Указатель на структуру для IP адреса
 * @return ESP_OK если IP получен
 */
esp_err_t wifi_manager_get_ip(esp_netif_ip_info_t* ip);

/**
 * @brief Получить IP адрес AP
 * @param ip Указатель на структуру для IP адреса
 * @return ESP_OK если IP получен
 */
esp_err_t wifi_manager_get_ap_ip(esp_netif_ip_info_t* ip);

/**
 * @brief Запуск BLE provisioning режима
 * @return ESP_OK при успехе
 */
esp_err_t wifi_manager_start_ble_provisioning(void);

/**
 * @brief Деинициализация WiFi
 */
void wifi_manager_deinit(void);

#ifdef __cplusplus
}
#endif