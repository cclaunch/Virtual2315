// *********************************************************************************
// emulator_state.cpp
//  definitions and functions related to the RUN/LOAD emulator state
// 
// *********************************************************************************
// 
#include <stdio.h>
#include "pico/stdlib.h"
#include <string.h>

#include "emulator_state_definitions.h"
#include "disk_state_definitions.h"
#include "display_functions.h"
//#include "display_timers.h"
#include "emulator_hardware.h"
#include "microsd_file_ops.h"

#define LOADINGERRORON 7
#define LOADINGERROROFF 7
#define UNLOADINGERRORON 4
#define UNLOADINGERROROFF 4

static int errorlightcount;

void process_run_load_state(Disk_State* dstate){
int intermediate_result;

    switch(dstate->run_load_state){

        case RLST0:
            // Unloaded, waiting in the unloaded state for the LOAD/UNLOAD switch to be toggled to the “LOAD” positiond
            microSD_LED_off();
            clear_fault_latch();
            clear_cpu_rdy_indicator();

            // if the input power from the IBM 1130 has dropped, we don't want to load a cartridge
            if (get_power_fail()) {
                break;
            }

            // ensure read only is off when we are in idle state
            if (get_wp_mode()) {
                printf("Resetting Ready Only in idle state\r\n");    // $$$ CVC $$$
                toggle_wp();
            }

            // has the switch been thrown to Load?
            if(dstate->rl_switch == 1){
                if (get_disk_unlocked()){ // begin the normal loading process
                    printf("Switch toggled from UNLOAD to LOAD\r\n");
                    clear_cpu_unlock_indicator();
                    dstate->run_load_state = RLST1; // If the LOAD/UNLOAD switch is toggled to LOAD then advance to RLST1
                }
            // otherwise just keep drive door unlocked lamp updated
            } else if (get_disk_unlocked()) {
                    set_cpu_unlock_indicator();
		}
                else {
                    clear_cpu_unlock_indicator();
                }
            dstate->wp_switch = 0;  // initially not read/only
            break;

        case RLST1:
            // The LOAD/UNLOAD switch has been toggled to the “LOAD” position. Check to see that the microSD has been inserted. 
            // If not, then go to load error state with code 1.
            microSD_LED_on();
            printf("  Drive_Address = %d, RLST%x, %d, %d\r\n", dstate->Drive_Address, dstate->run_load_state, dstate->rl_switch, dstate->wp_switch);
            if(is_card_present()){
                printf("Card present, microSD card detected\r\n");
                display_status((char *) "microSD", (char *) "detected");
                dstate->run_load_state = RLST2; // if the microSD card is inserted then advance to RLST2
            }
            else {
                //error_code = 1;
                printf("*** ERROR, microSD card is not inserted\r\n");
                display_error((char *) "no microSD", (char *) "inserted");
                dstate->run_load_state = RLST18;
            }
            break;

        case RLST2:
            // Check to see if the file system can be started. If not, then go to load error state with code 2.
            printf("  Drive_Address = %d, RLST%x, %d, %d\r\n", dstate->Drive_Address, dstate->run_load_state, dstate->rl_switch, dstate->wp_switch);
            if(file_init_and_mount() != 0) {
                //error_code = 2;
                printf("*** ERROR, could not init and mount microSD filesystem\r\n");
                //display_error((char *) "cannot init", (char *) "microSD card");
                dstate->run_load_state = RLST18;
            }
            else{
                printf("filesystem started\r\n");
                display_status((char *) "filesystem", (char *) "started");
                dstate->run_load_state = RLST4;
            }
            break;

        case RLST4:
            // Check to see if the disk image file can be opened. If not, then go to load error state with code 4.
            printf("  Drive_Address = %d, RLST%x, %d, %d\r\n", dstate->Drive_Address, dstate->run_load_state, dstate->rl_switch, dstate->wp_switch);
            if(file_open_read_disk_image() != 0){
                //error_code = 0x4;
                printf("*** ERROR, file_open_read_disk_image failed\r\n");
                display_error((char *) "cannot open", (char *) "disk image");
                dstate->run_load_state = RLST18;
            }
            else{
                printf("Disk image file is open\r\n");
                display_status((char *) "image file", (char *) "is open");
                dstate->run_load_state = RLST5;
            }
            break;

        case RLST5:
            // Read the format identifier in the header of the disk image file. If error, then load error state with code 5.
            // If the header is good then start moving the actuator to close the drive door
            printf("  Drive_Address = %d, RLST%x, %d, %d\r\n", dstate->Drive_Address, dstate->run_load_state, dstate->rl_switch, dstate->wp_switch);
            printf("Reading image file header\r\n");
            intermediate_result = read_image_file_header(dstate);
            if(intermediate_result != 0){
                file_close_disk_image();
                switch(intermediate_result) {
                    default:
                        printf("*** ERROR, problem reading image file header\r\n");
                        display_error((char *) "cannot read", (char *) "image header");
                        break;

                    case 2:
                        printf("*** ERROR, invalid file type\r\n");
                        display_error((char *) "invalid", (char *) "file type");
                        break;

                    case 3:
                        printf("*** ERROR, invalid file version\r\n");
                        display_error((char *) "invalid", (char *) "file ver");
                        break;
                }
                dstate->run_load_state = RLST18;
            }
            else if ((dstate->numberOfSectorsPerTrack > 16) && (dstate->Board_version < 2)) {
                printf("*** ERROR, Board Version %d cannot support %d sectors.\r\n", dstate->Board_version, dstate->numberOfSectorsPerTrack);
                display_error((char *) "> max", (char *) "sectors");
                dstate->run_load_state = RLST18;
            }
            else{
                printf("Image file header read successfully\r\n");
                close_drive_door();
                printf("Moving the actuator to close the door\r\n");
                display_status((char *) "Closing", (char *) "microSD door");
                dstate->run_load_state = RLST6;
            }
            break;

        case RLST6:
            // Wait for the actuator to finish closing the drive door.
            printf("  Drive_Address = %d, RLST%x, %d, %d\r\n", dstate->Drive_Address, dstate->run_load_state, dstate->rl_switch, dstate->wp_switch);
            intermediate_result = drive_door_status();
            if(intermediate_result == DOORCLOSED){
                printf("Door closed\r\nReading disk image data from file\r\n");
                display_status((char *) "Reading", (char *) "image data");
                dstate->run_load_state = RLST7;
            }
            break;

        case RLST7:
            // Read the disk image file and write it to the DRAM. If a read error occurs then go to load error state with code 7.
            printf("  Drive_Address = %d, RLST%x, %d, %d\r\n", dstate->Drive_Address, dstate->run_load_state, dstate->rl_switch, dstate->wp_switch);
            intermediate_result = read_disk_image_data(dstate);
            if(intermediate_result != 0){
                file_close_disk_image();
                printf("*** ERROR, problem reading disk image data\n");
                display_error((char *) "cannot read", (char *) "image data");
                dstate->run_load_state = RLST18;
            }
            else{
                printf("Disk image data read successfully\r\n");
                display_status((char *) "Image data", (char *) "read OK");
                dstate->run_load_state = RLST8;
            }
            break;

        case RLST8:
            // Close the disk image file and set the Cart_Ready bit in the FPGA mode register
            printf("  Drive_Address = %d, RLST%x, %d, %d\r\n", dstate->Drive_Address, dstate->run_load_state, dstate->rl_switch, dstate->wp_switch);
            intermediate_result = file_close_disk_image();
            if(intermediate_result != 0){
                printf("*** ERROR, problem closing disk image data file\n");
                display_error((char *) "cannot close", (char *) "image file");
                dstate->run_load_state = RLST18;
            }
            else{
                printf("Disk image data read, file closed successfully\r\n");
                dstate->run_load_state = RLST9;
                set_cart_ready();
            }
            break;

        case RLST9:
        // show fault that might stop us from going ready
        if (get_disk_fault()) { // disk drive threw a fault and went not ready
            set_cpu_fault_indicator();
        }

        // wait for disk to declare the drive ready for input output
             if (get_disk_ready()) {
                dstate->File_Ready = true;
                set_cpu_rdy_indicator();
                dstate->run_load_state = RLST10;
            }
             // we wait here until Load/Unload switch is turned off
             else {
                if (dstate->rl_switch == 0) {
                   printf("Requested unload without running\r\n");
                   clear_cart_ready();
                   dstate->run_load_state = RLST15a; // Advance to RLST15a
                }
                else {
                   if (get_power_fail()) {
                      printf("Terminating loaded cart due to power failure\r\n");
                      clear_cart_ready();
                      dstate->run_load_state = RLST15a;
                      break;
                   }
                   dstate->run_load_state = RLST9;
                }
             }
             break;

        case RLST10:
            // Loaded and running state. Normal access until drive goes off
            microSD_LED_on();

            if (get_disk_fault()) { // disk drive threw a fault and went not ready
                set_cpu_fault_indicator();
            }

            // do unload if power is turned off
            if (get_power_fail()) {
                printf("Unrequested unload due to power fail\r\n");
                clear_cpu_rdy_indicator();
                dstate->run_load_state = RLST11; // If the drive stopped then advance to RLST11
                break;
            }

            if (get_disk_ready() && get_real_mode()) { // just in case real drive drops ready due to speed decline etc
                break;              // if good, continue in this state
            } else if (get_disk_ready() == 0) {                // drive turned off or failed
                // the File Ready light tells operator if real/virtual drive is ready or not
                clear_cpu_rdy_indicator();
            }

            // we wait here until Load/Unload switch is turned off
            // if in real mode and the disk is ready, we don't check for the unload here (a break was executed)
            // this path exists if the disk is not ready or we are in virtual mode where this turns off the drive
            if (dstate->rl_switch == 0) {
                printf("Requested unload\r\n");
                clear_cpu_rdy_indicator();
                dstate->run_load_state = RLST11; // If the drive stopped then advance to RLST11
            }
            break;

        case RLST11:
            // The Load/Unload switch on the box was turned off. Read the contents of the DRAM and write it to the disk image file. 

            // if the write protect light is on (toggled R/O switch odd number of times) then skip write back
            if (get_read_only()) { // we want this cartridge to remain as it was
                printf("Cartridge was read-only\r\n");
                dstate->File_Ready = false;
                dstate->run_load_state = RLST15a;
                // turn off cart ready so FPGA doesn't try to access it
                clear_cart_ready();
                break;
            }
 
            // turn off cart ready so FPGA doesn't try to access it
            clear_cart_ready();

            printf("  Drive_Address = %d, RLST%x, %d, %d\r\n", dstate->Drive_Address, dstate->run_load_state, dstate->rl_switch, dstate->wp_switch);
            intermediate_result = file_open_write_disk_image();
            printf("finished file open for write, code %d\r\n", intermediate_result);

            // If a write error occurs then go to the unload error state with code 21.
            if(intermediate_result != FILE_OPS_OKAY){
                //error_code = 0x21;
                printf("*** ERROR, file_open_write_disk_image failed\r\n");
                display_error((char *) "image file", (char *) "open failed");
                dstate->run_load_state = RLST1a;
            }
            else{
                printf("Disk image file is open\r\n");
                dstate->File_Ready = false;
                display_status((char *) "Image file", (char *) "open");
                dstate->run_load_state = RLST12;
            }
            break;

        case RLST12:
            // Write the header of the image file.
            printf("  Drive_Address = %d, RLST%x, %d, %d\r\n", dstate->Drive_Address, dstate->run_load_state, dstate->rl_switch, dstate->wp_switch);
            intermediate_result = write_image_file_header(dstate);
            if(intermediate_result != FILE_OPS_OKAY){
                file_close_disk_image();
                printf("*** ERROR, write_image_file_header failed\r\n");
                display_error((char *) "image header", (char *) "write fail");
                dstate->run_load_state = RLST1a;
            }
            else{
                printf("Disk image header written\r\n");
                display_status((char *) "Writing", (char *) "image data");
                dstate->run_load_state = RLST13;
            }
            break;

        case RLST13:
            // Write the disk image data.
            printf("  Drive_Address = %d, RLST%x, %d, %d\r\n", dstate->Drive_Address, dstate->run_load_state, dstate->rl_switch, dstate->wp_switch);
            intermediate_result = write_disk_image_data(dstate);
            if(intermediate_result != FILE_OPS_OKAY){
                file_close_disk_image();
                printf("*** ERROR, write_disk_image_data failed\r\n");
                display_error((char *) "image data", (char *) "write fail");
                dstate->run_load_state = RLST1a;
            }
            else{
                printf("Disk image data written\r\n");
                //display_status((char *) "image file", (char *) "is open");
                dstate->run_load_state = RLST14;
            }
            break;

        case RLST14:
            // Close the disk image file. If an error occurs then go to the unload error state with code 22.
            // Start moving the actuator to close the drive door
            // Close the disk image file and set the File_Ready bit in the FPGA mode register and illuminate RDY on the front panel.
            printf("  Drive_Address = %d, RLST%x, %d, %d\r\n", dstate->Drive_Address, dstate->run_load_state, dstate->rl_switch, dstate->wp_switch);
            intermediate_result = file_close_disk_image();
            if(intermediate_result != 0){
                printf("*** ERROR, problem closing disk image data file\n");
                display_error((char *) "image file", (char *) "close fail");
                dstate->run_load_state = RLST1a;
            }
            else{
                printf("Disk image data write, file closed successfully\r\n");
                display_status((char *) "Opening", (char *) "microSD door");
                open_drive_door();
                printf("Moving the actuator to open the door\r\n");
                dstate->run_load_state = RLST15;
            }
            break;

        case RLST15:
            // Wait for the actuator to finish opening the drive door.
            microSD_LED_off();
            printf("  Drive_Address = %d, RLST%x, %d, %d\r\n", dstate->Drive_Address, dstate->run_load_state, dstate->rl_switch, dstate->wp_switch);
            intermediate_result = drive_door_status();
            printf("state RLST15 drive door [%d]\r\n", intermediate_result);
            if(intermediate_result == DOOROPEN){
                printf("Door open\r\n");
                display_status((char *) "microSD", (char *) "door open");
                dstate->run_load_state = RLST0;
            }
            break;

        case RLST18:
            // Loading error state, initialize internal error states for loading error.
            microSD_LED_off();
            printf("  Drive_Address = %d, RLST%x, %d, %d\r\n", dstate->Drive_Address, dstate->run_load_state, dstate->rl_switch, dstate->wp_switch);
            set_cpu_fault_indicator();
            errorlightcount = LOADINGERRORON;
            dstate->run_load_state = RLST19;
            break;

        case RLST19:
            // Loading error state, indicator on. Flash the Fault light indefinitely.
            if(--errorlightcount == 0){
                printf("  Drive_Address = %d, RLST%x, %d, %d\r\n", dstate->Drive_Address, dstate->run_load_state, dstate->rl_switch, dstate->wp_switch);
                errorlightcount = LOADINGERROROFF;
                dstate->run_load_state = RLST1a;
                clear_cpu_fault_indicator();
            }
            if(!dstate->rl_switch && dstate->wp_switch){ //if WTPROT switch is simultaneously pressed when toggling RUN/LOAD back to LOAD then only move the microSD carriage
                open_drive_door();
                clear_cpu_fault_indicator();
                dstate->run_load_state = RLST1b; // go to the 1b state to wait for the door to be opened
                clear_cart_ready();
                clear_cpu_rdy_indicator();
            }
            break;

        case RLST1a:
            // Loading error state, indicator off. Flash the Fault light indefinitely.
            if(--errorlightcount == 0){
                printf("  Drive_Address = %d, RLST%x, %d, %d\r\n", dstate->Drive_Address, dstate->run_load_state, dstate->rl_switch, dstate->wp_switch);
                errorlightcount = LOADINGERRORON;
                dstate->run_load_state = RLST19;
                set_cpu_fault_indicator();
            }
            if(!dstate->rl_switch && dstate->wp_switch){ //if WTPROT switch is simultaneously pressed when toggling RUN/LOAD back to LOAD then only move the microSD carriage
                open_drive_door();
                clear_cpu_fault_indicator();
                clear_cart_ready();
                clear_cpu_rdy_indicator();
                dstate->run_load_state = RLST1b; // go to the 1b state to wait for the door to be opened
            }
            break;

        case RLST1b:
            // wait for door to open after loading error state or loaded/ready RLST10 state.
            if(drive_door_status() == DOOROPEN){
                printf("  Drive_Address = %d, RLST%x, %d, %d\r\n", dstate->Drive_Address, dstate->run_load_state, dstate->rl_switch, dstate->wp_switch);
                dstate->run_load_state = RLST0;
            }
            break;

        case RLST1c:
            // Unloading error state, initialize internal error states for unloading error.
            printf("  Drive_Address = %d, RLST%x, %d, %d\r\n", dstate->Drive_Address, dstate->run_load_state, dstate->rl_switch, dstate->wp_switch);
            set_cpu_fault_indicator();
            errorlightcount = LOADINGERRORON;
            dstate->run_load_state = RLST1d;
            break;

        case RLST1d:
            // Unloading error state, indicator on. Flash the Fault light indefinitely.
            if(--errorlightcount == 0){
                printf("  Drive_Address = %d, RLST%x, %d, %d\r\n", dstate->Drive_Address, dstate->run_load_state, dstate->rl_switch, dstate->wp_switch);
                errorlightcount = UNLOADINGERROROFF;
                dstate->run_load_state = RLST1e;
                clear_cpu_fault_indicator();
            }
            if(dstate->rl_switch && dstate->wp_switch){ //if WTPROT switch is simultaneously pressed when toggling RUN/LOAD back to RUN then only move the microSD carriage
                close_drive_door();
                clear_cpu_fault_indicator();
                set_cpu_unlock_indicator();
                dstate->run_load_state = RLST1f; // go to the 1f state to wait for the door to be closed
            }
            break;

        case RLST1e:
            // Unloading error state, indicator off. Flash the Fault light indefinitely.
            if(--errorlightcount == 0){
                printf("  Drive_Address = %d, RLST%x, %d, %d\r\n", dstate->Drive_Address, dstate->run_load_state, dstate->rl_switch, dstate->wp_switch);
                errorlightcount = UNLOADINGERRORON;
                dstate->run_load_state = RLST1d;
                set_cpu_fault_indicator();
            }
            if(dstate->rl_switch && dstate->wp_switch){ //if WTPROT switch is simultaneously pressed when toggling RUN/LOAD back to RUN then only move the microSD carriage
                close_drive_door();
                clear_cpu_fault_indicator();
                dstate->run_load_state = RLST1f; // go to the 1f state to wait for the door to be closed
            }
            break;

        case RLST1f:
            // wait for door to close after Unloading error state or unloaded RLST0 state.
            if(drive_door_status() == DOORCLOSED){
                printf("  Drive_Address = %d, RLST%x, %d, %d\r\n", dstate->Drive_Address, dstate->run_load_state, dstate->rl_switch, dstate->wp_switch);
                dstate->run_load_state = RLST10;
            }
            break;

        case RLST15a:
            // trigger door to open when we are not writing back a cartridge
            printf("Disk image not written back\r\n");
            display_status((char *) "Opening", (char *) "microSD door");
            open_drive_door();
            printf("Moving the actuator to open the door\r\n");
            dstate->run_load_state = RLST15;
            break;


        default:
            printf("*** ERROR, invalid run_load_state: %x\n", dstate->run_load_state);
    }
}
