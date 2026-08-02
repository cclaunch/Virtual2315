# == DO NOT EDIT THE FOLLOWING LINES for the Raspberry Pi Pico VS Code Extension to work ==
if(WIN32)
    set(USERHOME $ENV{USERPROFILE})
else()
    set(USERHOME $ENV{HOME})
endif()
set(sdkVersion 2.1.1)
set(toolchainVersion 14_2_Rel1)
set(picotoolVersion 2.1.1)
set(picoVscode ${USERHOME}/.pico-sdk/cmake/pico-vscode.cmake)
if (EXISTS ${picoVscode})
    include(${picoVscode})
endif()
# ====================================================================================
set(PICO_BOARD pico CACHE STRING "Board type")

cmake_minimum_required(VERSION 3.12)

# Pull in PICO SDK (must be before project)
include(pico_sdk_import.cmake)

# Set name of project (as PROJECT_NAME) and C/C++ standards
project(V2315CF_PICO C CXX ASM)
set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)

#set(PICO_EXAMPLES_PATH ${PROJECT_SOURCE_DIR})

# Initialize the SDK
pico_sdk_init()

add_executable(V2315CF_PICO
	V2315CF_PICO.cpp
	emulator_hardware.cpp
	display_functions.cpp
	emulator_state.cpp
	emulator_command.cpp
	microsd_file_ops.cpp
	ssd1306a.cpp
	hw_config.c
	)

# Tell CMake where to find other source code
add_subdirectory(lib/no-OS-FatFS-SD-SPI-RPi-Pico/FatFs_SPI build)

# Pull in our pico_stdlib which pulls in commonl
target_link_libraries(V2315CF_PICO pico_stdlib FatFs_SPI hardware_i2c hardware_spi hardware_gpio hardware_pwm hardware_adc)

# create map/bin/hex file etc.
pico_add_extra_outputs(V2315CF_PICO)
