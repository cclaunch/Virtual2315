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
//   Respond with bus Access Ready which drops 5 ms after access go received and 
//   remains low for another 10 ms before returning high. Only care about falling
//   edge of BUS_ACC_GO_L to indicate a seek has begun
//
//   flickers the oncylinder indicator to indicate a seek (150 millisecond duration)
//
//   the real Home signal from the disk drive is used to force sync to cylinder zero in real mode
//
// Modified for 2310 by Carl Claunch
//
//==========================================================================================================

module seek_to_cylinder(
    input wire clock,                  // master clock 40 MHz
    input wire reset,                  // active high synchronous reset input
    input wire Selected_Ready,         // disk contents have been copied from the microSD to the SDRAM 
                                       // & drive selected & ~fault latch
    input wire BUS_ACC_GO_L,           // request movement of the heads when low
    input wire BUS_ACC_REV_L,          // access direction for arm movement, high is forward
    input wire BUS_10_20_L,            // one or two cylinder arm movement, low is 10 mil
    input wire clkenbl_sector,         // blip at each logical 2310 sector
    input wire clkenbl_1usec,          // 1 usec clock enable input from the timing generator
    input wire BUS_HOME_DRIVE_L,       // disk drive home indicator
//    input wire BUS_ACCESS_RDY_DRIVE_H, // disk drive ready for seek commands
    input Cart_Ready,                  // virtual cartridge loaded
    input wire real_drive,             // real or virtual mode
    input wire Reset_Cylinder,         // control flag to force arm to home position

    output reg [7:0] Cylinder_Address, // internal register to store the valid cylinder address
    output reg BUS_ACCESS_RDY_EMUL_H,  // access ready signal
    output reg BUS_HOME_DRIVE_EMUL_L,  // at home cylinder (0) when low
    output reg oncylinder_indicator,   // active high signal to drive the On Cylinder front panel indicator
    output reg strobe_selected_ready   // synchronized access go and selected_ready for command interrupt
);

//============================ Internal Connections ==================================

reg [3:0] meta_bus_go;        // sampling and metastability reduction of Bus Access Go
reg [3:0] meta_bus_accdir;    // sampling and metastability reduction of Bus Access Rev
reg [3:0] meta_bus_10_20;     // sampling and metastability reduction of Bus Access 10/20
reg [3:0] meta_bus_sector;    // sampling and metastability reduction of Bus clkenbl_sector
reg [3:0] meta_bus_home;      // sampling and metastability reduction of Bus Home Drive
// reg [3:0] meta_bus_ready;     // sampling and metastability reduction of Bus Access Ready
reg [18:0] seek_timer;        // counts microseconds while seek is active
reg [4:0] oncylinder_counter; // counts to blink the seek light
reg       hold_step;          // grab the step size
reg       hold_direction;     // grab the direction of motion

// state definitions and values for the seek action
`define SKST0 3'd0 // 0 - idle
`define SKST1 3'd1 // 1 - seek request begins
`define SKST2 3'd2 // 2 - update cylinder after 5ms
// define SKST3 3'd3 // 3 - virtual ready restored after 15ms
// define SKST4 3'd4 // 4 - real verify access ready on strobe
// define SKST5 3'd5 // 5 - real wait for access ready to drop
// define SKST6 3'd6 // 6 - real grab seek results
// define SKST7 3'd7 // 7 - real wait for access ready to rise
reg [1:0] seek_state; // seek state machine state variable

// 2310 disk drive is commanded to move forward or backward, with a 10 or 20 milli-inch step size
// no absolute seek to a target cylinder number
// the signal HOME is emitted when the arm is at cylinder 0
//============================ Start of Code =========================================

always @ (posedge clock)
begin

    if(reset == 1'b1) begin
        Cylinder_Address      <= 8'd0;
        meta_bus_go[3:0]      <= 4'h0;
        meta_bus_accdir[3:0]  <= 4'h0;
        meta_bus_10_20[3:0]   <= 4'h0;
        meta_bus_sector[3:0]  <= 4'h0;
        meta_bus_home[3:0]    <= 4'h0;
//        meta_bus_ready[3:0]   <= 4'h0;
        BUS_ACCESS_RDY_EMUL_H <= 1'b1;
        BUS_HOME_DRIVE_EMUL_L <= 1'b0;
        seek_timer            <= 19'd0;
        strobe_selected_ready <= 1'b0;
        oncylinder_counter    <= 5'd0;
        oncylinder_indicator  <= 1'b0;
        hold_step             <= 1'b0;
        hold_direction        <= 1'b0;
        seek_state            <= `SKST0;
    end
    else begin

        // we have a falling edge request for a seek (meta_bus_go is inverted from -Access Go)
        strobe_selected_ready <= (meta_bus_go[3]  == 1'b0) && (meta_bus_go[2] == 1'b1);

        // when access go was blipped in the last cycle, count for 15 ms worth of time
        // this is needed in virtual mode
        seek_timer <=  (strobe_selected_ready)
                        ? 19'd15000
                        : (clkenbl_1usec == 1'b1)
                          ? (seek_timer == 0)
                             ? seek_timer
                             : seek_timer - 1
                          : seek_timer;

        // for virtual, goes low at 5ms after go and returns high after full 15 ms
        BUS_ACCESS_RDY_EMUL_H <= (seek_timer > 10000) || (seek_timer == 0);

        // clock domain crossing elimination of metastable states
        meta_bus_go[3:0]     <= {meta_bus_go[2:0], ~BUS_ACC_GO_L};
        meta_bus_accdir[3:0] <= {meta_bus_accdir[2:0], BUS_ACC_REV_L};
        meta_bus_10_20[3:0]  <= {meta_bus_10_20[2:0], BUS_10_20_L};
        meta_bus_sector[3:0] <= {meta_bus_sector[2:0], clkenbl_sector};
        meta_bus_home[3:0]   <= {meta_bus_home[2:0], BUS_HOME_DRIVE_L};
//        meta_bus_ready[3:0]  <= {meta_bus_ready[2:0], BUS_ACCESS_RDY_DRIVE_H};

        // emit emulated home switch, used in virtual mode, when arm at track 0
        BUS_HOME_DRIVE_EMUL_L <= (Cylinder_Address == 8'd0) 
                                ? 1'b0
                                : 1'b1;

        // on strobe set counter, at falling edge of sector count down, thus flash for 150 ms
        oncylinder_counter <= strobe_selected_ready == 1'b1
                         ? 16 
                         : (meta_bus_sector[3] == 1'b1 && meta_bus_sector[2] == 1'b0)
                                ? (oncylinder_counter == 0) 
                                        ? 0 
                                        : oncylinder_counter - 1
                                : oncylinder_counter;

        // flash of SEEK indicator because seek was requested within 150ms
        oncylinder_indicator <= (oncylinder_counter != 0);

        case(seek_state)
        // sitting idle waiting for a seek request
        `SKST0: begin    

           // if we see the Acc Go signal begin a seek 
           seek_state <= (strobe_selected_ready)
                             ? `SKST1
                             : `SKST0;

           // always reset to Home when cartridge is unloaded
           // or the reset_cylinder flag is set
           Cylinder_Address <= ((Cart_Ready == 1'b0) || (Reset_Cylinder == 1'b1))
                               ? 0
                               : Cylinder_Address;

           // save the step size because it may be reset when Access Ready goes low
           hold_step  <= meta_bus_10_20[3];

           // save the direction of motion as well
           hold_direction <= meta_bus_accdir[3];
        end

        // request received in virtual mode
        `SKST1: begin    

           // if we see Acc Ready drop, move to state 2 
           seek_state <=  BUS_ACCESS_RDY_EMUL_H == 1'b0
                             ? `SKST2
                             : `SKST1;

        end

        // Access Ready dropped 
        //`SKST2: begin     

           // when Acc Ready comes back on it virtual, move to final state
        //   seek_state <=  BUS_ACCESS_RDY_EMUL_H == 1'b1
        //                     ? `SKST3
        //                     : `SKST2;

//        end

        // Access Ready raised
//        `SKST3: begin     

            // move cylinder location
  //          Cylinder_Address <= (hold_direction == 1'b1)  // forward
                                // move 1 or 2 tracks forward unless already at 202
    //                            ? hold_step == 1'b1         // 1 = 20 mil step, 0 = 10 mil step
      //                            ? Cylinder_Address < 200
        //                            ? Cylinder_Address + 2
          //                          : 202
            //                      : Cylinder_Address < 201
              //                      ? Cylinder_Address + 1
                //                    : 202
                                // move 1 or 2 tracks in reverse unless already at home (0)
                  //              : hold_step == 1'b1         // 1 = 20 mil step, 0 = 10 mil step
                    //              ? Cylinder_Address > 2
                      //              ? Cylinder_Address - 2
                        //            : 0
                          //        : Cylinder_Address > 1
                            //        ? Cylinder_Address - 1
                              //      : 0;

             // now we are done
//             seek_state <= `SKST0;

  //      end

        // verify we had access ready else ignore spurious access go request
//        `SKST4: begin


            // if access ready is on, advance else bail out
  //          seek_state <= (meta_bus_ready[3] == 1'b1)
    //                      ? `SKST5
      //                    : `SKST0;

        //end

        // wait for access ready to drop 
//        `SKST5: begin

            // if it drops, move on. 
            // if seek timer pops, bail out, 
            // otherwise stay here waiting
  //          seek_state <= (meta_bus_ready[3] == 1'b0)
    //                      ? `SKST6
      //                    : (seek_timer == 19'd0)
        //                    ?  `SKST0
          //                  :  `SKST5;

     //   end

        // grab the seek results
        `SKST2: begin

            // move cylinder location
            Cylinder_Address <= ((~meta_bus_home[3]) && real_drive == 1'b1) 
     	                        // home switch went on in real mode, set Cylinder to 0
          	                ? 0
                                : (hold_direction == 1'b1)  // forward
                                   // move 1 or 2 tracks forward unless already at 202
                                   ? hold_step == 1'b1         // 1 = 20 mil step, 0 = 10 mil step
                                     ? Cylinder_Address < 200
                                       ? Cylinder_Address + 2
                                       : 202
                                     : Cylinder_Address < 201
                                       ? Cylinder_Address + 1
                                       : 202
                                   // move 1 or 2 tracks in reverse unless already at home (0)
                                   : hold_step == 1'b1         // 1 = 20 mil step, 0 = 10 mil step
                                     ? Cylinder_Address > 2
                                       ? Cylinder_Address - 2
                                       : 0
                                     : Cylinder_Address > 1
                                       ? Cylinder_Address - 1
                                       : 0;

            // go wait for the next seek
            seek_state <= `SKST0;

        end

        // wait for access ready to go high
//        `SKST7: begin

            // when high, we are done else wait
  //          seek_state <= (meta_bus_ready[3] == 1'b1)
    //                      ? `SKST0
      //                    : `SKST7;

        //end

        default: begin
            seek_state <= `SKST0;
        end

        endcase

    end
end

endmodule // End of Module sector_and_index
