# Main CMakeLists.txt для основного компонента

idf_component_register(
    SRCS "main.c"
    INCLUDE_DIRS "."
    REQUIRES
        config_storage
        wifi_manager
        servo_controller
        led_controller
        web_server
        websocket_client
        esp_wifi
        esp_http_server
        nvs_flash
        driver
        json
        spiffs
)
