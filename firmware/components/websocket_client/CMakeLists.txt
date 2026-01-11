idf_component_register(
    SRCS "websocket_client.c"
    INCLUDE_DIRS "include"
    REQUIRES esp_websocket_client esp_http_client tcp_transport json config_storage servo_controller led_controller
)
