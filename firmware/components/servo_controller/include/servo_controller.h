#pragma once

#include "esp_err.h"
#include "config_storage.h"
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Инициализация сервоконтроллера
 * @return ESP_OK при успехе
 */
esp_err_t servo_controller_init(void);

/**
 * @brief Установить угол сервопривода
 * @param servo_id ID сервопривода (1 или 2)
 * @param angle Угол в градусах (0-180)
 * @param smooth Плавное движение (true/false)
 * @return ESP_OK при успехе
 */
esp_err_t servo_controller_move_to(int servo_id, int angle, bool smooth);

/**
 * @brief Получить текущий статус сервоприводов
 * @param status Указатель на структуру статуса
 * @return ESP_OK при успехе
 */
esp_err_t servo_controller_get_status(servo_status_t* status);

/**
 * @brief Задача для плавного движения сервоприводов
 * Должна вызываться периодически из основного цикла или задачи FreeRTOS
 */
void servo_controller_task(void);

/**
 * @brief Тестирование сервоприводов
 * @param servo_id ID сервопривода (1, 2 или 0 для всех)
 * @return ESP_OK при успехе
 */
esp_err_t servo_controller_test(int servo_id);

/**
 * @brief Деинициализация сервоконтроллера
 */
void servo_controller_deinit(void);

#ifdef __cplusplus
}
#endif