#pragma once

#include "esp_err.h"
#include "esp_websocket_client.h"
#include "config_storage.h"
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Инициализация WebSocket клиента
 * @param config Конфигурация устройства
 * @return ESP_OK при успехе
 */
esp_err_t websocket_client_init(const device_config_t* config);

/**
 * @brief Запуск WebSocket клиента
 * @return ESP_OK при успехе
 */
esp_err_t websocket_client_start(void);

/**
 * @brief Остановка WebSocket клиента
 * @return ESP_OK при успехе
 */
esp_err_t websocket_client_stop(void);

/**
 * @brief Проверить, подключен ли WebSocket
 * @return true если подключен
 */
bool websocket_client_is_connected(void);

/**
 * @brief Отправить heartbeat сообщение
 * @return ESP_OK при успехе
 */
esp_err_t websocket_client_send_heartbeat(void);

/**
 * @brief Задача для отправки heartbeat сообщений
 * Должна вызываться периодически
 */
void websocket_client_heartbeat_task(void);

/**
 * @brief Деинициализация WebSocket клиента
 */
void websocket_client_deinit(void);

#ifdef __cplusplus
}
#endif