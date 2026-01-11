# Корневой CMakeLists.txt для проекта SmartLight на ESP-IDF

cmake_minimum_required(VERSION 3.16)

# Подключаем ESP-IDF
include($ENV{IDF_PATH}/tools/cmake/project.cmake)

# Определяем проект
project(smartlight_firmware)

spiffs_create_partition_image(spiffs spiffs_image FLASH_IN_PROJECT)
