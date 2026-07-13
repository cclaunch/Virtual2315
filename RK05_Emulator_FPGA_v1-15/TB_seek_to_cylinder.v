//==========================================================================================================
// RK05 Emulator
// seek emulation from the BUS
// File Name: seek_to_cylinder.v
// Functions: 
//   TB for my module
//
//==========================================================================================================
//time_scale 1ps/1ps

module TB_seek_to_cylinder(
);

//============================ Internal Connections ==================================

     reg clock;
     reg reset;
     reg BUS_ACC_GO_L; 
     reg Selected_Ready; 
     reg real_drive;
     reg BUS_ACC_REV_L; 
     reg BUS_10_20_L; 
     wire [7:0] Cylinder_Address; // internal register to store the valid cylinder address
     wire BUS_ACCESS_RDY_EMUL_H;       // access ready signal
     wire BUS_HOME_DRIVE_EMUL_L;             // at home cylinder (0) when low
     wire oncylinder_indicator;   // active high signal to drive the On Cylinder front panel indicator
     wire strobe_selected_ready;   // synchronized strobe and selected_ready for command interrupt
     reg BUS_HOME_DRIVE_L;      // disk drive home indicator
     reg BUS_ACCESS_RDY_DRIVE_H; // disk drive ready for seek commands
     reg Cart_Ready;                  // virtual cartridge loaded

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
.real_drive (real_drive),      
.Cart_Ready (Cart_Ready),      
.BUS_ACC_GO_L (BUS_ACC_GO_L), 
.BUS_ACC_REV_L  (BUS_ACC_REV_L), 
.BUS_10_20_L  (BUS_10_20_L),     
.BUS_HOME_DRIVE_L (BUS_HOME_DRIVE_L), 
.BUS_ACCESS_RDY_DRIVE_H (BUS_ACCESS_RDY_DRIVE_H), 
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
      @(negedge BUS_ACCESS_RDY_EMUL_H) \
      BUS_ACC_GO_L <= 1'b1; \
      end

`define STEPONE \
      BUS_ACC_REV_L <= 1'b1; \
      BUS_10_20_L <= 1'b0;  \
      #250 \
      BUS_ACC_GO_L <= 1'b0; \
      @(negedge BUS_ACCESS_RDY_EMUL_H) \
      BUS_ACC_GO_L <= 1'b1;

`define BACKTWO \
      BUS_ACC_REV_L <= 1'b0;  \
      BUS_10_20_L <= 1'b1;  \
      #250 \
      BUS_ACC_GO_L <= 1'b0; \
      @(negedge BUS_ACCESS_RDY_EMUL_H) \
      BUS_ACC_GO_L <= 1'b1;

`define STEPTWO \
      BUS_ACC_REV_L <= 1'b1; \
      BUS_10_20_L <= 1'b1;   \
      #250 \
      BUS_ACC_GO_L <= 1'b0; \
      @(negedge BUS_ACCESS_RDY_EMUL_H) \
      BUS_ACC_GO_L <= 1'b1;

// clock and reset
  initial begin
    clock = 1'b0;
    forever #12.5 clock = ~clock;
  end
 
  initial begin
   reset = 1'b1;
   real_drive = 1'b0;
   Cart_Ready = 1'b1;
    #2025
   reset = 1'b0;
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
      `STEPONE    // from 0 to 1
      @(posedge BUS_ACCESS_RDY_EMUL_H)
      `STEPTWO   // from 1 to 3
      @(posedge BUS_ACCESS_RDY_EMUL_H)
      `STEPTWO   // from 3 to 5
      @(posedge BUS_ACCESS_RDY_EMUL_H)
      `STEPTWO   // from 5 to 7
      repeat (96) 
          begin
          @(posedge BUS_ACCESS_RDY_EMUL_H)
          `STEPTWO   // eventually stopped at 199
          end
      @(posedge BUS_ACCESS_RDY_EMUL_H)
      `BACKONE      // should get to 201
      @(posedge BUS_ACCESS_RDY_EMUL_H)
      `STEPTWO      // should get to 202 not 203
      @(posedge BUS_ACCESS_RDY_EMUL_H)
      `STEPONE      // should stay at 202
      @(posedge BUS_ACCESS_RDY_EMUL_H)
      BUS_ACC_GO_L <= 1'b1;      
    end

// generate the ACC READY drive signal
  initial begin
    BUS_ACCESS_RDY_DRIVE_H <= 1'b0;
    @(posedge Selected_Ready)
    BUS_ACCESS_RDY_DRIVE_H <= 1'b1;
    forever begin
       @(negedge BUS_ACC_GO_L)
       #5000000
       BUS_ACCESS_RDY_DRIVE_H <= 1'b0;
       #10000000
       BUS_ACCESS_RDY_DRIVE_H <= 1'b1;
       end
     end

// we are selected
  initial begin
    Selected_Ready <= 1'b0;
    BUS_HOME_DRIVE_L <= 1'b0;
    #20000
    Selected_Ready <= 1'b1;
    @(posedge BUS_ACC_GO_L)
    BUS_HOME_DRIVE_L <= 1'b1;
  end

endmodule // End of Module TB_seek_to_cylinder