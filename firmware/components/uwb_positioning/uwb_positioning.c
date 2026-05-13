#include "uwb_positioning.h"

#include "driver/gpio.h"
#include "esp_log.h"
#include "esp_timer.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include <string.h>

#define UWB_DIAGNOSTIC_INTERVAL_MS 1000
#define UWB_DIAGNOSTIC_BITS 32

static const char *TAG = "UWB_POSITIONING";

static uwb_positioning_config_t s_config = {
    .sdo_pin = 19,
    .sck_pin = 18,
    .rst_pin = 27,
};

static bool s_ready = false;
static int64_t s_last_diag_ms = 0;
static uint32_t s_last_sample = 0;
static uwb_range_t s_ranges[UWB_MAX_RANGES] = {0};

static int64_t now_ms(void)
{
    return esp_timer_get_time() / 1000;
}

static uint32_t read_diagnostic_sample(void)
{
    uint32_t sample = 0;

    for (int i = 0; i < UWB_DIAGNOSTIC_BITS; i++) {
        gpio_set_level((gpio_num_t)s_config.sck_pin, 0);
        esp_rom_delay_us(5);
        gpio_set_level((gpio_num_t)s_config.sck_pin, 1);
        esp_rom_delay_us(5);

        sample = (sample << 1) | (gpio_get_level((gpio_num_t)s_config.sdo_pin) & 0x01);
    }

    gpio_set_level((gpio_num_t)s_config.sck_pin, 0);
    return sample;
}

esp_err_t uwb_positioning_init(const uwb_positioning_config_t *config)
{
    if (config != NULL) {
        s_config = *config;
    }

    gpio_config_t output_conf = {
        .pin_bit_mask = (1ULL << s_config.sck_pin) | (1ULL << s_config.rst_pin),
        .mode = GPIO_MODE_OUTPUT,
        .pull_up_en = GPIO_PULLUP_DISABLE,
        .pull_down_en = GPIO_PULLDOWN_DISABLE,
        .intr_type = GPIO_INTR_DISABLE,
    };
    esp_err_t ret = gpio_config(&output_conf);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Failed to configure SCK/RST GPIO: %s", esp_err_to_name(ret));
        return ret;
    }

    gpio_config_t input_conf = {
        .pin_bit_mask = (1ULL << s_config.sdo_pin),
        .mode = GPIO_MODE_INPUT,
        .pull_up_en = GPIO_PULLUP_ENABLE,
        .pull_down_en = GPIO_PULLDOWN_DISABLE,
        .intr_type = GPIO_INTR_DISABLE,
    };
    ret = gpio_config(&input_conf);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Failed to configure SDO GPIO: %s", esp_err_to_name(ret));
        return ret;
    }

    gpio_set_level((gpio_num_t)s_config.sck_pin, 0);

    ESP_LOGI(TAG, "Resetting UWB module: SDO=GPIO%d SCK=GPIO%d RST=GPIO%d",
             s_config.sdo_pin, s_config.sck_pin, s_config.rst_pin);

    gpio_set_level((gpio_num_t)s_config.rst_pin, 0);
    vTaskDelay(pdMS_TO_TICKS(20));
    gpio_set_level((gpio_num_t)s_config.rst_pin, 1);
    vTaskDelay(pdMS_TO_TICKS(100));

    memset(s_ranges, 0, sizeof(s_ranges));
    s_last_sample = read_diagnostic_sample();
    s_last_diag_ms = now_ms();
    s_ready = true;

    ESP_LOGI(TAG, "UWB diagnostic sample after reset: 0x%08lx", (unsigned long)s_last_sample);
    ESP_LOGW(TAG, "UWB protocol is not decoded yet. Distance list will stay empty until module data format is mapped.");

    return ESP_OK;
}

void uwb_positioning_task(void)
{
    if (!s_ready) {
        return;
    }

    int64_t current_ms = now_ms();
    if ((current_ms - s_last_diag_ms) < UWB_DIAGNOSTIC_INTERVAL_MS) {
        return;
    }

    uint32_t sample = read_diagnostic_sample();
    if (sample != s_last_sample) {
        ESP_LOGI(TAG, "UWB diagnostic sample changed: 0x%08lx -> 0x%08lx",
                 (unsigned long)s_last_sample, (unsigned long)sample);
        s_last_sample = sample;
    } else {
        ESP_LOGD(TAG, "UWB diagnostic sample unchanged: 0x%08lx", (unsigned long)sample);
    }

    s_last_diag_ms = current_ms;
}

size_t uwb_positioning_get_ranges(uwb_range_t *ranges, size_t max_ranges)
{
    if (ranges == NULL || max_ranges == 0) {
        return 0;
    }

    size_t count = 0;
    for (size_t i = 0; i < UWB_MAX_RANGES && count < max_ranges; i++) {
        if (s_ranges[i].valid) {
            ranges[count++] = s_ranges[i];
        }
    }

    return count;
}

bool uwb_positioning_is_ready(void)
{
    return s_ready;
}
