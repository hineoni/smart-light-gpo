idf_component_register(
    SRCS "servo_controller.c"
    INCLUDE_DIRS "include"
    REQUIRES driver config_storage
)