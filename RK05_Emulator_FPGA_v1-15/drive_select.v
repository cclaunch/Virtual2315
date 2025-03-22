//==========================================================================================================
// RK05 Emulator
// Drive Select Logic
// File Name: drive_select.v
// Functions: 
//   Activate the global Selected signal when drive is turned on and 90 seconds has elapsed.
//   If in real drive (hybrid) mode, most signals are passed through and Select is always on
//
// Modified by Carl V Claunch for 2310 drive
//
//==========================================================================================================

module drive_select(
    input wire clock,                  // FPGA 40MHz clock
    input wire reset,                  // power on reset
    input wire clkenbl_1usec,          // microsecond pulses to advance our timers
    input wire real_drive,             // is this hybrid mode with real drive creating signals?
    input wire Cart_Ready,             // microSD has loaded virtual cartridge file into DRAM
    input wire BUS_UNLOCKED_DRIVE_H,   // real drive unlocked status
    output reg BUS_90SEC_RELAY_EMUL_L, // relay allowing drive to purge air before dropping heads
    output reg BUS_UNLOCKED_EMUL_L,    // cartridge can be inserted
    output reg Selected                // active high output enable signal indicates that the drive is selected
);

//============================ Internal Connections ==================================

// state definitions and values for the startup state
`define ST0 2'd0 // 0 - off
`define ST1 2'd1 // 1 - spinning up
`define ST2 2'd2 // 2 - running
reg [1:0] startup_state; // read state machine state variable

reg [27:0] timer;         // ninety second timer

//============================ Start of Code =========================================


always @ (posedge clock)
begin : SELECT // block name

  if(reset==1'b1) begin
    Selected <= 1'b0;
    BUS_UNLOCKED_EMUL_L <= 1'b1;
    BUS_90SEC_RELAY_EMUL_L <= 1'b0;
    timer <= 28'd90000000;
    startup_state <= `ST0;
  end
  else begin

    case(startup_state)

// drive is off, waiting for Run switch to be activated, when file loaded from microSD
    `ST0: begin     
      // when to move out of idle state
      startup_state <=  real_drive == 1'b1
                        ?  `ST2
                        :  (Cart_Ready == 1'b1) 
                           ? `ST1 
                           : `ST0;

      // light the unlocked lamp and make sure Select is off if emulated
      BUS_UNLOCKED_EMUL_L <= real_drive == 1'b1
                             ? ~BUS_UNLOCKED_DRIVE_H
                             : 1'b0;
      Selected <= 1'b0;
      BUS_90SEC_RELAY_EMUL_L <= 1'b1;

      // timer set at 90 seconds (counting in microseconds)
      timer <= 28'd90000000;

     end

// motor spinning and purging air during 90 seconds
    `ST1: begin     
      // move to online when fully spinning
      startup_state <= (Cart_Ready == 1'b1) 
                        ? (timer == 0) 
                               ? `ST2 
                               : `ST1 
                        : `ST0;

      // decrement timer
      timer <=   clkenbl_1usec == 1'b1
                 ? timer - 1
                 : timer;

      // turn off unlocked lamp
      BUS_UNLOCKED_EMUL_L <= real_drive == 1'b1
                             ? ~BUS_UNLOCKED_DRIVE_H
                             : 1'b1;

      // still not ready if emulated
      Selected <= 1'b0;

      BUS_90SEC_RELAY_EMUL_L <= 1'b1;

     end

// spinning and ready to go 
    `ST2: begin     

      // stay running until the Run switch is turned off   
      startup_state <= real_drive == 1'b1
                       ? `ST2
                       :(Cart_Ready == 1'b1) 
                        ? `ST2 
                        : `ST0;

      // tell the world we are selected and ready
      Selected <= 1'b1;

      BUS_90SEC_RELAY_EMUL_L <= 1'b0;

      // unlocked lamp remains off in virtual mode, 
      // mirrors physical drive in real mode
      BUS_UNLOCKED_EMUL_L <= real_drive == 1'b1
                          ?  ~BUS_UNLOCKED_DRIVE_H
                          :  1'b1;

     end

    default: begin
      startup_state <= `ST0;
    end

    endcase

  end
end // End of Block SELECT


endmodule // End of Module drive_select
