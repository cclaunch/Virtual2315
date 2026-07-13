//==========================================================================================================
// RK05 Emulator
// seek emulation from the BUS
// File Name: drive select.v
// Functions: 
//   TB for my module
//
//==========================================================================================================

module TB_drive_select(
);

//============================ Internal Connections ==================================

     reg clock;
     reg reset;
     reg clkenbl_1usec;                  // 1 usec clock enable input from the timing generator
     reg Cart_Ready;
     reg BUS_FILE_READY_DRIVE_L;
     wire BUS_90SEC_RELAY_EMUL_L;
     wire BUS_UNLOCKED_EMUL_L;
     wire Selected;
     reg  real_drive;


 drive_select DUT (
.clock (clock),
.reset (reset),
.real_drive (real_drive),
.clkenbl_1usec (clkenbl_1usec),      
.Cart_Ready (Cart_Ready),
.BUS_FILE_READY_DRIVE_L (BUS_FILE_READY_DRIVE_L),
.BUS_90SEC_RELAY_EMUL_L (BUS_90SEC_RELAY_EMUL_L),
.BUS_UNLOCKED_EMUL_L (BUS_UNLOCKED_EMUL_L),
.Selected (Selected)
);


//============================ Start of Code =========================================
// clock and reset
  initial begin
    clock = 1'b0;
    forever #12.5 clock = ~clock;
  end
 
  initial begin
   reset = 1'b1;
    #35
   reset = 1'b0;
  end

// load from microSD
  initial begin
    @(negedge reset)
    Cart_Ready <= 1'b0;
    #200000000
    Cart_Ready <= 1'b1;
    #1300000000
    Cart_Ready <= 1'b0;
  end

// turn on drive
  initial begin
    @(negedge reset)
    BUS_FILE_READY_DRIVE_L <= 1'b1;
    #300000000
    BUS_FILE_READY_DRIVE_L <= 1'b1;
    #1100000000
    BUS_FILE_READY_DRIVE_L <= 1'b1;
  end

// test conditions
 initial begin
   real_drive <= 1'b0;
 end

// 1 usec pulses
  initial begin
    clkenbl_1usec <= 1'b0;
    @(negedge reset)
    clkenbl_1usec <= 1'b1;
    #25
    clkenbl_1usec <= 1'b0;
    forever begin
      #975
      clkenbl_1usec <= 1'b1;
      #25
      clkenbl_1usec <= 1'b0;
    end
  end  

endmodule // End of Module TB_sector_and_index