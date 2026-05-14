#pragma once

#include "esp_err.h"
#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

#define UWB_MAX_RANGES 3
#define UWB_PEER_ID_LEN 32

typedef struct {
    char peer_id[UWB_PEER_ID_LEN];
    float distance_m;
    int rssi_dbm;
    int64_t updated_at_ms;
    bool valid;
} uwb_range_t;

typedef struct {
    int uart_num;
    int tx_pin;
    int rx_pin;
    int baud_rate;
    bool auto_config_enabled;
    int role;
    uint8_t pid;
    uint8_t period;
    uint16_t local_address;
    uint16_t peer0_address;
} uwb_positioning_config_t;

typedef struct {
    uint32_t total_bytes;
    uint32_t discarded_bytes;
    uint32_t parsed_frames;
    uint32_t invalid_frames;
    uint32_t parsed_lines;
    uint32_t invalid_lines;
    int64_t last_byte_at_ms;
    char last_rx_hex[96];
    bool auto_config_enabled;
    int role;
    uint8_t pid;
    uint8_t period;
    uint16_t local_address;
    uint16_t peer0_address;
} uwb_positioning_stats_t;

esp_err_t uwb_positioning_init(const uwb_positioning_config_t *config);
void uwb_positioning_task(void);
size_t uwb_positioning_get_ranges(uwb_range_t *ranges, size_t max_ranges);
bool uwb_positioning_is_ready(void);
void uwb_positioning_get_stats(uwb_positioning_stats_t *stats);

#ifdef __cplusplus
}
#endif
