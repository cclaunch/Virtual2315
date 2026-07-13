//==========================================================================================================
// RK05 Emulator
// seek emulation from the BUS
// File Name: sector_and_index.v
// Functions: 
//   TB for my module
//
//==========================================================================================================

module TB_sector_and_index(
);

//============================ Internal Connections ==================================

     reg clock;
     reg reset;
     wire clkenbl_1usec;                  // 1 usec clock enable input from the timing generator
     reg real_drive;                   // on to relay the real pulses from the 2310, off to generate
     reg BUS_SECTOR_L;                   // sector pulse from the 2310
     reg BUS_INDEX_L;                    // index pulse from the 2310
     wire clkenbl_sector;       // enable for disk read clock
     wire clkenbl_index;        // enable for disk read data
     wire BUS_INDEX_EMUL_H;     // active-high 165 usec sector pulse
     wire BUS_SECTOR_EMUL_H;      // active-high 165 usec index pulse
     wire [1:0] Sector_Address; //counter that specifies which sector is present "under the heads"


     wire clock_pulse;       // clock pulse with proper 165 us width from drive
     wire data_pulse;       // data pulse with proper 165 us width from drive
     wire clkenbl_read_bit;  // enable for disk read clock
     wire clkenbl_read_data; // enable for disk read data

 sector_and_index DUT (
.clock (clock),
.reset (reset),
.clkenbl_1usec (clkenbl_1usec),      
.real_drive (real_drive),      
.BUS_SECTOR_L (BUS_SECTOR_L),      
.BUS_INDEX_L (BUS_INDEX_L),      
.clkenbl_sector (clkenbl_sector),      
.clkenbl_index (clkenbl_index),      
.BUS_SECTOR_EMUL_H (BUS_SECTOR_EMUL_H),      
.BUS_INDEX_EMUL_H (BUS_INDEX_EMUL_H),      
.Sector_Address (Sector_Address)      
);

 timing_gen mytiming (
     .clock (clock),             // master clock 40 MHz
    .reset (reset),             // active high synchronous reset input
    .clkenbl_read_bit (clkenbl_read_bit),  // enable for disk read clock
    .clkenbl_read_data (clkenbl_read_data), // enable for disk read data
    .clock_pulse (clock_pulse),       // clock pulse with proper 160 us width from drive
    .data_pulse (data_pulse),        // data pulse with proper 160 us width from drive
    .clkenbl_1usec (clkenbl_1usec)     // enable for 1 usec clock pulse
);


//============================ Start of Code =========================================
// clock and reset
  initial begin
    clock = 1'b0;
    forever #12.5 clock = ~clock;
  end
 
  initial begin
   reset = 1'b1;
   #25
   reset = 1'b0;
  end


// sector pulses
  initial begin
    BUS_SECTOR_L <= 1'b1;
    @(negedge reset)
    #500000
    forever begin
       BUS_SECTOR_L <= 1'b0;
       #165000
       BUS_SECTOR_L <= 1'b1;
       #4835000
       BUS_SECTOR_L <= 1'b0;
    end
  end
 
// index pulses
  initial begin
    BUS_INDEX_L <= 1'b1;
    @(negedge reset)
    #1100000
    forever begin
       BUS_INDEX_L <= 1'b0;
       #165000
       BUS_INDEX_L <= 1'b1;
       #39835000
       BUS_INDEX_L <= 1'b0;
    end
  end
 

// drive our logic
    initial begin
       real_drive <= 1'b1;
    end


endmodule // End of Module TB_sector_and_index