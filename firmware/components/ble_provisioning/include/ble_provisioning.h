#pragma once

#include "esp_err.h"
#include "config_storage.h"
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Состояния BLE provisioning
 */
typedef enum {
    BLE_PROV_STATE_IDLE,
    BLE_PROV_STATE_STARTED,
    BLE_PROV_STATE_CONNECTED,
    BLE_PROV_STATE_COMPLETED,
    BLE_PROV_STATE_FAILED
} ble_prov_state_t;

/**
 * @brief Callback функция для получения событий provisioning
 */
typedef void (*ble_prov_event_cb_t)(ble_prov_state_t state, void *data);

/**
 * @brief Инициализация BLE provisioning
 * @return ESP_OK при успехе
 */
esp_err_t ble_provisioning_init(void);

/**
 * @brief Запуск BLE provisioning
 * @param event_cb Callback функция для событий (может быть NULL)
 * @return ESP_OK при успехе
 */
esp_err_t ble_provisioning_start(ble_prov_event_cb_t event_cb);

/**
 * @brief Остановка BLE provisioning
 * @return ESP_OK при успехе
 */
esp_err_t ble_provisioning_stop(void);

/**
 * @brief Получить текущее состояние provisioning
 * @return Текущее состояние
 */
ble_prov_state_t ble_provisioning_get_state(void);

/**
 * @brief Проверить завершен ли provisioning
 * @return true если завершен успешно
 */
bool ble_provisioning_is_completed(void);

/**
 * @brief Деинициализация BLE provisioning
 */
void ble_provisioning_deinit(void);

#ifdef __cplusplus
}
#endif