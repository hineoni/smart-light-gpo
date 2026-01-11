#include "servo_controller.h"
#include "driver/ledc.h"
#include "esp_log.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include <math.h>

static const char *TAG = "SERVO_CONTROLLER";

// LEDC конфигурация
#define SERVO_LEDC_TIMER              LEDC_TIMER_0
#define SERVO_LEDC_MODE               LEDC_LOW_SPEED_MODE
#define SERVO_LEDC_CHANNEL_1          LEDC_CHANNEL_0
#define SERVO_LEDC_CHANNEL_2          LEDC_CHANNEL_1
#define SERVO_LEDC_DUTY_RES           LEDC_TIMER_13_BIT  // 13-битное разрешение
#define SERVO_LEDC_FREQUENCY          50                 // 50 Hz для сервоприводов

// PWM параметры для сервоприводов (расширенный диапазон для разных моделей)
#define SERVO_MIN_DUTY                328    // ~0.8ms при 13-bit и 50Hz (минимальный рабочий импульс)
#define SERVO_MAX_DUTY                1024   // ~2.5ms при 13-bit и 50Hz (максимальный рабочий импульс)  
#define SERVO_STEP_DELAY_MS           15     // Задержка между шагами плавного движения

// Текущие состояния сервоприводов
static servo_status_t s_servo_status = {
    .angle1 = 90,
    .angle2 = 90,
    .moving1 = false,
    .moving2 = false
};

// Целевые углы для плавного движения
static int s_target_angle1 = 90;
static int s_target_angle2 = 90;
static TickType_t s_last_step_time = 0;

/**
 * @brief Преобразование угла в значение duty cycle для LEDC
 * @param angle Угол в градусах (0-180)
 * @return Значение duty cycle
 */
static uint32_t angle_to_duty(int angle)
{
    // Ограничиваем угол
    if (angle < SERVO_MIN_ANGLE) angle = SERVO_MIN_ANGLE;
    if (angle > SERVO_MAX_ANGLE) angle = SERVO_MAX_ANGLE;
    
    // Линейная интерполяция между MIN и MAX duty
    return SERVO_MIN_DUTY + (angle * (SERVO_MAX_DUTY - SERVO_MIN_DUTY)) / (SERVO_MAX_ANGLE - SERVO_MIN_ANGLE);
}

/**
 * @brief Установить duty cycle для сервопривода
 * @param servo_id ID сервопривода (1 или 2)
 * @param angle Угол в градусах
 */
static void set_servo_angle_immediate(int servo_id, int angle)
{
    uint32_t duty = angle_to_duty(angle);
    ledc_channel_t channel = (servo_id == 1) ? SERVO_LEDC_CHANNEL_1 : SERVO_LEDC_CHANNEL_2;
    int gpio_pin = (servo_id == 1) ? SERVO1_PIN : SERVO2_PIN;
    
    ESP_LOGI(TAG, "Setting servo %d (GPIO%d): angle=%d°, duty=%d (%.2fms)", 
             servo_id, gpio_pin, angle, duty, (duty * 20.0) / 8192.0);
    
    esp_err_t ret = ledc_set_duty(SERVO_LEDC_MODE, channel, duty);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Failed to set duty for servo %d: %s", servo_id, esp_err_to_name(ret));
        return;
    }
    
    ret = ledc_update_duty(SERVO_LEDC_MODE, channel);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Failed to update duty for servo %d: %s", servo_id, esp_err_to_name(ret));
        return;
    }
    
    // Проверяем что duty cycle установлен корректно
    uint32_t actual_duty = ledc_get_duty(SERVO_LEDC_MODE, channel);
    ESP_LOGI(TAG, "Servo %d actual duty: %d (expected: %d)", servo_id, actual_duty, duty);
    
    // Добавляем небольшую задержку для стабилизации сигнала
    vTaskDelay(pdMS_TO_TICKS(10));
}

esp_err_t servo_controller_init(void)
{
    esp_err_t ret;
    
    // Конфигурация таймера LEDC
    ledc_timer_config_t ledc_timer = {
        .speed_mode = SERVO_LEDC_MODE,
        .timer_num = SERVO_LEDC_TIMER,
        .duty_resolution = SERVO_LEDC_DUTY_RES,
        .freq_hz = SERVO_LEDC_FREQUENCY,
        .clk_cfg = LEDC_AUTO_CLK
    };
    ret = ledc_timer_config(&ledc_timer);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Failed to configure LEDC timer: %s", esp_err_to_name(ret));
        return ret;
    }
    
    // Конфигурация канала для первого сервопривода
    ledc_channel_config_t ledc_channel_1 = {
        .speed_mode = SERVO_LEDC_MODE,
        .channel = SERVO_LEDC_CHANNEL_1,
        .timer_sel = SERVO_LEDC_TIMER,
        .intr_type = LEDC_INTR_DISABLE,
        .gpio_num = SERVO1_PIN,
        .duty = angle_to_duty(90),  // Начальное положение 90 градусов
        .hpoint = 0
    };
    ret = ledc_channel_config(&ledc_channel_1);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Failed to configure LEDC channel 1: %s", esp_err_to_name(ret));
        return ret;
    }
    
    // Конфигурация канала для второго сервопривода
    ledc_channel_config_t ledc_channel_2 = {
        .speed_mode = SERVO_LEDC_MODE,
        .channel = SERVO_LEDC_CHANNEL_2,
        .timer_sel = SERVO_LEDC_TIMER,
        .intr_type = LEDC_INTR_DISABLE,
        .gpio_num = SERVO2_PIN,
        .duty = angle_to_duty(90),  // Начальное положение 90 градусов
        .hpoint = 0
    };
    ret = ledc_channel_config(&ledc_channel_2);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Failed to configure LEDC channel 2: %s", esp_err_to_name(ret));
        return ret;
    }
    
    s_last_step_time = xTaskGetTickCount();
    
    ESP_LOGI(TAG, "Servo controller initialized. Servo1 pin: %d, Servo2 pin: %d", SERVO1_PIN, SERVO2_PIN);
    return ESP_OK;
}

esp_err_t servo_controller_move_to(int servo_id, int angle, bool smooth)
{
    // Ограничиваем угол
    if (angle < SERVO_MIN_ANGLE) angle = SERVO_MIN_ANGLE;
    if (angle > SERVO_MAX_ANGLE) angle = SERVO_MAX_ANGLE;
    
    if (servo_id == 1) {
        s_target_angle1 = angle;
        if (smooth) {
            s_servo_status.moving1 = (s_servo_status.angle1 != angle);
        } else {
            s_servo_status.angle1 = angle;
            s_servo_status.moving1 = false;
            set_servo_angle_immediate(1, angle);
        }
    } else if (servo_id == 2) {
        s_target_angle2 = angle;
        if (smooth) {
            s_servo_status.moving2 = (s_servo_status.angle2 != angle);
        } else {
            s_servo_status.angle2 = angle;
            s_servo_status.moving2 = false;
            set_servo_angle_immediate(2, angle);
        }
    } else {
        ESP_LOGE(TAG, "Invalid servo ID: %d", servo_id);
        return ESP_ERR_INVALID_ARG;
    }
    
    ESP_LOGI(TAG, "Servo %d moving to %d degrees (smooth: %s)", servo_id, angle, smooth ? "yes" : "no");
    return ESP_OK;
}

esp_err_t servo_controller_get_status(servo_status_t* status)
{
    if (status == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    
    *status = s_servo_status;
    return ESP_OK;
}

void servo_controller_task(void)
{
    TickType_t current_time = xTaskGetTickCount();
    
    // Проверяем, прошло ли достаточно времени с последнего шага
    if ((current_time - s_last_step_time) < pdMS_TO_TICKS(SERVO_STEP_DELAY_MS)) {
        return;
    }
    
    s_last_step_time = current_time;
    
    // Плавное движение первого сервопривода
    if (s_servo_status.moving1) {
        if (s_servo_status.angle1 != s_target_angle1) {
            int step = (s_target_angle1 > s_servo_status.angle1) ? 1 : -1;
            s_servo_status.angle1 += step;
            set_servo_angle_immediate(1, s_servo_status.angle1);
            
            if (s_servo_status.angle1 == s_target_angle1) {
                s_servo_status.moving1 = false;
                ESP_LOGI(TAG, "Servo 1 reached target angle: %d", s_target_angle1);
            }
        } else {
            s_servo_status.moving1 = false;
        }
    }
    
    // Плавное движение второго сервопривода
    if (s_servo_status.moving2) {
        if (s_servo_status.angle2 != s_target_angle2) {
            int step = (s_target_angle2 > s_servo_status.angle2) ? 1 : -1;
            s_servo_status.angle2 += step;
            set_servo_angle_immediate(2, s_servo_status.angle2);
            
            if (s_servo_status.angle2 == s_target_angle2) {
                s_servo_status.moving2 = false;
                ESP_LOGI(TAG, "Servo 2 reached target angle: %d", s_target_angle2);
            }
        } else {
            s_servo_status.moving2 = false;
        }
    }
}

void servo_controller_deinit(void)
{
    // Остановка каналов LEDC
    ledc_stop(SERVO_LEDC_MODE, SERVO_LEDC_CHANNEL_1, 0);
    ledc_stop(SERVO_LEDC_MODE, SERVO_LEDC_CHANNEL_2, 0);
    
    ESP_LOGI(TAG, "Servo controller deinitialized");
}

/**
 * @brief Тестирование сервоприводов - движение по всему диапазону
 * @param servo_id ID сервопривода (1, 2 или 0 для всех)
 */
esp_err_t servo_controller_test(int servo_id)
{
    ESP_LOGI(TAG, "=== TESTING SERVO %s ===", servo_id == 0 ? "ALL" : (servo_id == 1 ? "1" : "2"));
    
    int servos_to_test[2];
    int count = 0;
    
    if (servo_id == 0) {  // Тестируем все
        servos_to_test[0] = 1;
        servos_to_test[1] = 2;
        count = 2;
    } else if (servo_id == 1 || servo_id == 2) {
        servos_to_test[0] = servo_id;
        count = 1;
    } else {
        ESP_LOGE(TAG, "Invalid servo ID for test: %d", servo_id);
        return ESP_ERR_INVALID_ARG;
    }
    
    for (int i = 0; i < count; i++) {
        int servo = servos_to_test[i];
        ESP_LOGI(TAG, "Testing servo %d...", servo);
        
        // Тест по ключевым позициям
        int test_angles[] = {0, 45, 90, 135, 180, 90}; // Возвращаемся в центр
        int num_angles = sizeof(test_angles) / sizeof(test_angles[0]);
        
        for (int j = 0; j < num_angles; j++) {
            ESP_LOGI(TAG, "Servo %d -> %d degrees", servo, test_angles[j]);
            set_servo_angle_immediate(servo, test_angles[j]);
            vTaskDelay(pdMS_TO_TICKS(1000)); // 1 секунда на позицию
        }
        
        ESP_LOGI(TAG, "Servo %d test completed", servo);
    }
    
    ESP_LOGI(TAG, "=== SERVO TEST COMPLETED ===");
    return ESP_OK;
}