#include "light_sensor.h"
#include "led_controller.h"
#include "esp_adc/adc_oneshot.h"
#include "esp_log.h"
#include "esp_timer.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

#define LIGHT_SENSOR_CHANNEL ADC_CHANNEL_6  // ESP32 GPIO34, ADC1 works with Wi-Fi.
#define LIGHT_SENSOR_SAMPLES 16
#define LIGHT_SENSOR_ADC_MAX 4095
#define LIGHT_SENSOR_INTERVAL_MS 250
#define LIGHT_SENSOR_STALE_MS 3000

static const char *TAG = "LIGHT_SENSOR";
static adc_oneshot_unit_handle_t s_adc;
static portMUX_TYPE s_lock = portMUX_INITIALIZER_UNLOCKED;
static light_sensor_reading_t s_reading;

light_sensor_reading_t light_sensor_get_reading(void)
{
    portENTER_CRITICAL(&s_lock);
    light_sensor_reading_t reading = s_reading;
    portEXIT_CRITICAL(&s_lock);
    if (esp_timer_get_time() / 1000 - reading.sampled_at_ms > LIGHT_SENSOR_STALE_MS) {
        reading.available = false;
    }
    return reading;
}

static void sample_task(void *arg)
{
    (void)arg;
    int filtered = -1;
    int log_counter = 0;
    while (true) {
        int total = 0;
        esp_err_t ret = ESP_OK;
        for (int i = 0; i < LIGHT_SENSOR_SAMPLES; i++) {
            int raw;
            ret = adc_oneshot_read(s_adc, LIGHT_SENSOR_CHANNEL, &raw);
            if (ret != ESP_OK) break;
            total += raw;
        }
        light_sensor_reading_t reading = {0};
        if (ret == ESP_OK) {
            int average = total / LIGHT_SENSOR_SAMPLES;
            filtered = filtered < 0 ? average : (3 * filtered + average) / 4;
            reading.available = true;
            reading.raw = filtered;
            // Typical LM393 LDR module: AO falls as ambient light increases.
            reading.percent = ((LIGHT_SENSOR_ADC_MAX - filtered) * 100 +
                               LIGHT_SENSOR_ADC_MAX / 2) / LIGHT_SENSOR_ADC_MAX;
            reading.sampled_at_ms = esp_timer_get_time() / 1000;
        }
        portENTER_CRITICAL(&s_lock);
        s_reading = reading;
        portEXIT_CRITICAL(&s_lock);

        // Machine-readable telemetry for the optional local USB bridge.
        if (log_counter++ % 4 == 0) {
            led_controller_status_t lamp = {0};
            led_controller_get_status(&lamp);
            ESP_LOGI(TAG, "SENSOR_DATA {\"available\":%s,\"raw\":%d,\"percent\":%d,"
                     "\"lamp\":{\"available\":%s,\"isOn\":%s,\"brightness\":%u,\"r\":%u,\"g\":%u,\"b\":%u}}",
                     reading.available ? "true" : "false", reading.raw, reading.percent,
                     lamp.available ? "true" : "false", lamp.is_on ? "true" : "false",
                     lamp.brightness, lamp.color.r, lamp.color.g, lamp.color.b);
        }
        vTaskDelay(pdMS_TO_TICKS(LIGHT_SENSOR_INTERVAL_MS));
    }
}

esp_err_t light_sensor_init(void)
{
    if (s_adc != NULL) return ESP_ERR_INVALID_STATE;
    const adc_oneshot_unit_init_cfg_t unit = {.unit_id = ADC_UNIT_1};
    esp_err_t ret = adc_oneshot_new_unit(&unit, &s_adc);
    if (ret != ESP_OK) return ret;
    const adc_oneshot_chan_cfg_t channel = {
        .atten = ADC_ATTEN_DB_12,
        .bitwidth = ADC_BITWIDTH_12,
    };
    ret = adc_oneshot_config_channel(s_adc, LIGHT_SENSOR_CHANNEL, &channel);
    if (ret == ESP_OK && xTaskCreate(sample_task, "light_sensor", 3072, NULL, 2, NULL) != pdPASS) {
        ret = ESP_ERR_NO_MEM;
    }
    if (ret != ESP_OK) {
        esp_err_t cleanup = adc_oneshot_del_unit(s_adc);
        if (cleanup != ESP_OK) ESP_LOGW(TAG, "ADC cleanup: %s", esp_err_to_name(cleanup));
        s_adc = NULL;
        return ret;
    }
    ESP_LOGI(TAG, "Ambient light sensor on GPIO34 (ADC1 channel 6)");
    return ESP_OK;
}
