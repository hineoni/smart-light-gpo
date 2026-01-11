#pragma once

#include "esp_err.h"
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// Константы конфигурации
#define DEFAULT_AP_SSID "SmartLight-Setup"
#define DEFAULT_AP_PASS "smartlight"
#define CONFIG_NAMESPACE "config"
#define HEARTBEAT_INTERVAL_MS 15000

// Пины сервоприводов
#define SERVO1_PIN 12
#define SERVO2_PIN 14

// Диапазон углов сервоприводов
#define SERVO_MIN_ANGLE 0
#define SERVO_MAX_ANGLE 180

// Структура конфигурации устройства
typedef struct {
    char wifi_ssid[64];
    char wifi_pass[64];
    char backend_url[256];
    char device_id[32];
    bool is_valid;
} device_config_t;

// Статус сервоприводов
typedef struct {
    int angle1;
    int angle2;
    bool moving1;
    bool moving2;
} servo_status_t;

/**
 * @brief Инициализация NVS
 * @return ESP_OK при успехе
 */
esp_err_t config_storage_init(void);

/**
 * @brief Загрузить конфигурацию из NVS
 * @param config Указатель на структуру для хранения конфигурации
 * @return ESP_OK при успехе
 */
esp_err_t config_storage_load(device_config_t* config);

/**
 * @brief Сохранить конфигурацию в NVS
 * @param config Указатель на структуру с конфигурацией
 * @return ESP_OK при успехе
 */
esp_err_t config_storage_save(const device_config_t* config);

/**
 * @brief Генерация device_id на основе MAC адреса
 * @param device_id Буфер для хранения device_id (минимум 32 байта)
 */
void config_generate_device_id(char* device_id);

#ifdef __cplusplus
}
#endif