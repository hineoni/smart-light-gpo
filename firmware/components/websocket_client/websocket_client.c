#include "websocket_client.h"
#include "servo_controller.h"
#include "led_controller.h"
#include "cJSON.h"
#include "esp_log.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include <string.h>
#include <stdio.h>

#define HEARTBEAT_INTERVAL_MS 15000  // 15 секунд между heartbeat сообщениями (было 5)

static const char *TAG = "WS_CLIENT";

static esp_websocket_client_handle_t s_websocket_client = NULL;
static device_config_t s_device_config = {0};
static bool s_is_connected = false;
static TickType_t s_last_heartbeat = 0;
static bool s_last_send_failed = false;  // Флаг последней ошибки отправки

/**
 * @brief Парсинг URL для получения хоста, порта и пути
 */
static esp_err_t parse_websocket_url(const char* url, char* host, int* port, char* path, bool* is_secure)
{
    *is_secure = false;
    *port = 80;
    strcpy(path, "/");
    
    // Проверяем протокол
    if (strncmp(url, "wss://", 6) == 0) {
        *is_secure = true;
        *port = 443;
        url += 6;
    } else if (strncmp(url, "ws://", 5) == 0) {
        *is_secure = false;
        *port = 80;
        url += 5;
    }
    
    // Ищем первый слэш для разделения host:port и path
    const char* slash = strchr(url, '/');
    if (slash != NULL) {
        // Копируем путь
        strncpy(path, slash, 255);
        path[255] = '\0';
        
        // Копируем хост:порт
        int host_len = slash - url;
        strncpy(host, url, host_len);
        host[host_len] = '\0';
    } else {
        // Нет пути, только хост:порт
        strncpy(host, url, 255);
        host[255] = '\0';
    }
    
    // Ищем двоеточие для разделения хоста и порта
    char* colon = strchr(host, ':');
    if (colon != NULL) {
        *colon = '\0';
        *port = atoi(colon + 1);
    }
    
    return ESP_OK;
}

/**
 * @brief Отправить JSON сообщение через WebSocket с retry
 */
static esp_err_t send_json_message(cJSON* json)
{
    if (s_websocket_client == NULL) {
        ESP_LOGE(TAG, "WebSocket client is NULL");
        return ESP_ERR_INVALID_STATE;
    }
    
    if (!s_is_connected) {
        ESP_LOGE(TAG, "WebSocket not connected");
        return ESP_ERR_INVALID_STATE;
    }
    
    char* json_string = cJSON_Print(json);
    if (json_string == NULL) {
        ESP_LOGE(TAG, "Failed to serialize JSON to string - out of memory?");
        return ESP_ERR_NO_MEM;
    }
    
    size_t msg_len = strlen(json_string);
    ESP_LOGD(TAG, "Sending JSON message (%d bytes): %s", msg_len, json_string);
    
    esp_err_t ret = ESP_FAIL;
    int retry_count = 3;
    
    // Пробуем отправить с retry
    for (int i = 0; i < retry_count; i++) {
        ret = esp_websocket_client_send_text(s_websocket_client, json_string, msg_len, pdMS_TO_TICKS(1000));
        
        if (ret == ESP_OK) {
            ESP_LOGD(TAG, "Message sent successfully on attempt %d", i + 1);
            break;
        } else {
            ESP_LOGW(TAG, "Send attempt %d failed: %s (error code 0x%x)", 
                     i + 1, esp_err_to_name(ret), ret);
            
            if (i < retry_count - 1) {
                ESP_LOGD(TAG, "Retrying in 100ms...");
                vTaskDelay(pdMS_TO_TICKS(100));
            }
        }
    }
    
    if (ret != ESP_OK) {
        s_last_send_failed = true;
        
        // Логируем ошибки только первый раз, потом ждем ACK
        if (!s_last_send_failed || (ret != 0x56)) { // 0x56 - известная ложная ошибка
            ESP_LOGW(TAG, "esp_websocket_client_send_text failed after %d attempts: %s (error code 0x%x)", 
                     retry_count, esp_err_to_name(ret), ret);
                     
            // Проверяем состояние клиента
            if (esp_websocket_client_is_connected(s_websocket_client)) {
                ESP_LOGD(TAG, "WebSocket reports as connected but send failed (may be false positive)");
            } else {
                ESP_LOGE(TAG, "WebSocket reports as disconnected");
                s_is_connected = false;
            }
        }
    } else {
        s_last_send_failed = false;
    }
    
    free(json_string);
    return ret;
}

/**
 * @brief Обработка входящих WebSocket сообщений
 */
static esp_err_t handle_websocket_message(const char* data, int len)
{
    char* json_str = malloc(len + 1);
    if (json_str == NULL) {
        ESP_LOGE(TAG, "Failed to allocate memory for message");
        return ESP_ERR_NO_MEM;
    }
    
    memcpy(json_str, data, len);
    json_str[len] = '\0';
    
    ESP_LOGI(TAG, "Received message: %s", json_str);
    
    cJSON* json = cJSON_Parse(json_str);
    free(json_str);
    
    if (json == NULL) {
        ESP_LOGE(TAG, "Failed to parse JSON message");
        return ESP_ERR_INVALID_ARG;
    }
    
    cJSON* type_item = cJSON_GetObjectItem(json, "type");
    if (type_item == NULL || !cJSON_IsString(type_item)) {
        ESP_LOGE(TAG, "Message has no 'type' field");
        cJSON_Delete(json);
        return ESP_ERR_INVALID_ARG;
    }
    
    const char* type = type_item->valuestring;
    
    if (strcmp(type, "set_servo") == 0) {
        cJSON* id_item = cJSON_GetObjectItem(json, "id");
        cJSON* angle_item = cJSON_GetObjectItem(json, "angle");
        
        if (cJSON_IsNumber(id_item) && cJSON_IsNumber(angle_item)) {
            int id = id_item->valueint;
            int angle = angle_item->valueint;
            
            if (id >= 1 && id <= 2 && angle >= 0 && angle <= 180) {
                servo_controller_move_to(id, angle, true);
                ESP_LOGI(TAG, "Moving servo %d to %d degrees", id, angle);
            } else {
                ESP_LOGE(TAG, "Invalid servo command: id=%d, angle=%d", id, angle);
            }
        }
    } else if (strcmp(type, "set_led_color") == 0) {
        cJSON* r_item = cJSON_GetObjectItem(json, "r");
        cJSON* g_item = cJSON_GetObjectItem(json, "g");
        cJSON* b_item = cJSON_GetObjectItem(json, "b");
        
        if (cJSON_IsNumber(r_item) && cJSON_IsNumber(g_item) && cJSON_IsNumber(b_item)) {
            led_rgb_t color = {
                .r = (uint8_t)r_item->valueint,
                .g = (uint8_t)g_item->valueint,
                .b = (uint8_t)b_item->valueint
            };
            
            esp_err_t ret = led_controller_set_all_color(&color);
            if (ret == ESP_OK) {
                ret = led_controller_update();
                if (ret == ESP_OK) {
                    ESP_LOGI(TAG, "LED color set to R=%d G=%d B=%d", color.r, color.g, color.b);
                } else {
                    ESP_LOGE(TAG, "Failed to update LED strip");
                }
            } else {
                ESP_LOGE(TAG, "Failed to set LED color");
            }
        }
    } else if (strcmp(type, "set_led_brightness") == 0) {
        cJSON* brightness_item = cJSON_GetObjectItem(json, "brightness");
        
        if (cJSON_IsNumber(brightness_item)) {
            uint8_t brightness = (uint8_t)brightness_item->valueint;
            
            esp_err_t ret = led_controller_set_brightness(brightness);
            if (ret == ESP_OK) {
                // Нужно обновить LED ленту чтобы применить новую яркость
                ret = led_controller_update();
                if (ret == ESP_OK) {
                    ESP_LOGI(TAG, "LED brightness set to %d", brightness);
                } else {
                    ESP_LOGE(TAG, "Failed to update LED strip with new brightness");
                }
            } else {
                ESP_LOGE(TAG, "Failed to set LED brightness");
            }
        }
    } else if (strcmp(type, "clear_leds") == 0) {
        esp_err_t ret = led_controller_clear();
        if (ret == ESP_OK) {
            ESP_LOGI(TAG, "LEDs cleared");
        } else {
            ESP_LOGE(TAG, "Failed to clear LEDs");
        }
    } else if (strcmp(type, "ack") == 0) {
        // Heartbeat ACK - это нормально, сбрасываем флаг ошибки
        ESP_LOGD(TAG, "Received heartbeat ACK");
        // Если получили ACK, значит предыдущая отправка была успешной несмотря на ошибку
        s_last_send_failed = false;
    } else if (strcmp(type, "error") == 0) {
        cJSON* error_item = cJSON_GetObjectItem(json, "error");
        const char* error_msg = cJSON_IsString(error_item) ? error_item->valuestring : "unknown";
        ESP_LOGE(TAG, "Server error: %s", error_msg);
    } else {
        ESP_LOGW(TAG, "Unknown message type: %s", type);
    }
    
    cJSON_Delete(json);
    return ESP_OK;
}

/**
 * @brief Обработчик событий WebSocket
 */
static void websocket_event_handler(void* handler_args, esp_event_base_t base, int32_t event_id, void* event_data)
{
    esp_websocket_event_data_t* data = (esp_websocket_event_data_t*)event_data;
    
    switch (event_id) {
        case WEBSOCKET_EVENT_CONNECTED:
            ESP_LOGI(TAG, "WebSocket connected");
            s_is_connected = true;
            
            // Отправляем сообщение регистрации
            cJSON* register_json = cJSON_CreateObject();
            cJSON_AddStringToObject(register_json, "type", "register");
            cJSON_AddStringToObject(register_json, "deviceId", s_device_config.device_id);
            
            esp_err_t ret = send_json_message(register_json);
            if (ret == ESP_OK) {
                ESP_LOGI(TAG, "Registration message sent: deviceId=%s", s_device_config.device_id);
            } else {
                ESP_LOGE(TAG, "Failed to send registration message");
            }
            
            cJSON_Delete(register_json);
            break;
            
        case WEBSOCKET_EVENT_DISCONNECTED:
            ESP_LOGI(TAG, "WebSocket disconnected");
            s_is_connected = false;
            break;
            
        case WEBSOCKET_EVENT_DATA:
            if (data->op_code == 0x01) { // Text frame
                handle_websocket_message(data->data_ptr, data->data_len);
            }
            break;
            
        case WEBSOCKET_EVENT_ERROR:
            ESP_LOGE(TAG, "WebSocket error");
            s_is_connected = false;
            break;
            
        default:
            ESP_LOGD(TAG, "Other WebSocket event: %d", (int)event_id);
            break;
    }
}

esp_err_t websocket_client_init(const device_config_t* config)
{
    if (config == NULL || !config->is_valid) {
        ESP_LOGE(TAG, "Invalid configuration");
        return ESP_ERR_INVALID_ARG;
    }
    
    s_device_config = *config;
    
    // Парсим URL
    char host[256];
    int port;
    char path[256];
    bool is_secure;
    
    esp_err_t ret = parse_websocket_url(config->backend_url, host, &port, path, &is_secure);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Failed to parse WebSocket URL: %s", config->backend_url);
        return ret;
    }
    
    // Создаем полный URI
    char uri[768];
    snprintf(uri, sizeof(uri), "%s://%s:%d%s", 
             is_secure ? "wss" : "ws", host, port, path);
    
    ESP_LOGI(TAG, "Connecting to WebSocket: %s", uri);
    
    esp_websocket_client_config_t websocket_cfg = {
        .uri = uri,
        .buffer_size = 1024,           // Увеличиваем буфер отправки
        .task_stack = 4096,            // Увеличиваем стек задачи
        .task_prio = 5,                // Приоритет задачи
        .keep_alive_idle = 60,         // Keep-alive параметры (исправлено)
        .keep_alive_interval = 5,      // (исправлено)
        .keep_alive_count = 3,         // (исправлено)
        .network_timeout_ms = 10000,   // Таймауты сети
        .user_context = NULL,
        .cert_pem = NULL
    };
    
    s_websocket_client = esp_websocket_client_init(&websocket_cfg);
    if (s_websocket_client == NULL) {
        ESP_LOGE(TAG, "Failed to initialize WebSocket client");
        return ESP_FAIL;
    }
    
    ret = esp_websocket_register_events(s_websocket_client, WEBSOCKET_EVENT_ANY, websocket_event_handler, NULL);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Failed to register WebSocket event handler");
        esp_websocket_client_destroy(s_websocket_client);
        s_websocket_client = NULL;
        return ret;
    }
    
    s_last_heartbeat = xTaskGetTickCount();
    
    ESP_LOGI(TAG, "WebSocket client initialized");
    return ESP_OK;
}

esp_err_t websocket_client_start(void)
{
    if (s_websocket_client == NULL) {
        ESP_LOGE(TAG, "WebSocket client not initialized");
        return ESP_ERR_INVALID_STATE;
    }
    
    return esp_websocket_client_start(s_websocket_client);
}

esp_err_t websocket_client_stop(void)
{
    if (s_websocket_client == NULL) {
        return ESP_OK;
    }
    
    s_is_connected = false;
    return esp_websocket_client_stop(s_websocket_client);
}

bool websocket_client_is_connected(void)
{
    return s_is_connected;
}

esp_err_t websocket_client_send_heartbeat(void)
{
    if (!s_is_connected) {
        ESP_LOGW(TAG, "Cannot send heartbeat: WebSocket not connected");
        return ESP_ERR_INVALID_STATE;
    }
    
    if (s_websocket_client == NULL) {
        ESP_LOGE(TAG, "Cannot send heartbeat: WebSocket client is NULL");
        return ESP_ERR_INVALID_STATE;
    }
    
    servo_status_t status;
    servo_controller_get_status(&status);
    
    cJSON* heartbeat_json = cJSON_CreateObject();
    if (heartbeat_json == NULL) {
        ESP_LOGE(TAG, "Failed to create heartbeat JSON object - out of memory?");
        return ESP_ERR_NO_MEM;
    }
    
    cJSON_AddStringToObject(heartbeat_json, "type", "heartbeat");
    
    cJSON* servo1 = cJSON_CreateObject();
    if (servo1 == NULL) {
        ESP_LOGE(TAG, "Failed to create servo1 JSON object");
        cJSON_Delete(heartbeat_json);
        return ESP_ERR_NO_MEM;
    }
    cJSON_AddNumberToObject(servo1, "angle", status.angle1);
    cJSON_AddItemToObject(heartbeat_json, "servo1", servo1);
    
    cJSON* servo2 = cJSON_CreateObject();
    if (servo2 == NULL) {
        ESP_LOGE(TAG, "Failed to create servo2 JSON object");
        cJSON_Delete(heartbeat_json);
        return ESP_ERR_NO_MEM;
    }
    cJSON_AddNumberToObject(servo2, "angle", status.angle2);
    cJSON_AddItemToObject(heartbeat_json, "servo2", servo2);
    
    ESP_LOGD(TAG, "Sending heartbeat with servo1=%d, servo2=%d", status.angle1, status.angle2);
    
    esp_err_t ret = send_json_message(heartbeat_json);
    cJSON_Delete(heartbeat_json);
    
    if (ret == ESP_OK) {
        ESP_LOGD(TAG, "Heartbeat sent successfully");
    } else {
        // Не логируем ошибку 0x56 как критическую - это известный баг ESP-IDF
        if (ret == 0x56) {
            ESP_LOGD(TAG, "Heartbeat send returned 0x56 (false error - message likely delivered)");
        } else {
            ESP_LOGE(TAG, "Failed to send heartbeat: %s (error code 0x%x)", esp_err_to_name(ret), ret);
            
            // Дополнительная диагностика
            if (ret == ESP_ERR_INVALID_STATE) {
                ESP_LOGE(TAG, "WebSocket client state issue - client may be disconnecting");
            } else if (ret == ESP_ERR_NO_MEM) {
                ESP_LOGE(TAG, "Out of memory when sending heartbeat");
            } else if (ret == ESP_ERR_TIMEOUT) {
                ESP_LOGE(TAG, "Timeout when sending heartbeat - connection may be slow");
            } else {
                ESP_LOGE(TAG, "Unknown error when sending heartbeat");
            }
        }
    }
    
    return ret;
}

void websocket_client_heartbeat_task(void)
{
    TickType_t current_time = xTaskGetTickCount();
    
    // Отправляем heartbeat каждые HEARTBEAT_INTERVAL_MS миллисекунд
    if ((current_time - s_last_heartbeat) >= pdMS_TO_TICKS(HEARTBEAT_INTERVAL_MS)) {
        if (s_is_connected) {
            websocket_client_send_heartbeat();
        }
        s_last_heartbeat = current_time;
    }
}

void websocket_client_deinit(void)
{
    if (s_websocket_client != NULL) {
        websocket_client_stop();
        esp_websocket_client_destroy(s_websocket_client);
        s_websocket_client = NULL;
    }
    
    s_is_connected = false;
    ESP_LOGI(TAG, "WebSocket client deinitialized");
}