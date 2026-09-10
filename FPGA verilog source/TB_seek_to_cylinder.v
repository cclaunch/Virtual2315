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
     wire completed_seek;          // our new pulse for end of a seek
     reg BUS_HOME_L;      // disk drive home indicator
     reg BUS_ACCESS_RDY_H; // disk drive ready for seek commands
     reg Cart_Ready;                  // virtual cartridge loaded
     reg Reset_Cylinder;            // reset request when drive goes not ready

     wire clock_pulse;       // clock pulse with proper 160 us width from drive
     wire data_pulse;       // data pulse with proper 160 us width from drive
     wire clkenbl_read_bit;  // enable for disk read clock
     wire clkenbl_read_data; // enable for disk read data
     wire clkenbl_1usec;
     reg clkenbl_sector;
     reg realseek;
     wire SEEK_FEEDBACK;

//============================ Start of Code =========================================

// clock and reset
  initial begin
    clock = 1'b0;
    forever #12.5 clock = ~clock;
  end
 
   assign SEEK_FEEDBACK = BUS_ACCESS_RDY_H;
//   assign SEEK_FEEDBACK = BUS_ACCESS_RDY_EMUL_H;

  initial begin
   reset = 1'b1;
   real_drive = 1'b1;
//   real_drive = 1'b0;
   Reset_Cylinder = 1'b0;
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

`define BACKONE \
      realseek <= 1'b1; \
      BUS_ACC_REV_L <= 1'b0;  \
      BUS_10_20_L <= 1'b0;  \
      #250 \
      BUS_ACC_GO_L <= 1'b0; \
      realseek <= 1'b0; \
      @(negedge SEEK_FEEDBACK   ) \
      BUS_ACC_GO_L <= 1'b1; 

`define STEPONE \
      BUS_ACC_REV_L <= 1'b1; \
      realseek <= 1'b1; \
      BUS_10_20_L <= 1'b0;  \
      #250 \
      realseek <= 1'b0; \
      BUS_ACC_GO_L <= 1'b0; \
      @(negedge SEEK_FEEDBACK   ) \
      BUS_ACC_GO_L <= 1'b1;

`define BACKTWO \
      BUS_ACC_REV_L <= 1'b0;  \
      realseek <= 1'b1; \
      BUS_10_20_L <= 1'b1;  \
      #250 \
      realseek <= 1'b0; \
      BUS_ACC_GO_L <= 1'b0; \
      @(negedge SEEK_FEEDBACK   ) \
      BUS_ACC_GO_L <= 1'b1;

`define STEPTWO \
      BUS_ACC_REV_L <= 1'b1; \
      realseek <= 1'b1; \
      BUS_10_20_L <= 1'b1;   \
      #250 \
      realseek <= 1'b0; \
      BUS_ACC_GO_L <= 1'b0; \
      @(negedge SEEK_FEEDBACK   ) \
      BUS_ACC_GO_L <= 1'b1;

`define GLITCHONE \
      BUS_ACC_REV_L <= 1'b1; \
      BUS_10_20_L <= 1'b0;  \
      #250 \
      BUS_ACC_GO_L <= 1'b0; \
      #100 \
      BUS_ACC_GO_L <= 1'b1; \
      #100000 \
      BUS_ACC_GO_L <= 1'b1;

`define GLITCHTWO \
      BUS_ACC_REV_L <= 1'b1; \
      realseek <= 1'b1; \
      BUS_10_20_L <= 1'b1;  \
      #250 \
      realseek <= 1'b0; \
      BUS_ACC_GO_L <= 1'b0; \
      #3000000 \
      BUS_ACC_GO_L <= 1'b1; \
      #200 \
      BUS_ACC_GO_L <= 1'b0; \
      @(negedge SEEK_FEEDBACK   ) \
      BUS_ACC_GO_L <= 1'b1; \
      #100000 \
      BUS_ACC_GO_L <= 1'b1;

`define GLITCHTHREE \
      BUS_ACC_REV_L <= 1'b1; \
      realseek <= 1'b1; \
      BUS_10_20_L <= 1'b1;  \
      #250 \
      realseek <= 1'b0; \
      BUS_ACC_GO_L <= 1'b0; \
      @(negedge SEEK_FEEDBACK   ) \
      BUS_ACC_GO_L <= 1'b1; \
      #1999980 \
      BUS_ACC_GO_L <= 1'b0; \
      #20 \
      BUS_ACC_GO_L <= 1'b1; \
      #3000000 \
      BUS_ACC_GO_L <= 1'b1; \
      #3000000 \
      BUS_ACC_GO_L <= 1'b1;

`define GLITCHFOUR \
      #3000 \
      BUS_ACC_GO_L <= 1'b0; \
      #100 \
      BUS_ACC_GO_L <= 1'b1; \
      #1000


 
// drive our seek logic
    initial begin
      realseek <= 1'b0; 
      BUS_10_20_L <= 1'b1;   // 20 mil
      BUS_ACC_REV_L <= 1'b1; // forward
      BUS_ACC_GO_L <= 1'b1;  // not move request
      @(negedge reset)
      #20000
      `GLITCHONE  // ignore
      #3000
      `STEPONE    // from 0 to 1
      @(posedge SEEK_FEEDBACK   )
      #310
      `STEPTWO   // from 1 to 3
      @(posedge SEEK_FEEDBACK   )
      #3000
      `GLITCHTWO   // from 3 to 5
      @(posedge SEEK_FEEDBACK   )
      #3500
      `STEPTWO   // from 5 to 7
      @(posedge SEEK_FEEDBACK   )
      #510
      `GLITCHTHREE   // from 7 to 9
      @(posedge SEEK_FEEDBACK   )
      #35000
      `STEPTWO   // from 9 to 11
      repeat (6) 
          begin
          @(posedge SEEK_FEEDBACK   )
          #350
          `STEPTWO   // eventually stopped at 23
          end
      @(posedge SEEK_FEEDBACK   )
      #500000
      realseek <= 1'b0; 
      #500000
      realseek <= 1'b0; 
      #500000
      realseek <= 1'b0; 
      #500000
      realseek <= 1'b0; 
      #500000
      `BACKONE      // should get to 22
      @(posedge SEEK_FEEDBACK   )
      #350
      `GLITCHFOUR   // blip should be ignored before backup
      #360
      `BACKTWO      // should get to 20
      @(posedge SEEK_FEEDBACK   )
      #350
      `BACKTWO      // should get to 18
      @(posedge SEEK_FEEDBACK   )
      #350
      `BACKTWO      // should get to 16
      @(posedge SEEK_FEEDBACK   )
      #350
      `BACKTWO      // should get to 14
      @(posedge SEEK_FEEDBACK   )
      #350
      `BACKTWO      // should get to 12
      @(posedge SEEK_FEEDBACK   )
      #350
      `BACKTWO      // should get to 10
      @(posedge SEEK_FEEDBACK   )
      #350000
      `BACKTWO      // should get to 8
      @(posedge SEEK_FEEDBACK   )
      #350
      `BACKTWO      // should get to 6
      @(posedge SEEK_FEEDBACK   )
      #350
      `BACKTWO      // should get to 4
      @(posedge SEEK_FEEDBACK   )
      #350
      `BACKTWO      // should get to 2
      @(posedge SEEK_FEEDBACK   )
      #350
      `BACKTWO      // should get to 0
      @(posedge SEEK_FEEDBACK   )
      #350000
      `BACKTWO      // should stay at 0
      @(posedge SEEK_FEEDBACK   )
      #350
      `STEPONE      // should go to 1
      @(posedge SEEK_FEEDBACK   )
      BUS_ACC_GO_L <= 1'b1;      
    end

// generate the ACC READY drive signal
  initial begin
    BUS_ACCESS_RDY_H <= 1'b1;
    @(posedge Selected_Ready)
    BUS_ACCESS_RDY_H <= 1'b1;
    BUS_ACCESS_RDY_H <= 1'b1;
    forever begin
       @(negedge realseek)
       #4500000
       BUS_ACCESS_RDY_H <= 1'b0;
       #10000000
       BUS_ACCESS_RDY_H <= 1'b1;
       end
     end

// we are selected
  initial begin
    Selected_Ready <= 1'b0;
    BUS_HOME_L <= 1'b0;
    #20000
    Selected_Ready <= 1'b1;
    @(posedge BUS_ACC_GO_L)
    BUS_HOME_L <= 1'b1;
    repeat(324)
    begin
        #1000000
        BUS_HOME_L <= 1'b1;
    end
    BUS_HOME_L <= 1'b0;
    repeat(41)
    begin
        #1000000
        BUS_HOME_L <= 1'b0;
    end
    BUS_HOME_L <= 1'b1;
  end

 seek_to_cylinder DUT (
.clock (clock),
.reset (reset),
.Selected_Ready (Selected_Ready),      
.real_drive (real_drive),      
.Cart_Ready (Cart_Ready),      
.BUS_ACC_GO_L (BUS_ACC_GO_L), 
.BUS_ACC_REV_L  (BUS_ACC_REV_L), 
.BUS_10_20_L  (BUS_10_20_L),     
.BUS_HOME_L (BUS_HOME_L), 
.BUS_ACCESS_RDY_H (BUS_ACCESS_RDY_H), 
.clkenbl_1usec  (clkenbl_1usec),   
.clkenbl_sector  (clkenbl_sector),   
.Reset_Cylinder (Reset_Cylinder),
.Cylinder_Address  (Cylinder_Address), 
.BUS_ACCESS_RDY_EMUL_H (BUS_ACCESS_RDY_EMUL_H),  
.BUS_HOME_DRIVE_EMUL_L (BUS_HOME_DRIVE_EMUL_L),    
.oncylinder_indicator (oncylinder_indicator),
.completed_seek (completed_seek),
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

endmodule // End of Module TB_seek_to_cylinder