idf_component_register(
    SRCS "web_server.c"
    INCLUDE_DIRS "include"
    REQUIRES esp_http_server json spiffs config_storage wifi_manager servo_controller led_controller
)