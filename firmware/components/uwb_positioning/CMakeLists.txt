idf_component_register(
    SRCS "uwb_positioning.c"
    INCLUDE_DIRS "include"
    REQUIRES driver esp_driver_uart esp_timer log freertos
)
