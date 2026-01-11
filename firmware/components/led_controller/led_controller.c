#include <string.h>
#include <stdlib.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "led_controller.h"
#include "led_strip_encoder.h"
#include "driver/rmt_tx.h"
#include "esp_log.h"

static const char *TAG = "led_controller";

#define RMT_LED_STRIP_RESOLUTION_HZ 10000000 // 10MHz resolution, 1 tick = 0.1us

// Структура для хранения состояния LED контроллера
typedef struct {
    rmt_channel_handle_t led_chan;
    rmt_encoder_handle_t led_encoder;
    uint8_t *led_strip_pixels;
    int led_count;
    int gpio_pin;
    uint8_t brightness;
    led_rgb_t current_color;  // Храним текущий цвет
    bool initialized;
} led_controller_state_t;

static led_controller_state_t s_led_state = {0};

esp_err_t led_controller_init(const led_controller_config_t *config)
{
    if (!config) {
        ESP_LOGE(TAG, "Config is NULL");
        return ESP_ERR_INVALID_ARG;
    }
    
    if (config->led_count <= 0 || config->led_count > LED_CONTROLLER_MAX_LEDS) {
        ESP_LOGE(TAG, "Invalid LED count: %d", config->led_count);
        return ESP_ERR_INVALID_ARG;
    }
    
    if (s_led_state.initialized) {
        ESP_LOGW(TAG, "LED controller already initialized");
        return ESP_OK;
    }

    ESP_LOGI(TAG, "Initializing LED controller on GPIO %d with %d LEDs", config->gpio_pin, config->led_count);
    
    // Сохраняем конфигурацию
    s_led_state.led_count = config->led_count;
    s_led_state.gpio_pin = config->gpio_pin;
    s_led_state.brightness = 255; // Максимальная яркость по умолчанию

    // Создаем RMT канал
    rmt_tx_channel_config_t tx_chan_config = {
        .clk_src = RMT_CLK_SRC_DEFAULT,
        .gpio_num = config->gpio_pin,
        .mem_block_symbols = 64,
        .resolution_hz = RMT_LED_STRIP_RESOLUTION_HZ,
        .trans_queue_depth = 4,
    };
    ESP_ERROR_CHECK(rmt_new_tx_channel(&tx_chan_config, &s_led_state.led_chan));

    // Устанавливаем энкодер для LED ленты
    led_strip_encoder_config_t encoder_config = {
        .resolution = RMT_LED_STRIP_RESOLUTION_HZ,
    };
    ESP_ERROR_CHECK(rmt_new_led_strip_encoder(&encoder_config, &s_led_state.led_encoder));

    // Включаем RMT канал
    ESP_ERROR_CHECK(rmt_enable(s_led_state.led_chan));

    // Выделяем память для данных светодиодов
    s_led_state.led_strip_pixels = malloc(config->led_count * 3);
    if (!s_led_state.led_strip_pixels) {
        ESP_LOGE(TAG, "Failed to allocate memory for LED strip pixels");
        return ESP_ERR_NO_MEM;
    }

    // Очищаем все светодиоды
    memset(s_led_state.led_strip_pixels, 0, config->led_count * 3);
    
    s_led_state.initialized = true;
    
    // Отправляем данные для инициализации
    led_controller_update();
    
    ESP_LOGI(TAG, "LED controller initialized successfully");
    return ESP_OK;
}

esp_err_t led_controller_deinit(void)
{
    if (!s_led_state.initialized) {
        return ESP_OK;
    }

    // Очищаем светодиоды перед выключением
    led_controller_clear();
    
    // Освобождаем ресурсы
    if (s_led_state.led_strip_pixels) {
        free(s_led_state.led_strip_pixels);
        s_led_state.led_strip_pixels = NULL;
    }
    
    if (s_led_state.led_encoder) {
        rmt_del_encoder(s_led_state.led_encoder);
        s_led_state.led_encoder = NULL;
    }
    
    if (s_led_state.led_chan) {
        rmt_disable(s_led_state.led_chan);
        rmt_del_channel(s_led_state.led_chan);
        s_led_state.led_chan = NULL;
    }

    s_led_state.initialized = false;
    
    ESP_LOGI(TAG, "LED controller deinitialized");
    return ESP_OK;
}

esp_err_t led_controller_set_all_color(const led_rgb_t *color)
{
    if (!s_led_state.initialized || !color) {
        return ESP_ERR_INVALID_STATE;
    }

    // Сохраняем текущий цвет
    s_led_state.current_color = *color;

    // Применяем яркость к цвету
    uint8_t r = (color->r * s_led_state.brightness) / 255;
    uint8_t g = (color->g * s_led_state.brightness) / 255;
    uint8_t b = (color->b * s_led_state.brightness) / 255;

    // Устанавливаем цвет для всех светодиодов (формат GRB)
    for (int i = 0; i < s_led_state.led_count; i++) {
        s_led_state.led_strip_pixels[i * 3 + 0] = g; // Green
        s_led_state.led_strip_pixels[i * 3 + 1] = r; // Red
        s_led_state.led_strip_pixels[i * 3 + 2] = b; // Blue
    }

    return ESP_OK;
}

esp_err_t led_controller_set_color(int led_index, const led_rgb_t *color)
{
    if (!s_led_state.initialized || !color) {
        return ESP_ERR_INVALID_STATE;
    }
    
    if (led_index < 0 || led_index >= s_led_state.led_count) {
        ESP_LOGE(TAG, "Invalid LED index: %d", led_index);
        return ESP_ERR_INVALID_ARG;
    }

    // Применяем яркость к цвету
    uint8_t r = (color->r * s_led_state.brightness) / 255;
    uint8_t g = (color->g * s_led_state.brightness) / 255;
    uint8_t b = (color->b * s_led_state.brightness) / 255;

    // Устанавливаем цвет для конкретного светодиода (формат GRB)
    s_led_state.led_strip_pixels[led_index * 3 + 0] = g; // Green
    s_led_state.led_strip_pixels[led_index * 3 + 1] = r; // Red
    s_led_state.led_strip_pixels[led_index * 3 + 2] = b; // Blue

    return ESP_OK;
}

esp_err_t led_controller_update(void)
{
    if (!s_led_state.initialized) {
        return ESP_ERR_INVALID_STATE;
    }

    rmt_transmit_config_t tx_config = {
        .loop_count = 0, // no transfer loop
    };

    esp_err_t ret = rmt_transmit(s_led_state.led_chan, s_led_state.led_encoder, 
                                 s_led_state.led_strip_pixels, 
                                 s_led_state.led_count * 3, &tx_config);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Failed to transmit LED data: %s", esp_err_to_name(ret));
        return ret;
    }

    ret = rmt_tx_wait_all_done(s_led_state.led_chan, portMAX_DELAY);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Failed to wait for transmission: %s", esp_err_to_name(ret));
        return ret;
    }

    return ESP_OK;
}

esp_err_t led_controller_clear(void)
{
    if (!s_led_state.initialized) {
        return ESP_ERR_INVALID_STATE;
    }

    memset(s_led_state.led_strip_pixels, 0, s_led_state.led_count * 3);
    return led_controller_update();
}

esp_err_t led_controller_set_brightness(uint8_t brightness)
{
    if (!s_led_state.initialized) {
        return ESP_ERR_INVALID_STATE;
    }

    s_led_state.brightness = brightness;
    ESP_LOGI(TAG, "Brightness set to %d", brightness);
    
    // Переприменяем текущий цвет с новой яркостью
    return led_controller_set_all_color(&s_led_state.current_color);
}

int led_controller_get_led_count(void)
{
    return s_led_state.initialized ? s_led_state.led_count : -1;
}