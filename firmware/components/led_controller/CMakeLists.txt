idf_component_register(
    SRCS "led_controller.c" "led_strip_encoder.c"
    INCLUDE_DIRS "include"
    REQUIRES driver log freertos
)