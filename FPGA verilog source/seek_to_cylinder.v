//==========================================================================================================
// RK05 Emulator
// seek to cylinder logic
// File Name: seek_to_cylinder.v
// Functions: 
//
//   This will keep track of the cylinder address after any sequence of seek
//   operations. Shadows the arm of the disk drive when in real mode. 
//
//   Receive the bus go signal, bus step direction address, and step size signals.
//   Seek to the cylinder address if the address is valid, based on saved cylinder
//   then saving the new cylinder address in Cylinder_Address.
//
//   Arm can only be moved one or two tracks in either the forward or reverse direction
//   if reverse and we would go below 0, stop at 0 and set Home signal
//   if forward and we would go past 202, stop at 202
//   
//   Respond with bus Access Ready which drops 5.5 ms after access go received and 
//   remains low for another 9 ms before returning high. Only care about falling
//   edge of BUS_ACC_GO_L to indicate a seek has begun
//
//   flickers the oncylinder indicator to indicate a seek (150 millisecond duration)
//
//   the real Home signal from the disk drive is used to force sync to cylinder zero in real mode
//
//   pulses the completed_seek signal at the end of a series of seek steps, resets after seek indicator goes off
//
// Modified for 2310 by Carl Claunch
//
//==========================================================================================================

`include "debouncer.v"

module seek_to_cylinder(
    input wire clock,                  // master clock 40 MHz
    input wire reset,                  // active high synchronous reset input
    input wire Selected_Ready,         // disk contents have been copied from the microSD to the SDRAM 
                                       // & drive selected & ~fault latch
    input wire BUS_ACC_GO_L,           // request movement of the heads when low
    input wire BUS_ACC_REV_L,          // access direction for arm movement, high is forward
    input wire BUS_10_20_L,            // one or two cylinder arm movement, low is 10 mil
    input wire BUS_ACCESS_RDY_H,       // drops during portion of a seek
    input wire clkenbl_sector,         // blip at each logical 2310 sector
    input wire clkenbl_1usec,          // 1 usec clock enable input from the timing generator
    input wire BUS_HOME_L,             // disk drive home indicator
    input Cart_Ready,                  // virtual cartridge loaded
    input wire real_drive,             // real or virtual mode
    input wire Reset_Cylinder,         // control flag to force arm to home position

    output reg [7:0] Cylinder_Address, // internal register to store the valid cylinder address
    output reg BUS_ACCESS_RDY_EMUL_H,  // access ready signal
    output reg BUS_HOME_DRIVE_EMUL_L,  // at home cylinder (0) when low
    output reg oncylinder_indicator,   // active high signal to drive the On Cylinder front panel indicator
    output reg completed_seek,          // indicates an 1130 XIO Seek has completed
    output reg strobe_selected_ready   // synchronized access go and selected_ready for command interrupt
);

//============================ Internal Connections ==================================

reg [18:0] seek_timer;         // counts microseconds while seek is active
reg [4:0]  oncylinder_counter; // counts to blink the seek light
reg [4:0]  group_timer;        // counts microseconds after a seek step ends
reg        hold_step;          // grab the step size
reg        hold_direction;     // grab the direction of motion
wire       debounced_go;       // debounced inverted version of BUS_ACC_GO_L
wire       debounced_ready;    // debounced BUS_ACCESS_RDY_DRIVE_H


// state definitions and values for the seek action
`define SKST0 2'd0    // 0 - idle
`define SKST1 2'd1    // 1 - seek request begins
`define SKST2 2'd2    // 2 - update cylinder after 5ms
`define SKST3 2'd3    // 3 - update cylinder after 5ms
reg [1:0] seek_state; // seek state machine state variable

// 2310 disk drive is commanded to move forward or backward, with a 10 or 20 milli-inch step size
// no absolute seek to a target cylinder number
// the signal HOME is emitted when the arm is at cylinder 0
//============================ Start of Code =========================================

always @ (posedge clock)
begin

    if(reset == 1'b1) begin
        Cylinder_Address      <= 8'd0;
        BUS_ACCESS_RDY_EMUL_H <= 1'b1;
        BUS_HOME_DRIVE_EMUL_L <= 1'b0;
        seek_timer            <= 19'd0;
        strobe_selected_ready <= 1'b0;
        oncylinder_counter    <= 5'd0;
        oncylinder_indicator  <= 1'b0;
        hold_step             <= 1'b0;
        hold_direction        <= 1'b0;
        group_timer           <= 5'd0;
        completed_seek        <= 1'b0;
        seek_state            <= `SKST0;
    end
    else begin

        // we emit for the duration of a seek
        strobe_selected_ready <= (debounced_go) && (strobe_selected_ready == 1'b0)
                                 ? 1'b1
                                 :  debounced_go == 1'b0
                                   ? 1'b0
                                   : strobe_selected_ready;

                             
        // when access go was blipped in the last cycle, count for 14.5 ms worth of time
        // this is needed in virtual mode
        seek_timer <=  (strobe_selected_ready) && (debounced_go) && (seek_timer == 19'd0)
                        ?  19'd14500   
                         : (clkenbl_1usec == 1'b1)
                             ? (seek_timer == 0)
                                ? seek_timer
                                : seek_timer - 1
                             : seek_timer;

        // generated to go low at 5.5ms after go and returns high after full 14.5 ms
        BUS_ACCESS_RDY_EMUL_H <= (seek_timer > 10000) || (seek_timer == 0);

        // emit emulated home switch, used in virtual mode, when arm at track 0
        BUS_HOME_DRIVE_EMUL_L <= (Cylinder_Address == 8'd0) 
                                ? 1'b0
                                : 1'b1;

        // on strobe set counter, at falling edge of sector count down, thus flash for 150 ms
        oncylinder_counter <= strobe_selected_ready == 1'b1
                         ? 16 
                         : (clkenbl_sector == 1'b1)
                                ? (oncylinder_counter == 0) 
                                        ? 0 
                                        : oncylinder_counter - 1
                                : oncylinder_counter;

        // flash of SEEK indicator because seek was requested within 150ms
        oncylinder_indicator <= (oncylinder_counter != 0);

        case(seek_state)
        // sitting idle waiting for a seek request
        `SKST0: begin    

           // always reset to Home when cartridge is unloaded
           // or the reset_cylinder flag is set
           // also in real mode, reset if we start at home cylinder
           Cylinder_Address <= ((Cart_Ready == 1'b0) || (Reset_Cylinder == 1'b1))
                               ? 0
                               :  (real_drive == 1'b1) && (BUS_HOME_L == 1'b0)
                                  ?  0
                                  :  Cylinder_Address;

           // save the step size because it may be reset when Access Ready goes low
           hold_step  <= BUS_10_20_L;

           // save the direction of motion as well
           hold_direction <= BUS_ACC_REV_L;

           // process group timer every microsecond
           group_timer    <=  (clkenbl_1usec == 1'b1)
                              ?  (group_timer > 0)
                                 ?  group_timer - 1
                                 :  group_timer
                              :  group_timer;

           // turn on completed_seek if group_timer about to drop to zero
           completed_seek <=  (clkenbl_1usec == 1'b1) && (group_timer == 1)
                              ?  1'b1
                              :  oncylinder_indicator == 1'b0
                                 ?  1'b0
                                 :  completed_seek;
           
           // if we see the Acc Go signal begin a seek 
           seek_state <= ((strobe_selected_ready) && (debounced_go))
                             ? `SKST1
                             : `SKST0;

        end

        // wait here for debouncer interval, then for -Access Go goes high
        `SKST1: begin

           // turn off completed_seek and reset the group timer
           completed_seek  <= 1'b0;
           group_timer     <= 5'd31;
                                    
           seek_state <= real_drive == 1'b1
                           ?  ((debounced_go == 1'b0) && (debounced_ready == 1'b0))
                              ?  `SKST2
                              :  `SKST1
                           :  ((debounced_go == 1'b0) && (BUS_ACCESS_RDY_EMUL_H == 1'b0))
                              ?  `SKST2
                              :  `SKST1;

        end

        // grab the seek results
        `SKST2: begin

            // move cylinder location
            Cylinder_Address <= (hold_direction == 1'b1)  // forward
                                // move 1 or 2 tracks forward unless already at 202
                                ? hold_step == 1'b1         // 1 = 20 mil step, 0 = 10 mil step
                                  ? Cylinder_Address < 200
                                    ? Cylinder_Address + 2
                                    : 202
                                  : Cylinder_Address < 201
                                    ? Cylinder_Address + 1
                                    : 202
                                // move 1 or 2 tracks in reverse unless already at home (0)
                                :  hold_step == 1'b1         // 1 = 20 mil step, 0 = 10 mil step
                                   ? Cylinder_Address > 2
                                      ? Cylinder_Address - 2
                                      : 0
                                   : Cylinder_Address > 1
                                      ? Cylinder_Address - 1
                                      : 0;

           // turn off completed_seek and reset the group timer
           completed_seek  <= 1'b0;
           group_timer     <= 5'd31;

            // go wait for the next seek  
            seek_state <= `SKST3;

        end

        // wait to end the seek
        `SKST3: begin

           // turn off completed_seek and reset the group timer
           completed_seek  <= 1'b0;
           group_timer     <= 5'd31;

            // go wait for the next seek            
            seek_state <= real_drive == 1'b1
                          ?  (debounced_ready == 1'b1)
                             ? `SKST0
                             : `SKST3
                          :  (seek_timer == 0)
                             ?  `SKST0
                             :  `SKST3;

        end


        default: begin

           // turn off completed_seek and reset the group timer
           completed_seek  <= 1'b0;
           group_timer     <= 5'd31;

           seek_state <= `SKST0;

        end

        endcase

    end
end

// ======== Debouncer Module for ~BUS_ACC_GO_L ========
debouncer go_debouncer (
    // Inputs
    .clock (clock),
    .reset (reset),
    .input_data (~BUS_ACC_GO_L),
    .initial_state (1'b0),

    // Outputs
    .debounced_data (debounced_go)
);

// ======== Debouncer Module for BUS_ACCESS_RDY_DRIVE_H ========
debouncer ready_debouncer (
    // Inputs
    .clock (clock),
    .reset (reset),
    .input_data (BUS_ACCESS_RDY_H),
    .initial_state (1'b1),

    // Outputs
    .debounced_data (debounced_ready)
);


endmodule // End of Module sector_and_index
