#pragma once

#include <stdint.h>
#include <stdbool.h>
#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

#define LED_CONTROLLER_MAX_LEDS 64

/**
 * @brief Структура для RGB цвета
 */
typedef struct {
    uint8_t r;  ///< Красный канал (0-255)
    uint8_t g;  ///< Зелёный канал (0-255)  
    uint8_t b;  ///< Синий канал (0-255)
} led_rgb_t;

/**
 * @brief Конфигурация LED контроллера
 */
typedef struct {
    int gpio_pin;           ///< GPIO пин для DATA сигнала
    int led_count;          ///< Количество светодиодов в ленте
} led_controller_config_t;

/**
 * @brief Инициализация LED контроллера
 * 
 * @param config Конфигурация контроллера
 * @return ESP_OK в случае успеха
 */
esp_err_t led_controller_init(const led_controller_config_t *config);

/**
 * @brief Деинициализация LED контроллера
 * 
 * @return ESP_OK в случае успеха
 */
esp_err_t led_controller_deinit(void);

/**
 * @brief Установка цвета для всех светодиодов
 * 
 * @param color RGB цвет
 * @return ESP_OK в случае успеха
 */
esp_err_t led_controller_set_all_color(const led_rgb_t *color);

/**
 * @brief Установка цвета для одного светодиода
 * 
 * @param led_index Индекс светодиода (0-based)
 * @param color RGB цвет
 * @return ESP_OK в случае успеха
 */
esp_err_t led_controller_set_color(int led_index, const led_rgb_t *color);

/**
 * @brief Отправка данных на светодиодную ленту
 * 
 * @return ESP_OK в случае успеха
 */
esp_err_t led_controller_update(void);

/**
 * @brief Выключение всех светодиодов
 * 
 * @return ESP_OK в случае успеха
 */
esp_err_t led_controller_clear(void);

/**
 * @brief Установка яркости
 * 
 * @param brightness Яркость от 0 до 255
 * @return ESP_OK в случае успеха
 */
esp_err_t led_controller_set_brightness(uint8_t brightness);

/**
 * @brief Получение текущего количества светодиодов
 * 
 * @return Количество светодиодов или -1 если контроллер не инициализирован
 */
int led_controller_get_led_count(void);

#ifdef __cplusplus
}
#endif