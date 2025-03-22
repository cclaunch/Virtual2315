// *********************************************************************************
// V2315CF_PICO.cpp
//   Top Level main() function of the Virtual 2315 Cartridge Facility
//
//  based on George Wiley's RK-05 Emulator, modified by Carl Claunch
// *********************************************************************************
// 
//===============================================================================================//
//                                                                                               //
// This software and related modules included by the top level module and files used to build    //
// the software are provided on an as-is basis. No warrantees or guarantees are provided or      //
// implied. Users of the RK05 Emulator or RK05 Tester shall not hold the developers of this      //
// software, firmware, hardware, or related documentation liable for any damages caused by       //
// any type of malfunction of the product including malfunctions caused by defects in the design //
// or operation of the software, firmware, hardware or use of related documentation or any       //
// combination thereof.                                                                          //
//                                                                                               //
//===============================================================================================//
//
#define SOFTWARE_MINOR_VERSION 0
#define SOFTWARE_VERSION 3

#include <stdio.h>
#include "pico/stdlib.h"
#include "hardware/gpio.h"
#include "hardware/sync.h"
//#include "hardware/adc.h"
//#include "sd_card.h"
//#include "ff.h"

//#include "include_libs/stdlib.h"
//#include "include_libs/adc.h"
//#include "include_libs/sd_card.h"
//#include "include_libs/ff.h"

//#include <stdio.h>
#include <string.h>
//#include "pico/stdlib.h"
//#include "hardware/uart.h"
//#include "pico/binary_info.h"
//#include "hardware/spi.h"

//#include "emulator_hardware.h"
//#include "emulator_state.h"
//#include "display_big_images.h"
#include "disk_state_definitions.h"
#include "display_functions.h"
//#include "microsd_file_ops.h"

#include "emulator_state_definitions.h"
#include "emulator_state.h"
#include "emulator_hardware.h"
#include "display_functions.h"
#include "display_timers.h"
#include "emulator_command.h"

// GLOBAL VARIABLES
struct Disk_State edisk;

#define INPUT_LINE_LENGTH 200
char inputdata[INPUT_LINE_LENGTH];
char *extract_argv[INPUT_LINE_LENGTH];
int extract_argc;

// callback code
int char_from_callback;

int debug_mode;



// console input callback code
void callback(void *ptr){
    int *i = (int*) ptr;  // cast void pointer back to int pointer
    // read the character which caused to callback (and in the future read the whole string)
    *i = getchar_timeout_us(100); // length of timeout does not affect results
}

void gpio_callback(uint gpio, uint32_t events) {
    int readval = read_int_inputs();
    int operation_id = (readval >> 10) & 0x3;
    if((gpio == 4) && ((events & 0x8) == 0x8)){
        printf("some kind of event to callback\r\n"); // $$$ CVC $$$
        switch(operation_id){
            case 0:
                printf("*SEEK %d\r\n", readval & 0xff);
                break;
            case 1:
                printf("*READ c=%d h=%d s=%d\r\n", readval & 0xff, (readval >> 8) & 1, (readval >> 12) & 0xf);
                break;
            case 2:
                printf("*WRITE c=%d h=%d s=%d\r\n", readval & 0xff, (readval >> 8) & 1, (readval >> 12) & 0xf);
                break;
            default:
                printf("*ERROR, operation_id=%d\r\n", operation_id);
                break;
        }
    }
}

void read_switches_and_set_drive_address(){
//    int switch_read_value = read_drive_address_switches();
//    edisk.Drive_Address = switch_read_value & DRIVE_ADDRESS_BITS_I2C;
//    edisk.mode_RK05f = ((switch_read_value & DRIVE_FIXED_MODE_BIT_I2C) == 0) ? false : true;
//    load_drive_address(edisk.Drive_Address);   2310 does not have multiple drives on a string
}

void initialize_states(){
    edisk.Drive_Address = 0;
    edisk.mode_RK05f = false;
    edisk.File_Ready = false;
    edisk.Fault_Latch = false;
    edisk.dc_low = false;
    edisk.FPGA_version = 0;
    edisk.FPGA_minorversion = 0;
    edisk.Board_version = read_board_version();

    edisk.run_load_state = RLST0;
    edisk.rl_switch = false;
    edisk.p_wp_switch = edisk.wp_switch = false;

    edisk.door_is_open = true;
    edisk.door_count = 0;

    // initialize states to 2310 values
    strcpy(edisk.controller, "IBM 1130");
    edisk.bitRate = 720000;
    edisk.numberOfCylinders = 203;
    edisk.numberOfSectorsPerTrack = 8;
    edisk.numberOfHeads = 2;
    edisk.microsecondsPerSector = 5000;
}

#define UART_ID uart0
//#define BAUD_RATE 115200
#define BAUD_RATE 460800
#define UART_TX_PIN 0
#define UART_RX_PIN 1

void initialize_system() {
    debug_mode = 0;
    stdio_init_all();
    sleep_ms(50);
    //initialize_uart();
    // Set up our UART with the required speed.
    uart_init(UART_ID, BAUD_RATE);
    sleep_ms(500);

    // Set the TX and RX pins by using the function select on the GPIO
    // Set datasheet for more information on function select
    // We are using GP0 and GP1 for the UART, package pins 1 & 2
    gpio_set_function(UART_TX_PIN, GPIO_FUNC_UART);
    gpio_set_function(UART_RX_PIN, GPIO_FUNC_UART);
    sleep_ms(50);

    // callback code
    char_from_callback = 0;
    uint32_t old_irq_status = save_and_disable_interrupts();
    stdio_set_chars_available_callback(callback, (void*)  &char_from_callback); //register callback
    restore_interrupts(old_irq_status);

    printf("\r\n************* RK05 Emulator STARTUP *************\n");
    initialize_gpio();
    setup_display();
    printf(" *gpio initialized\n");
    assert_fpga_reset();
    sleep_ms(10);
    deassert_fpga_reset();
    initialize_spi();
    printf(" *spi initialized\r\n");
    initialize_states();
    printf(" *software internal states initialized\n");
    initialize_fpga(&edisk);
    printf(" *fpga registers initialized\n");

    printf(" *Emulator software version %d.%d\r\n", SOFTWARE_VERSION, SOFTWARE_MINOR_VERSION);
    printf(" *FPGA version %d.%d\r\n", edisk.FPGA_version, edisk.FPGA_minorversion);
    printf(" *Board version %d\r\n", edisk.Board_version);
    if (get_real_mode()) {
       printf(" *Real mode operation\r\n");
    } else {
       printf(" *Virtual mode operation\r\n");
    }

    // At boot time: if the LOAD/UNLOAD switch is in the UNLOAD position then open the door
    read_rocker_switches(&edisk);
    clear_dc_low();
}

int main() {
    uint32_t ticker;
    initialize_system();
    read_switches_and_set_drive_address();

    ticker = 0;
    int reg00_val;
    printf("Virtual 2315 Cartridge Facility STARTING\n");
    display_splash_screen();


    while (true) {
        if((ticker % 50) == 0){
            reg00_val = read_reg00();
            printf("main loop %d, Drive_Address = %d, RLST%x, vsense = %d, reg00 = %x\r\n", ticker, edisk.Drive_Address, edisk.run_load_state, 
                edisk.debug_vsense, reg00_val);
        }
        read_rocker_switches(&edisk);

        check_dc_low(&edisk);

        process_run_load_state(&edisk);
        if((edisk.run_load_state == RLST0) || (edisk.run_load_state == RLST19) || (edisk.run_load_state == RLST1d)){
            display_drive_address(edisk.Drive_Address, edisk.mode_RK05f, edisk.File_Ready ? edisk.imageName : (char *)"");
        }
        else if ((edisk.run_load_state == RLST9) || (edisk.run_load_state == RLST10)) {
            display_drive_address(edisk.Drive_Address, edisk.mode_RK05f, edisk.imageName);
        }
        manage_display_timers(&edisk);
        if(char_from_callback != 0){
            // if the key was L or l then begin logging events
            if((char_from_callback == 'L') || (char_from_callback == 'l')){
                printf("  Begin logging events\r\n");
                gpio_set_irq_enabled_with_callback(4, GPIO_IRQ_EDGE_RISE, true, &gpio_callback); // gpio callback
            }
            else if((char_from_callback == 'S') || (char_from_callback == 's')){
                printf("  Stop logging events\r\n");
                gpio_set_irq_enabled_with_callback(4, GPIO_IRQ_EDGE_RISE, false, &gpio_callback); // gpio callback
            }
            char_from_callback = 0; //reset the value
        }

        sleep_ms(100);
        ticker++;
    }
    return 0;
}