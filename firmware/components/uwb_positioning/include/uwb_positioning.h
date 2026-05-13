#pragma once

#include "esp_err.h"
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

#define UWB_MAX_RANGES 3
#define UWB_PEER_ID_LEN 32

typedef struct {
    char peer_id[UWB_PEER_ID_LEN];
    float distance_m;
    int64_t updated_at_ms;
    bool valid;
} uwb_range_t;

typedef struct {
    int uart_num;
    int tx_pin;
    int rx_pin;
    int baud_rate;
} uwb_positioning_config_t;

esp_err_t uwb_positioning_init(const uwb_positioning_config_t *config);
void uwb_positioning_task(void);
size_t uwb_positioning_get_ranges(uwb_range_t *ranges, size_t max_ranges);
bool uwb_positioning_is_ready(void);

#ifdef __cplusplus
}
#endif
