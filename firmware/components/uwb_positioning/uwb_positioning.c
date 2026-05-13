#include "uwb_positioning.h"

#include "driver/uart.h"
#include "esp_log.h"
#include "esp_timer.h"
#include "freertos/FreeRTOS.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define UWB_DIAGNOSTIC_INTERVAL_MS 1000
#define UWB_RX_BUFFER_SIZE 1024
#define UWB_LINE_BUFFER_SIZE 128
#define UWB_MAX_LINES_PER_POLL 8

static const char *TAG = "UWB_POSITIONING";

static uwb_positioning_config_t s_config = {
    .uart_num = UART_NUM_1,
    .tx_pin = 18,
    .rx_pin = 19,
    .baud_rate = 115200,
};

static bool s_ready = false;
static int64_t s_last_diag_ms = 0;
static uwb_range_t s_ranges[UWB_MAX_RANGES] = {0};
static char s_line_buffer[UWB_LINE_BUFFER_SIZE];
static size_t s_line_length = 0;

static int64_t now_ms(void)
{
    return esp_timer_get_time() / 1000;
}

static void trim_line(char *line)
{
    size_t len = strlen(line);
    while (len > 0) {
        char c = line[len - 1];
        if (c != '\r' && c != '\n' && c != ' ' && c != '\t') {
            break;
        }
        line[--len] = '\0';
    }
}

static bool parse_range_line(const char *line, uwb_range_t *range)
{
    char peer_id[UWB_PEER_ID_LEN] = {0};
    float distance_m = 0.0f;

    if (sscanf(line, "DIST,%31[^,],%f", peer_id, &distance_m) == 2 ||
        sscanf(line, "DIST:%31[^:]:%f", peer_id, &distance_m) == 2 ||
        sscanf(line, "%31[^,],%f", peer_id, &distance_m) == 2 ||
        sscanf(line, "%31[^:]:%f", peer_id, &distance_m) == 2) {
        if (peer_id[0] == '\0' || distance_m < 0.0f || distance_m > 100.0f) {
            return false;
        }

        memset(range, 0, sizeof(*range));
        snprintf(range->peer_id, sizeof(range->peer_id), "%s", peer_id);
        range->distance_m = distance_m;
        range->updated_at_ms = now_ms();
        range->valid = true;
        return true;
    }

    return false;
}

static void upsert_range(const uwb_range_t *range)
{
    size_t free_index = UWB_MAX_RANGES;

    for (size_t i = 0; i < UWB_MAX_RANGES; i++) {
        if (s_ranges[i].valid && strncmp(s_ranges[i].peer_id, range->peer_id, UWB_PEER_ID_LEN) == 0) {
            s_ranges[i] = *range;
            return;
        }

        if (!s_ranges[i].valid && free_index == UWB_MAX_RANGES) {
            free_index = i;
        }
    }

    if (free_index < UWB_MAX_RANGES) {
        s_ranges[free_index] = *range;
        return;
    }

    size_t oldest_index = 0;
    for (size_t i = 1; i < UWB_MAX_RANGES; i++) {
        if (s_ranges[i].updated_at_ms < s_ranges[oldest_index].updated_at_ms) {
            oldest_index = i;
        }
    }
    s_ranges[oldest_index] = *range;
}

static void process_uart_line(char *line)
{
    trim_line(line);
    if (line[0] == '\0') {
        return;
    }

    ESP_LOGI(TAG, "UWB UART line: %s", line);

    uwb_range_t range;
    if (parse_range_line(line, &range)) {
        upsert_range(&range);
        ESP_LOGI(TAG, "Parsed UWB range: peer=%s distance=%.3fm",
                 range.peer_id, (double)range.distance_m);
        return;
    }

    ESP_LOGW(TAG, "UWB line format is not recognized yet");
}

esp_err_t uwb_positioning_init(const uwb_positioning_config_t *config)
{
    if (config != NULL) {
        s_config = *config;
    }

    uart_config_t uart_config = {
        .baud_rate = s_config.baud_rate,
        .data_bits = UART_DATA_8_BITS,
        .parity = UART_PARITY_DISABLE,
        .stop_bits = UART_STOP_BITS_1,
        .flow_ctrl = UART_HW_FLOWCTRL_DISABLE,
        .source_clk = UART_SCLK_DEFAULT,
    };

    esp_err_t ret = uart_driver_install(s_config.uart_num, UWB_RX_BUFFER_SIZE, 0, 0, NULL, 0);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Failed to install UART driver: %s", esp_err_to_name(ret));
        return ret;
    }

    ret = uart_param_config(s_config.uart_num, &uart_config);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Failed to configure UART: %s", esp_err_to_name(ret));
        uart_driver_delete(s_config.uart_num);
        return ret;
    }

    ret = uart_set_pin(s_config.uart_num, s_config.tx_pin, s_config.rx_pin,
                       UART_PIN_NO_CHANGE, UART_PIN_NO_CHANGE);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Failed to set UART pins: %s", esp_err_to_name(ret));
        uart_driver_delete(s_config.uart_num);
        return ret;
    }

    memset(s_ranges, 0, sizeof(s_ranges));
    memset(s_line_buffer, 0, sizeof(s_line_buffer));
    s_line_length = 0;
    s_last_diag_ms = now_ms();
    s_ready = true;

    ESP_LOGI(TAG, "Initialized UWB UART: uart=%d tx=GPIO%d rx=GPIO%d baud=%d",
             s_config.uart_num, s_config.tx_pin, s_config.rx_pin, s_config.baud_rate);
    ESP_LOGW(TAG, "Expecting text lines like 'DIST,<peer>,<meters>' or '<peer>,<meters>'");

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

    uint8_t rx_buffer[128];
    int processed_lines = 0;

    while (processed_lines < UWB_MAX_LINES_PER_POLL) {
        int bytes_read = uart_read_bytes(s_config.uart_num, rx_buffer, sizeof(rx_buffer), 0);
        if (bytes_read <= 0) {
            break;
        }

        for (int i = 0; i < bytes_read; i++) {
            char c = (char)rx_buffer[i];
            if (c == '\n' || c == '\r') {
                if (s_line_length > 0) {
                    s_line_buffer[s_line_length] = '\0';
                    process_uart_line(s_line_buffer);
                    s_line_length = 0;
                    processed_lines++;
                }
                continue;
            }

            if (s_line_length < (sizeof(s_line_buffer) - 1)) {
                s_line_buffer[s_line_length++] = c;
            } else {
                s_line_buffer[sizeof(s_line_buffer) - 1] = '\0';
                ESP_LOGW(TAG, "Dropping overlong UWB UART line: %s", s_line_buffer);
                s_line_length = 0;
            }
        }
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
