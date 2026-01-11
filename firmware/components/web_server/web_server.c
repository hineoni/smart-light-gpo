#include "web_server.h"
#include "wifi_manager.h"
#include "servo_controller.h"
#include "led_controller.h"
#include "cJSON.h"
#include "esp_log.h"
#include "esp_spiffs.h"
#include <string.h>

static const char *TAG = "WEB_SERVER";

static httpd_handle_t s_server = NULL;
static device_config_t* s_device_config = NULL;

/**
 * @brief Инициализация SPIFFS
 */
static esp_err_t init_spiffs(void)
{
    esp_vfs_spiffs_conf_t conf = {
        .base_path = "/spiffs",
        .partition_label = NULL,
        .max_files = 5,
        .format_if_mount_failed = true
    };
    
    esp_err_t ret = esp_vfs_spiffs_register(&conf);
    if (ret != ESP_OK) {
        if (ret == ESP_FAIL) {
            ESP_LOGE(TAG, "Failed to mount or format filesystem");
        } else if (ret == ESP_ERR_NOT_FOUND) {
            ESP_LOGE(TAG, "Failed to find SPIFFS partition");
        } else {
            ESP_LOGE(TAG, "Failed to initialize SPIFFS (%s)", esp_err_to_name(ret));
        }
        return ret;
    }
    
    size_t total = 0, used = 0;
    ret = esp_spiffs_info(NULL, &total, &used);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Failed to get SPIFFS partition information (%s)", esp_err_to_name(ret));
    } else {
        ESP_LOGI(TAG, "SPIFFS partition size: total: %d, used: %d", total, used);
    }
    
    return ret;
}

/**
 * @brief Отправить JSON ответ
 */
static esp_err_t send_json_response(httpd_req_t* req, cJSON* json, int status_code)
{
    char* json_string = cJSON_Print(json);
    if (json_string == NULL) {
        httpd_resp_send_err(req, HTTPD_500_INTERNAL_SERVER_ERROR, "JSON serialization failed");
        return ESP_ERR_NO_MEM;
    }
    
    httpd_resp_set_type(req, "application/json");
    httpd_resp_set_status(req, status_code == 200 ? "200 OK" : "400 Bad Request");
    httpd_resp_send(req, json_string, strlen(json_string));
    
    free(json_string);
    return ESP_OK;
}

/**
 * @brief Обработчик главной страницы
 */
static esp_err_t root_handler(httpd_req_t* req)
{
    FILE* f = fopen("/spiffs/index.html", "r");
    if (f == NULL) {
        ESP_LOGE(TAG, "Failed to open index.html");
        httpd_resp_send_err(req, HTTPD_404_NOT_FOUND, "File not found");
        return ESP_FAIL;
    }
    
    httpd_resp_set_type(req, "text/html");
    
    char chunk[1024];
    size_t read_bytes;
    do {
        read_bytes = fread(chunk, 1, sizeof(chunk), f);
        if (read_bytes > 0) {
            httpd_resp_send_chunk(req, chunk, read_bytes);
        }
    } while (read_bytes > 0);
    
    fclose(f);
    httpd_resp_send_chunk(req, NULL, 0);
    return ESP_OK;
}

/**
 * @brief Обработчик статуса устройства
 */
static esp_err_t status_handler(httpd_req_t* req)
{
    servo_status_t servo_status;
    servo_controller_get_status(&servo_status);
    
    cJSON* json = cJSON_CreateObject();
    
    // WiFi статус
    if (wifi_manager_is_connected()) {
        cJSON_AddStringToObject(json, "wifi", "connected");
        
        esp_netif_ip_info_t ip_info;
        if (wifi_manager_get_ip(&ip_info) == ESP_OK) {
            char ip_str[16];
            sprintf(ip_str, IPSTR, IP2STR(&ip_info.ip));
            cJSON_AddStringToObject(json, "ip", ip_str);
        } else {
            cJSON_AddStringToObject(json, "ip", "0.0.0.0");
        }
    } else {
        cJSON_AddStringToObject(json, "wifi", "ap");
        
        esp_netif_ip_info_t ip_info;
        if (wifi_manager_get_ap_ip(&ip_info) == ESP_OK) {
            char ip_str[16];
            sprintf(ip_str, IPSTR, IP2STR(&ip_info.ip));
            cJSON_AddStringToObject(json, "ip", ip_str);
        } else {
            cJSON_AddStringToObject(json, "ip", "192.168.4.1"); // Default AP IP
        }
    }
    
    // Device ID
    cJSON_AddStringToObject(json, "deviceId", s_device_config->device_id);
    
    // Backend URL
    cJSON_AddStringToObject(json, "backendUrl", s_device_config->backend_url);
    
    // WiFi credentials (для заполнения формы)
    cJSON_AddStringToObject(json, "wifiSsid", s_device_config->wifi_ssid);
    cJSON_AddStringToObject(json, "wifiPass", s_device_config->wifi_pass);
    
    // Статус сервоприводов
    cJSON* servo1 = cJSON_CreateObject();
    cJSON_AddNumberToObject(servo1, "angle", servo_status.angle1);
    cJSON_AddBoolToObject(servo1, "moving", servo_status.moving1);
    cJSON_AddItemToObject(json, "servo1", servo1);
    
    cJSON* servo2 = cJSON_CreateObject();
    cJSON_AddNumberToObject(servo2, "angle", servo_status.angle2);
    cJSON_AddBoolToObject(servo2, "moving", servo_status.moving2);
    cJSON_AddItemToObject(json, "servo2", servo2);
    
    esp_err_t ret = send_json_response(req, json, 200);
    cJSON_Delete(json);
    return ret;
}

/**
 * @brief Обработчик для настройки backend URL после BLE provisioning
 */
static esp_err_t backend_config_handler(httpd_req_t* req)
{
    if (req->method != HTTP_POST) {
        httpd_resp_send_err(req, HTTPD_405_METHOD_NOT_ALLOWED, "Only POST allowed");
        return ESP_FAIL;
    }
    
    // Читаем тело запроса
    char* content = malloc(req->content_len + 1);
    if (content == NULL) {
        httpd_resp_send_err(req, HTTPD_500_INTERNAL_SERVER_ERROR, "Memory allocation failed");
        return ESP_ERR_NO_MEM;
    }
    
    int ret = httpd_req_recv(req, content, req->content_len);
    if (ret <= 0) {
        free(content);
        if (ret == HTTPD_SOCK_ERR_TIMEOUT) {
            httpd_resp_send_err(req, HTTPD_408_REQ_TIMEOUT, "Request timeout");
        } else {
            httpd_resp_send_err(req, HTTPD_400_BAD_REQUEST, "Failed to read request body");
        }
        return ESP_FAIL;
    }
    
    content[req->content_len] = '\0';
    
    // Парсим JSON
    cJSON* json = cJSON_Parse(content);
    free(content);
    
    if (json == NULL) {
        cJSON* error_json = cJSON_CreateObject();
        cJSON_AddStringToObject(error_json, "error", "invalid json");
        send_json_response(req, error_json, 400);
        cJSON_Delete(error_json);
        return ESP_FAIL;
    }
    
    // Получаем backend URL из JSON
    cJSON* backend_url = cJSON_GetObjectItem(json, "backend_url");
    cJSON* device_id = cJSON_GetObjectItem(json, "device_id");
    
    if (!cJSON_IsString(backend_url) || strlen(backend_url->valuestring) == 0) {
        cJSON* error_json = cJSON_CreateObject();
        cJSON_AddStringToObject(error_json, "error", "backend_url is required");
        send_json_response(req, error_json, 400);
        cJSON_Delete(error_json);
        cJSON_Delete(json);
        return ESP_FAIL;
    }
    
    // Обновляем backend URL в конфигурации
    strncpy(s_device_config->backend_url, backend_url->valuestring, sizeof(s_device_config->backend_url) - 1);
    s_device_config->backend_url[sizeof(s_device_config->backend_url) - 1] = '\0';
    
    // Обновляем device_id если передан
    if (cJSON_IsString(device_id) && strlen(device_id->valuestring) > 0) {
        strncpy(s_device_config->device_id, device_id->valuestring, sizeof(s_device_config->device_id) - 1);
        s_device_config->device_id[sizeof(s_device_config->device_id) - 1] = '\0';
    }
    
    // Обновляем валидность конфигурации
    s_device_config->is_valid = (strlen(s_device_config->wifi_ssid) > 0) && (strlen(s_device_config->backend_url) > 0);
    
    cJSON_Delete(json);
    
    // Сохраняем конфигурацию в NVS
    esp_err_t save_ret = config_storage_save(s_device_config);
    
    cJSON* response_json = cJSON_CreateObject();
    if (save_ret == ESP_OK) {
        cJSON_AddStringToObject(response_json, "status", "success");
        cJSON_AddStringToObject(response_json, "message", "Backend URL saved successfully");
        send_json_response(req, response_json, 200);
        
        ESP_LOGI(TAG, "Backend URL configured: %s", s_device_config->backend_url);
        if (strlen(s_device_config->device_id) > 0) {
            ESP_LOGI(TAG, "Device ID configured: %s", s_device_config->device_id);
        }
        
        // Отправляем событие для перезапуска WebSocket, если WiFi подключен
        ESP_LOGI(TAG, "Configuration updated, will attempt to restart WebSocket on next cycle");
        
    } else {
        cJSON_AddStringToObject(response_json, "status", "error");
        cJSON_AddStringToObject(response_json, "message", "Failed to save configuration");
        send_json_response(req, response_json, 500);
        ESP_LOGE(TAG, "Failed to save backend configuration: %s", esp_err_to_name(save_ret));
    }
    cJSON_Delete(response_json);
    
    return (save_ret == ESP_OK) ? ESP_OK : ESP_FAIL;
}

/**
 * @brief Обработчик сохранения конфигурации
 */
static esp_err_t config_handler(httpd_req_t* req)
{
    if (req->method != HTTP_POST) {
        httpd_resp_send_err(req, HTTPD_405_METHOD_NOT_ALLOWED, "Only POST allowed");
        return ESP_FAIL;
    }
    
    // Читаем тело запроса
    char* content = malloc(req->content_len + 1);
    if (content == NULL) {
        httpd_resp_send_err(req, HTTPD_500_INTERNAL_SERVER_ERROR, "Memory allocation failed");
        return ESP_ERR_NO_MEM;
    }
    
    int ret = httpd_req_recv(req, content, req->content_len);
    if (ret <= 0) {
        free(content);
        if (ret == HTTPD_SOCK_ERR_TIMEOUT) {
            httpd_resp_send_err(req, HTTPD_408_REQ_TIMEOUT, "Request timeout");
        } else {
            httpd_resp_send_err(req, HTTPD_400_BAD_REQUEST, "Failed to read request body");
        }
        return ESP_FAIL;
    }
    
    content[req->content_len] = '\0';
    
    // Парсим JSON
    cJSON* json = cJSON_Parse(content);
    free(content);
    
    if (json == NULL) {
        cJSON* error_json = cJSON_CreateObject();
        cJSON_AddStringToObject(error_json, "error", "json parse");
        send_json_response(req, error_json, 400);
        cJSON_Delete(error_json);
        return ESP_FAIL;
    }
    
    // Обновляем конфигурацию
    cJSON* wifi_ssid = cJSON_GetObjectItem(json, "wifiSsid");
    cJSON* wifi_pass = cJSON_GetObjectItem(json, "wifiPass");
    cJSON* backend_url = cJSON_GetObjectItem(json, "backendUrl");
    cJSON* device_id = cJSON_GetObjectItem(json, "deviceId");
    
    if (cJSON_IsString(wifi_ssid)) {
        strncpy(s_device_config->wifi_ssid, wifi_ssid->valuestring, sizeof(s_device_config->wifi_ssid) - 1);
        s_device_config->wifi_ssid[sizeof(s_device_config->wifi_ssid) - 1] = '\0';
    }
    
    if (cJSON_IsString(wifi_pass)) {
        strncpy(s_device_config->wifi_pass, wifi_pass->valuestring, sizeof(s_device_config->wifi_pass) - 1);
        s_device_config->wifi_pass[sizeof(s_device_config->wifi_pass) - 1] = '\0';
    }
    
    if (cJSON_IsString(backend_url)) {
        strncpy(s_device_config->backend_url, backend_url->valuestring, sizeof(s_device_config->backend_url) - 1);
        s_device_config->backend_url[sizeof(s_device_config->backend_url) - 1] = '\0';
    }
    
    if (cJSON_IsString(device_id)) {
        strncpy(s_device_config->device_id, device_id->valuestring, sizeof(s_device_config->device_id) - 1);
        s_device_config->device_id[sizeof(s_device_config->device_id) - 1] = '\0';
    }
    
    // Обновляем валидность
    s_device_config->is_valid = (strlen(s_device_config->wifi_ssid) > 0) && (strlen(s_device_config->backend_url) > 0);
    
    cJSON_Delete(json);
    
    // Сохраняем конфигурацию
    esp_err_t save_ret = config_storage_save(s_device_config);
    
    cJSON* response_json = cJSON_CreateObject();
    if (save_ret == ESP_OK) {
        cJSON_AddStringToObject(response_json, "status", "ok");
        send_json_response(req, response_json, 200);
    } else {
        cJSON_AddStringToObject(response_json, "status", "fail");
        send_json_response(req, response_json, 500);
    }
    cJSON_Delete(response_json);
    
    return (save_ret == ESP_OK) ? ESP_OK : ESP_FAIL;
}

/**
 * @brief Обработчик управления сервоприводами
 */
static esp_err_t servo_handler(httpd_req_t* req)
{
    if (req->method != HTTP_POST) {
        httpd_resp_send_err(req, HTTPD_405_METHOD_NOT_ALLOWED, "Only POST allowed");
        return ESP_FAIL;
    }
    
    // Читаем тело запроса
    char* content = malloc(req->content_len + 1);
    if (content == NULL) {
        httpd_resp_send_err(req, HTTPD_500_INTERNAL_SERVER_ERROR, "Memory allocation failed");
        return ESP_ERR_NO_MEM;
    }
    
    int ret = httpd_req_recv(req, content, req->content_len);
    if (ret <= 0) {
        free(content);
        httpd_resp_send_err(req, HTTPD_400_BAD_REQUEST, "Failed to read request body");
        return ESP_FAIL;
    }
    
    content[req->content_len] = '\0';
    
    // Парсим JSON
    cJSON* json = cJSON_Parse(content);
    free(content);
    
    if (json == NULL) {
        cJSON* error_json = cJSON_CreateObject();
        cJSON_AddStringToObject(error_json, "error", "bad json");
        send_json_response(req, error_json, 400);
        cJSON_Delete(error_json);
        return ESP_FAIL;
    }
    
    cJSON* id_item = cJSON_GetObjectItem(json, "id");
    cJSON* angle_item = cJSON_GetObjectItem(json, "angle");
    cJSON* smooth_item = cJSON_GetObjectItem(json, "smooth");
    
    if (!cJSON_IsNumber(id_item) || !cJSON_IsNumber(angle_item)) {
        cJSON* error_json = cJSON_CreateObject();
        cJSON_AddStringToObject(error_json, "error", "invalid parameters");
        send_json_response(req, error_json, 400);
        cJSON_Delete(error_json);
        cJSON_Delete(json);
        return ESP_FAIL;
    }
    
    int id = id_item->valueint;
    int angle = angle_item->valueint;
    bool smooth = cJSON_IsBool(smooth_item) ? cJSON_IsTrue(smooth_item) : true;
    
    if (id < 1 || id > 2) {
        cJSON* error_json = cJSON_CreateObject();
        cJSON_AddStringToObject(error_json, "error", "servo id");
        send_json_response(req, error_json, 400);
        cJSON_Delete(error_json);
        cJSON_Delete(json);
        return ESP_FAIL;
    }
    
    cJSON_Delete(json);
    
    // Управляем сервоприводом
    esp_err_t servo_ret = servo_controller_move_to(id, angle, smooth);
    
    cJSON* response_json = cJSON_CreateObject();
    if (servo_ret == ESP_OK) {
        cJSON_AddStringToObject(response_json, "status", "moving");
        send_json_response(req, response_json, 200);
    } else {
        cJSON_AddStringToObject(response_json, "status", "error");
        send_json_response(req, response_json, 500);
    }
    cJSON_Delete(response_json);
    
    return servo_ret;
}

/**
 * @brief Обработчик управления LED
 */
static esp_err_t led_handler(httpd_req_t* req)
{
    if (req->method != HTTP_POST) {
        httpd_resp_send_err(req, HTTPD_405_METHOD_NOT_ALLOWED, "Only POST allowed");
        return ESP_FAIL;
    }
    
    // Читаем тело запроса
    char* content = malloc(req->content_len + 1);
    if (content == NULL) {
        httpd_resp_send_err(req, HTTPD_500_INTERNAL_SERVER_ERROR, "Memory allocation failed");
        return ESP_ERR_NO_MEM;
    }
    
    int ret = httpd_req_recv(req, content, req->content_len);
    if (ret <= 0) {
        free(content);
        httpd_resp_send_err(req, HTTPD_400_BAD_REQUEST, "Failed to read request body");
        return ESP_FAIL;
    }
    
    content[req->content_len] = '\0';
    
    // Парсим JSON
    cJSON* json = cJSON_Parse(content);
    free(content);
    
    if (json == NULL) {
        cJSON* error_json = cJSON_CreateObject();
        cJSON_AddStringToObject(error_json, "error", "bad json");
        send_json_response(req, error_json, 400);
        cJSON_Delete(error_json);
        return ESP_FAIL;
    }
    
    cJSON* type_item = cJSON_GetObjectItem(json, "type");
    if (!cJSON_IsString(type_item)) {
        cJSON* error_json = cJSON_CreateObject();
        cJSON_AddStringToObject(error_json, "error", "missing type field");
        send_json_response(req, error_json, 400);
        cJSON_Delete(error_json);
        cJSON_Delete(json);
        return ESP_FAIL;
    }
    
    const char* type = type_item->valuestring;
    esp_err_t led_ret = ESP_OK;
    
    if (strcmp(type, "set_led_color") == 0) {
        cJSON* r_item = cJSON_GetObjectItem(json, "r");
        cJSON* g_item = cJSON_GetObjectItem(json, "g");
        cJSON* b_item = cJSON_GetObjectItem(json, "b");
        
        if (cJSON_IsNumber(r_item) && cJSON_IsNumber(g_item) && cJSON_IsNumber(b_item)) {
            led_rgb_t color = {
                .r = (uint8_t)r_item->valueint,
                .g = (uint8_t)g_item->valueint,
                .b = (uint8_t)b_item->valueint
            };
            
            led_ret = led_controller_set_all_color(&color);
            if (led_ret == ESP_OK) {
                led_ret = led_controller_update();
            }
        } else {
            led_ret = ESP_ERR_INVALID_ARG;
        }
    } else if (strcmp(type, "set_led_brightness") == 0) {
        cJSON* brightness_item = cJSON_GetObjectItem(json, "brightness");
        
        if (cJSON_IsNumber(brightness_item)) {
            uint8_t brightness = (uint8_t)brightness_item->valueint;
            led_ret = led_controller_set_brightness(brightness);
        } else {
            led_ret = ESP_ERR_INVALID_ARG;
        }
    } else if (strcmp(type, "clear_leds") == 0) {
        led_ret = led_controller_clear();
    } else {
        led_ret = ESP_ERR_NOT_SUPPORTED;
    }
    
    cJSON_Delete(json);
    
    cJSON* response_json = cJSON_CreateObject();
    if (led_ret == ESP_OK) {
        cJSON_AddStringToObject(response_json, "status", "ok");
        send_json_response(req, response_json, 200);
    } else {
        cJSON_AddStringToObject(response_json, "status", "error");
        cJSON_AddStringToObject(response_json, "error", esp_err_to_name(led_ret));
        send_json_response(req, response_json, 400);
    }
    cJSON_Delete(response_json);
    
    return (led_ret == ESP_OK) ? ESP_OK : ESP_FAIL;
}

esp_err_t web_server_init(device_config_t* config)
{
    if (config == NULL) {
        ESP_LOGE(TAG, "Config is NULL");
        return ESP_ERR_INVALID_ARG;
    }
    
    s_device_config = config;
    
    // Инициализируем SPIFFS
    esp_err_t ret = init_spiffs();
    if (ret != ESP_OK) {
        return ret;
    }
    
    // Конфигурируем сервер
    httpd_config_t server_config = HTTPD_DEFAULT_CONFIG();
    server_config.max_uri_handlers = 8;
    server_config.uri_match_fn = httpd_uri_match_wildcard;
    
    // Запускаем сервер
    ret = httpd_start(&s_server, &server_config);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Error starting server: %s", esp_err_to_name(ret));
        return ret;
    }
    
    // Регистрируем обработчики
    httpd_uri_t root_uri = {
        .uri = "/",
        .method = HTTP_GET,
        .handler = root_handler,
        .user_ctx = NULL
    };
    httpd_register_uri_handler(s_server, &root_uri);
    
    httpd_uri_t status_uri = {
        .uri = "/api/status",
        .method = HTTP_GET,
        .handler = status_handler,
        .user_ctx = NULL
    };
    httpd_register_uri_handler(s_server, &status_uri);
    
    httpd_uri_t config_uri = {
        .uri = "/api/config",
        .method = HTTP_POST,
        .handler = config_handler,
        .user_ctx = NULL
    };
    httpd_register_uri_handler(s_server, &config_uri);
    
    httpd_uri_t backend_config_uri = {
        .uri = "/api/setup-backend",
        .method = HTTP_POST,
        .handler = backend_config_handler,
        .user_ctx = NULL
    };
    httpd_register_uri_handler(s_server, &backend_config_uri);
    
    httpd_uri_t servo_uri = {
        .uri = "/api/servo",
        .method = HTTP_POST,
        .handler = servo_handler,
        .user_ctx = NULL
    };
    httpd_register_uri_handler(s_server, &servo_uri);
    
    httpd_uri_t led_uri = {
        .uri = "/api/led",
        .method = HTTP_POST,
        .handler = led_handler,
        .user_ctx = NULL
    };
    httpd_register_uri_handler(s_server, &led_uri);
    
    ESP_LOGI(TAG, "Web server started on port 80");
    return ESP_OK;
}

esp_err_t web_server_stop(void)
{
    if (s_server != NULL) {
        esp_err_t ret = httpd_stop(s_server);
        s_server = NULL;
        return ret;
    }
    return ESP_OK;
}

void web_server_deinit(void)
{
    web_server_stop();
    esp_vfs_spiffs_unregister(NULL);
    s_device_config = NULL;
    ESP_LOGI(TAG, "Web server deinitialized");
}