#include "uwb_positioning.h"

#include "driver/uart.h"
#include "esp_log.h"
#include "esp_timer.h"
#include "freertos/FreeRTOS.h"
#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define UWB_RX_BUFFER_SIZE 1024
#define UWB_LINE_BUFFER_SIZE 128
#define UWB_MAX_LINES_PER_POLL 8
#define UWB_FRAME_SIZE 8
#define UWB_FRAME_HEADER 0xF0
#define UWB_FRAME_PAYLOAD_LEN 0x05
#define UWB_FRAME_TAIL 0xAA
#define UWB_STALE_AFTER_MS 5000
#define UWB_LOG_INTERVAL_MS 1000

static const char *TAG = "UWB_POSITIONING";

static uwb_positioning_config_t s_config = {
    .uart_num = UART_NUM_1,
    .tx_pin = 18,
    .rx_pin = 19,
    .baud_rate = 115200,
};

static bool s_ready = false;
static int64_t s_last_log_ms = 0;
static int64_t s_last_rx_diag_ms = 0;
static uwb_range_t s_ranges[UWB_MAX_RANGES] = {0};
static uwb_positioning_stats_t s_stats = {0};
static char s_line_buffer[UWB_LINE_BUFFER_SIZE];
static size_t s_line_length = 0;
static uint8_t s_frame_buffer[UWB_FRAME_SIZE];
static size_t s_frame_length = 0;

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
        range->rssi_dbm = 0;
        range->updated_at_ms = now_ms();
        range->valid = true;
        return true;
    }

    return false;
}

static bool parse_mk8000_frame(const uint8_t *frame, uwb_range_t *range)
{
    if (frame[0] != UWB_FRAME_HEADER ||
        frame[1] != UWB_FRAME_PAYLOAD_LEN ||
        frame[7] != UWB_FRAME_TAIL) {
        return false;
    }

    uint16_t peer_addr = (uint16_t)frame[2] | ((uint16_t)frame[3] << 8);
    uint16_t distance_cm = (uint16_t)frame[4] | ((uint16_t)frame[5] << 8);
    int rssi_dbm = (int)frame[6] - 256;

    if (peer_addr == 0 || distance_cm > 10000) {
        return false;
    }

    memset(range, 0, sizeof(*range));
    snprintf(range->peer_id, sizeof(range->peer_id), "uwb_%04X", peer_addr);
    range->distance_m = (float)distance_cm / 100.0f;
    range->rssi_dbm = rssi_dbm;
    range->updated_at_ms = now_ms();
    range->valid = true;
    return true;
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

static bool should_log_now(void)
{
    int64_t current_ms = now_ms();
    if ((current_ms - s_last_log_ms) < UWB_LOG_INTERVAL_MS) {
        return false;
    }

    s_last_log_ms = current_ms;
    return true;
}

static void process_mk8000_frame(const uint8_t *frame)
{
    uwb_range_t range;
    if (parse_mk8000_frame(frame, &range)) {
        s_stats.parsed_frames++;
        upsert_range(&range);
        ESP_LOGI(TAG, "Parsed MK8000 range: peer=%s distance=%.2fm rssi=%ddBm",
                 range.peer_id, (double)range.distance_m, range.rssi_dbm);
        return;
    }

    s_stats.invalid_frames++;
    if (should_log_now()) {
        ESP_LOGW(TAG,
                 "Invalid MK8000 frame: %02X %02X %02X %02X %02X %02X %02X %02X",
                 frame[0], frame[1], frame[2], frame[3],
                 frame[4], frame[5], frame[6], frame[7]);
    }
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
        s_stats.parsed_lines++;
        upsert_range(&range);
        ESP_LOGI(TAG, "Parsed UWB range: peer=%s distance=%.3fm",
                 range.peer_id, (double)range.distance_m);
        return;
    }

    s_stats.invalid_lines++;
    ESP_LOGW(TAG, "UWB line format is not recognized yet");
}

static void log_rx_diagnostics(const uint8_t *bytes, int bytes_read)
{
    int64_t current_ms = now_ms();
    if ((current_ms - s_last_rx_diag_ms) < 5000) {
        return;
    }
    s_last_rx_diag_ms = current_ms;

    if (bytes_read <= 0) {
        ESP_LOGW(TAG,
                 "No UWB UART bytes yet: total=%" PRIu32 " frames=%" PRIu32 " invalidFrames=%" PRIu32
                 " lines=%" PRIu32 " invalidLines=%" PRIu32,
                 s_stats.total_bytes, s_stats.parsed_frames, s_stats.invalid_frames,
                 s_stats.parsed_lines, s_stats.invalid_lines);
        return;
    }

    char hex[sizeof(s_stats.last_rx_hex)] = {0};
    size_t offset = 0;
    int dump_len = bytes_read < 16 ? bytes_read : 16;
    for (int i = 0; i < dump_len && offset < sizeof(hex); i++) {
        int written = snprintf(hex + offset, sizeof(hex) - offset, "%02X%s", bytes[i], i == dump_len - 1 ? "" : " ");
        if (written <= 0) {
            break;
        }
        offset += (size_t)written;
    }

    ESP_LOGI(TAG, "UWB UART rx: bytes=%d total=%" PRIu32 " first=%s",
             bytes_read, s_stats.total_bytes, hex);
}

static void remember_rx_hex(const uint8_t *bytes, int bytes_read)
{
    if (bytes_read <= 0) {
        return;
    }

    size_t offset = 0;
    int dump_len = bytes_read < 16 ? bytes_read : 16;
    memset(s_stats.last_rx_hex, 0, sizeof(s_stats.last_rx_hex));
    for (int i = 0; i < dump_len && offset < sizeof(s_stats.last_rx_hex); i++) {
        int written = snprintf(s_stats.last_rx_hex + offset,
                               sizeof(s_stats.last_rx_hex) - offset,
                               "%02X%s", bytes[i], i == dump_len - 1 ? "" : " ");
        if (written <= 0) {
            break;
        }
        offset += (size_t)written;
    }
}

static void process_rx_byte(uint8_t byte, int *processed_lines)
{
    if (s_frame_length == 0) {
        if (byte == UWB_FRAME_HEADER) {
            s_frame_buffer[s_frame_length++] = byte;
            return;
        }
    } else {
        s_frame_buffer[s_frame_length++] = byte;

        if (s_frame_length == 2 && s_frame_buffer[1] != UWB_FRAME_PAYLOAD_LEN) {
            s_stats.invalid_frames++;
            if (should_log_now()) {
                ESP_LOGW(TAG, "Dropping MK8000 frame with unexpected length byte: 0x%02X", s_frame_buffer[1]);
            }
            s_frame_length = 0;
            return;
        }

        if (s_frame_length == UWB_FRAME_SIZE) {
            process_mk8000_frame(s_frame_buffer);
            s_frame_length = 0;
        }

        return;
    }

    char c = (char)byte;
    if (c == '\n' || c == '\r') {
        if (s_line_length > 0) {
            s_line_buffer[s_line_length] = '\0';
            process_uart_line(s_line_buffer);
            s_line_length = 0;
            (*processed_lines)++;
        }
        return;
    }

    if (c >= 32 && c <= 126) {
        if (s_line_length < (sizeof(s_line_buffer) - 1)) {
            s_line_buffer[s_line_length++] = c;
        } else {
            s_line_buffer[sizeof(s_line_buffer) - 1] = '\0';
            ESP_LOGW(TAG, "Dropping overlong UWB UART line: %s", s_line_buffer);
            s_line_length = 0;
        }
        return;
    }

    s_stats.discarded_bytes++;
    if (should_log_now()) {
        ESP_LOGW(TAG, "Discarding non-frame non-text UWB byte: 0x%02X", byte);
    }
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
    memset(&s_stats, 0, sizeof(s_stats));
    memset(s_line_buffer, 0, sizeof(s_line_buffer));
    s_line_length = 0;
    memset(s_frame_buffer, 0, sizeof(s_frame_buffer));
    s_frame_length = 0;
    s_last_log_ms = now_ms();
    s_last_rx_diag_ms = s_last_log_ms;
    s_ready = true;

    ESP_LOGI(TAG, "Initialized UWB UART: uart=%d tx=GPIO%d rx=GPIO%d baud=%d",
             s_config.uart_num, s_config.tx_pin, s_config.rx_pin, s_config.baud_rate);
    ESP_LOGI(TAG, "Expecting MK8000 binary frames: F0 05 <addr_lo> <addr_hi> <dist_lo> <dist_hi> <rssi> AA");
    ESP_LOGI(TAG, "Diagnostic text lines like 'DIST,<peer>,<meters>' remain supported");

    return ESP_OK;
}

void uwb_positioning_task(void)
{
    if (!s_ready) {
        return;
    }

    uint8_t rx_buffer[128];
    int processed_lines = 0;

    while (processed_lines < UWB_MAX_LINES_PER_POLL) {
        int bytes_read = uart_read_bytes(s_config.uart_num, rx_buffer, sizeof(rx_buffer), 0);
        if (bytes_read <= 0) {
            log_rx_diagnostics(NULL, 0);
            break;
        }

        s_stats.total_bytes += (uint32_t)bytes_read;
        s_stats.last_byte_at_ms = now_ms();
        remember_rx_hex(rx_buffer, bytes_read);
        log_rx_diagnostics(rx_buffer, bytes_read);

        for (int i = 0; i < bytes_read; i++) {
            process_rx_byte(rx_buffer[i], &processed_lines);
        }
    }
}

size_t uwb_positioning_get_ranges(uwb_range_t *ranges, size_t max_ranges)
{
    if (ranges == NULL || max_ranges == 0) {
        return 0;
    }

    size_t count = 0;
    int64_t current_ms = now_ms();
    for (size_t i = 0; i < UWB_MAX_RANGES && count < max_ranges; i++) {
        if (s_ranges[i].valid && (current_ms - s_ranges[i].updated_at_ms) <= UWB_STALE_AFTER_MS) {
            ranges[count++] = s_ranges[i];
        }
    }

    return count;
}

bool uwb_positioning_is_ready(void)
{
    return s_ready;
}

void uwb_positioning_get_stats(uwb_positioning_stats_t *stats)
{
    if (stats == NULL) {
        return;
    }
    *stats = s_stats;
}
