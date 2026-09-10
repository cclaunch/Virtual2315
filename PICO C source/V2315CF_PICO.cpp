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

#define SPI_CYLADDR_81 0x81
#define SPI_DRVSTATUS_82 0x82

#define INPUT_LINE_LENGTH 200
char inputdata[INPUT_LINE_LENGTH];
char *extract_argv[INPUT_LINE_LENGTH];
int extract_argc;

// callback code
volatile int char_from_callback;

int debug_mode;
int damage_mode;     // CVC inserted to handle one bad FPGA chip
#define ALT_INTERRUPT 5      // use pin 5 instead of pin 4 (CMD_INTERRUPT)

// console input callback code
void callback(void *ptr){
    int *i = (int*) ptr;  // cast void pointer back to int pointer
    // read the character which caused to callback (and in the future read the whole string)
    *i = getchar_timeout_us(100); // length of timeout does not affect results
}

// pin interrupt to signal PICO from FPGA of seek, read or write
void gpio_callback(uint gpio, uint32_t events) {
    if((gpio == 4) && ((events & 0x8) == 0x8)){

        int readval = read_int_inputs();
        int operation_id = (readval >> 10) & 0x3;
        
        switch(operation_id){
            case 0:
                printf("*SEEK c=%d\r\n", readval & 0xff);
                break;
            case 1:
                printf("*READ c=%d h=%d s=%d\r\n", readval & 0xff, (readval >> 8) & 1, (readval >> 13) & 0xf);
                break;
            case 2:
                printf("*WRITE c=%d h=%d s=%d\r\n", readval & 0xff, (readval >> 8) & 1, (readval >> 13) & 0xf);
                break;
            default:
                printf("*ERROR, operation_id=%d\r\n", operation_id);
                break;
        }
    }
}

// initial condition of system  at startup
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
    edisk.saw_fail = false;
}

// serial connection
#define UART_ID uart0
//#define BAUD_RATE 115200
#define BAUD_RATE 460800
#define UART_TX_PIN 0
#define UART_RX_PIN 1

// startup code
void initialize_system() {
    debug_mode = 0;

    // initialize IO library
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
    // disable interrupts and save old status
    uint32_t old_irq_status = save_and_disable_interrupts();
    // set up the callback for the uart when it receives a character
    stdio_set_chars_available_callback(callback, (void*)  &char_from_callback); //register callback
    // restore the interrupts
    restore_interrupts(old_irq_status);

    printf("\r\n************* V2315CF Emulator STARTUP *************\n");

    // initialize the GP IO pins
    initialize_gpio();

    // start the LCD display
    setup_display();

    printf(" *gpio initialized\n");

    // reset the FPGA so it can start in a clean state
    assert_fpga_reset();
    sleep_ms(10);
    deassert_fpga_reset();

    // start up the SPI link to the FPGA
    initialize_spi();
    printf(" *spi initialized\r\n");

    // set initial condition of virtual disk drive
    initialize_states();
    printf(" *software internal states initialized\n");

    // set initial state of registers describing disk
    initialize_fpga(&edisk);
    printf(" *disk state registers initialized\n");

    // look for defective board where pin 4 is always high, switch      CVC
    // over to use the alternative interrupt pin 5                      CVC
    if (gpio_get(ALT_INTERRUPT) == 1) {                            //   CVC
        printf(" *Found pin 4 hot, this is the damaged board\r\n");//   CVC
        damage_mode = true;                                        //   CVC
    } else {                                                       //   CVC
        damage_mode = false;                                       //   CVC 
    }                                                              //   CVC

    printf(" *Emulator software version %d.%d\r\n", SOFTWARE_VERSION, SOFTWARE_MINOR_VERSION);
    printf(" *FPGA version %d.%d\r\n", edisk.FPGA_version, edisk.FPGA_minorversion);
    printf(" *Board version %d\r\n", edisk.Board_version);

    // declare mode of V2315CF
    if (get_real_mode()) {
       printf(" *Real mode operation\r\n");
    } else {
       printf(" *Virtual mode operation\r\n");
    }

    // At boot time: if the LOAD/UNLOAD switch is in the UNLOAD position then open the door
    read_rocker_switches(&edisk);
    if (edisk.rl_switch) {
        printf("Started with Load switch active\r\n");
    }
    clear_dc_low();
}

// mainline routine
int main() {
    uint32_t ticker;
    initialize_system();
 
    ticker = 0;
    int reg00_val;
    int reg81_val;
    int reg82_val;
    int reg82_sector;
    int reg82_head;
    bool showicon;
    printf("Virtual 2315 Cartridge Facility STARTING\n");
    display_splash_screen();

    // permanent loop to process everything
    while (true) {

        // log status line every 50 ticks or roughly 5 seconds
        if((ticker % 50) == 0){
            reg00_val = read_reg00();
            reg81_val = read_write_spi_register(SPI_CYLADDR_81, 0);
            reg82_val = read_write_spi_register(SPI_DRVSTATUS_82, 0);
            reg82_sector = (reg82_val & 0x30) >> 4;
            reg82_head = reg82_val & 0x01;
            
            printf("main loop %d, RLST%x, Cylinder = %d, Head = %d, Sector = %d, reg00 = %x\r\n", ticker, edisk.run_load_state, 
                reg81_val, reg82_head, reg82_sector, reg00_val);
        }

        // see if the rocker switches have been moved
        read_rocker_switches(&edisk);

        if (edisk.wp_switch) {
            printf("Read Only switch held down\r\n");
        }
        
        // check for power error
        check_dc_low(&edisk);

        // update the state of the disk ddrive
        process_run_load_state(&edisk);

        // indicate unloaded on the LCD screen
        if((edisk.run_load_state == RLST0) || (edisk.run_load_state == RLST19) || (edisk.run_load_state == RLST1d)){
            showicon = false;
            display_drive_address(edisk.Drive_Address, edisk.mode_RK05f, (char *)"", showicon);
        }
        // show the cartridge ID on the LCD screen
        else if ((edisk.run_load_state == RLST9) || (edisk.run_load_state == RLST10)) {
            showicon = true;
            display_drive_address(edisk.Drive_Address, edisk.mode_RK05f, edisk.imageName, showicon);
        }

        // housekeeping on timers
        manage_display_timers(&edisk, showicon);

        // if input was typed on serial link over USB, a callback routine reads the char into char_from_callback
        if(char_from_callback != 0){
            // if the key was L or l then begin logging events
            if((char_from_callback == 'L') || (char_from_callback == 'l')){
                printf("  Begin logging events\r\n");
                gpio_set_irq_enabled_with_callback( (damage_mode ? 5 : 4), GPIO_IRQ_EDGE_RISE, true, &gpio_callback); // gpio callback with CVC mod
            }
            // if the key was S or s then stop logging
            else if((char_from_callback == 'S') || (char_from_callback == 's')){
                printf("  Stop logging events\r\n");
                gpio_set_irq_enabled_with_callback( (damage_mode ? 5 : 4), GPIO_IRQ_EDGE_RISE, false, &gpio_callback); // gpio callback with CVC mod
            }
            // erase character until the next one is entered
            char_from_callback = 0; //reset the value
        }

        // wait 1/10th second then increment ticker count
        sleep_ms(100);
        ticker++;
    }
    return 0;
}