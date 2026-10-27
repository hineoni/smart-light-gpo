#pragma once

#include <stdbool.h>
#include <stdint.h>
#include "esp_err.h"

typedef struct {
    bool available;
    int raw;
    int percent;
    int64_t sampled_at_ms;
} light_sensor_reading_t;

// AO on GPIO34 / ADC1 channel 6. Does not access NVS or other peripherals.
esp_err_t light_sensor_init(void);
light_sensor_reading_t light_sensor_get_reading(void);
