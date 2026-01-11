idf_component_register(
    SRCS "ble_provisioning.c"
    INCLUDE_DIRS "include"
    REQUIRES 
        esp_wifi
        protocomm
        wifi_provisioning
        config_storage
        log
        esp_timer
        esp_event
)