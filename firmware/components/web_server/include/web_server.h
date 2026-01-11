#pragma once

#include "esp_err.h"
#include "esp_http_server.h"
#include "config_storage.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Инициализация и запуск веб-сервера
 * @param config Указатель на конфигурацию устройства (может быть изменена)
 * @return ESP_OK при успехе
 */
esp_err_t web_server_init(device_config_t* config);

/**
 * @brief Остановка веб-сервера
 * @return ESP_OK при успехе
 */
esp_err_t web_server_stop(void);

/**
 * @brief Деинициализация веб-сервера
 */
void web_server_deinit(void);

#ifdef __cplusplus
}
#endif