//==========================================================================================================
// RK05 Emulator
// seek emulation from the BUS
// File Name: seek_to_cylinder.v
// Functions: 
//   TB for my module
//
//==========================================================================================================

module TB_seek_to_cylinder(
);

//============================ Internal Connections ==================================

     reg clock;
     reg reset;
     reg BUS_ACC_GO_L; 
     reg Selected_Ready; 
     reg BUS_ACC_REV_L; 
     reg BUS_10_20_L; 
     wire [7:0] Cylinder_Address; // internal register to store the valid cylinder address
     wire BUS_ACCESS_RDY_EMUL_H;       // access ready signal
     wire BUS_HOME_DRIVE_EMUL_L;             // at home cylinder (0) when low
     wire oncylinder_indicator;   // active high signal to drive the On Cylinder front panel indicator
     wire strobe_selected_ready;   // synchronized strobe and selected_ready for command interrupt

     reg [7:0] bitclockdivider_clockphase;
     reg [7:0] bitclockdivider_dataphase;
     reg [7:0] bitpulse_width;
     wire clock_pulse;       // clock pulse with proper 160 us width from drive
     wire data_pulse;       // data pulse with proper 160 us width from drive
     wire clkenbl_read_bit;  // enable for disk read clock
     wire clkenbl_read_data; // enable for disk read data
     wire clkenbl_1usec;
     reg clkenbl_sector;

 seek_to_cylinder DUT (
.clock (clock),
.reset (reset),
.Selected_Ready (Selected_Ready),      
.BUS_ACC_GO_L (BUS_ACC_GO_L), 
.BUS_ACC_REV_L  (BUS_ACC_REV_L), 
.BUS_10_20_L  (BUS_10_20_L),     
.clkenbl_1usec  (clkenbl_1usec),   
.clkenbl_sector  (clkenbl_sector),   
.Cylinder_Address  (Cylinder_Address), 
.BUS_ACCESS_RDY_EMUL_H (BUS_ACCESS_RDY_EMUL_H),  
.BUS_HOME_DRIVE_EMUL_L (BUS_HOME_DRIVE_EMUL_L),    
.oncylinder_indicator (oncylinder_indicator),
.strobe_selected_ready  (strobe_selected_ready)   
);

 timing_gen mytiming (
     .clock (clock),             // master clock 40 MHz
    .reset (reset),             // active high synchronous reset input
    .bitclockdivider_clockphase (bitclockdivider_clockphase),
    .bitclockdivider_dataphase (bitclockdivider_dataphase),
    .bitpulse_width (bitpulse_width),
    .clkenbl_read_bit (clkenbl_read_bit),  // enable for disk read clock
    .clkenbl_read_data (clkenbl_read_data), // enable for disk read data
    .clock_pulse (clock_pulse),       // clock pulse with proper 160 us width from drive
    .data_pulse (data_pulse),        // data pulse with proper 160 us width from drive
    .clkenbl_1usec (clkenbl_1usec)     // enable for 1 usec clock pulse
);


//============================ Start of Code =========================================

`define BACKONE \
      begin \
      BUS_ACC_REV_L <= 1'b0;  \
      BUS_10_20_L <= 1'b0;  \
      #250 \
      BUS_ACC_GO_L <= 1'b0; \
      #250 \
      BUS_ACC_GO_L <= 1'b1; \
      end

`define STEPONE \
      BUS_ACC_REV_L <= 1'b1; \
      BUS_10_20_L <= 1'b0;  \
      #250 \
      BUS_ACC_GO_L <= 1'b0; \
      #250 \
      BUS_ACC_GO_L <= 1'b1;

`define BACKTWO \
      BUS_ACC_REV_L <= 1'b0;  \
      BUS_10_20_L <= 1'b1;  \
      #250 \
      BUS_ACC_GO_L <= 1'b0; \
      #250 \
      BUS_ACC_GO_L <= 1'b1;

`define STEPTWO \
      BUS_ACC_REV_L <= 1'b1; \
      BUS_10_20_L <= 1'b1;   \
      #250 \
      BUS_ACC_GO_L <= 1'b0; \
      #250 \
      BUS_ACC_GO_L <= 1'b1;

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

// start off our timing generator
  initial begin
    bitclockdivider_clockphase <= 8'd28;
    bitclockdivider_dataphase <= 8'd28;
    bitpulse_width <= 8'd16;
  end

// sector pulses
  initial begin
    clkenbl_sector <= 1'b0;
    @(negedge reset)
    forever begin
       @(posedge clkenbl_1usec)
       clkenbl_sector <= 1'b1;
       #25
       clkenbl_sector <= 1'b0;
       #9999975
       clkenbl_sector <= 1'b0;
       end
  end
 

// drive our seek logic
    initial begin
      BUS_10_20_L <= 1'b1;   // 20 mil
      BUS_ACC_REV_L <= 1'b1; // forward
      BUS_ACC_GO_L <= 1'b1;  // not move request
      @(negedge reset)
      #20000
     `STEPTWO    // from 0 to 2
      @(posedge BUS_ACCESS_RDY_EMUL_H)
      #4000000
      `STEPONE   // from 2 to 3
      @(posedge BUS_ACCESS_RDY_EMUL_H)
      #34000000
      `BACKTWO   // from 3 to 1
      @(posedge BUS_ACCESS_RDY_EMUL_H)
      #200000
      `BACKTWO   // from 1 to home
      @(posedge BUS_ACCESS_RDY_EMUL_H)
      #1000000
      `BACKONE   // stay at home
      @(posedge BUS_ACCESS_RDY_EMUL_H)
      #1000000
      `STEPTWO   // from 0 to 2
      @(posedge BUS_ACCESS_RDY_EMUL_H)
      #1000000
      `STEPTWO   // from 2 to 4
      @(posedge BUS_ACCESS_RDY_EMUL_H)
      #1000000
      `STEPTWO   // from 4 to 6
      @(posedge BUS_ACCESS_RDY_EMUL_H)
      #1000000
      BUS_ACC_GO_L <= 1'b1;
      repeat (100) 
          begin
          `STEPTWO   // eventually stopped at 202
          @(posedge BUS_ACCESS_RDY_EMUL_H)
          BUS_ACC_GO_L <= 1'b1;
          end
      `BACKONE      // should get to 201
      @(posedge BUS_ACCESS_RDY_EMUL_H)
      #1000000
      `STEPONE      // should get to 202
      @(posedge BUS_ACCESS_RDY_EMUL_H)
      #1000000
      `STEPONE      // should stay at 202
      @(posedge BUS_ACCESS_RDY_EMUL_H)
      BUS_ACC_GO_L <= 1'b1;      
    end

// we are selected
  initial begin
    Selected_Ready <= 1'b1;
  end

endmodule // End of Module TB_seek_to_cylinder
