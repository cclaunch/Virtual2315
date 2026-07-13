//==========================================================================================================
// RK05 Emulator
// 
// File Name: TB_entire.v
// Functions: 
//   TB for all modules
//
//==========================================================================================================
module TB_RK05_emulator_top_v03(
);

//============================ Internal Connections ==================================

reg BUS_ACCESS_RDY_DRIVE_H;
reg BUS_HOME_DRIVE_L;     // indicates at track zero
reg BUS_UNLOCKED_EMUL_L;       // indicates drive unlocked, ready to accept cartridge
reg BUS_WT_CLOCKB_DRIVE_L;      // 720 KHz clock to control writes
reg BUS_RD_DATA_DRIVE_L;
reg BUS_RD_CLK_DRIVE_L;
reg BUS_FILE_READY_DRIVE_L;
reg BUS_SECTOR_DRIVE_L;              // Sector pulse for sector module
reg BUS_INDEX_DRIVE_L;               // Sector pulse for sector module
reg BUS_WRITE_SEL_ERR_DRIVE_L;
reg BUS_90S_RELAY_DRIVE_L;    // 90 second relay while drive purges
reg BUS_UNLOCKED_DRIVE_H;
reg BUS_REAL_DRIVE;

reg BUS_10_20_CTRL_L;               // signal to enable movement for seek module
reg BUS_ACC_GO_DRIVE_CTRL_L;
reg BUS_ACC_REV_CTRL_L;
reg BUS_HEAD_SELECT_CTRL_L;
reg BUS_RD_GATE_CTRL_L;
reg BUS_WT_GATE_CTRL_L;
reg BUS_WT_DATA_CLK_CTRL_L;

wire BUS_10_20_DRIVE_L;
wire BUS_ACC_GO_DRIVE_DRIVE_L;
wire BUS_ACC_REV_DRIVE_L;
wire BUS_HEAD_SELECT_DRIVE_L;
wire BUS_RD_GATE_DRIVE_L;
wire BUS_WT_GATE_DRIVE_L;
wire BUS_WT_DATA_CLK_DRIVE_L;

wire BUS_ACCESS_RDY_CTRL_H;
wire BUS_HOME_CTRL_L;
wire BUS_WT_CLOCKB_CTRL_L;
wire BUS_RD_DATA_CTRL_L;
wire BUS_RD_CLK_CTRL_L;
wire BUS_FILE_READY_CTRL_L;
wire BUS_SECTOR_CTRL_L;
wire BUS_INDEX_CTRL_L;
wire BUS_WRITE_SEL_ERR_CTRL_L;
wire BUS_90S_RELAY_CTRL_L;
wire BUS_UNLOCKED_LIGHT_H;

wire CPU_SPI_MISO;
reg CPU_SPI_MOSI;
reg CPU_SPI_CLK;
reg CPU_SPI_CS_n;

wire FPANEL_READ_ONLY_indicator;
wire FPANEL_WR_indicator;
wire FPANEL_RD_indicator;
wire FPANEL_ON_CYL_indicator;

wire TESTER_OUTPUT_3_L;

wire Servo_Pulse_FPGA_pin;
wire SPARE_PIO1_24;
wire SELECTED_RDY_LED_N;
wire CMD_INTERRUPT;

reg clock;
reg pin_reset_n;

wire [15:0] SDRAM_DQ;
wire [12:0] SDRAM_Address;
wire SDRAM_BS0;
wire SDRAM_BS1;
wire SDRAM_WE_n;
wire SDRAM_CAS_n;
wire SDRAM_RAS_n;
wire SDRAM_CS_n;
wire SDRAM_CLK;
wire SDRAM_CKE;
wire SDRAM_DQML;
wire SDRAM_DQMH;
wire SDRAM_DQ_enable;

RK05_emulator_top mytop (

// BUS Connector Inputs, 19 signals

//  Drive side 12 signals
    .BUS_ACCESS_RDY_DRIVE_H (BUS_ACCESS_RDY_DRIVE_H),    // Seek ready and on-cylinder
    .BUS_HOME_DRIVE_L (BUS_HOME_DRIVE_L),          // indicates at track zero
    .BUS_WT_CLOCKB_DRIVE_L (BUS_WT_CLOCKB_DRIVE_L),     // 720 KHz clock to control writes
    .BUS_RD_DATA_DRIVE_L (BUS_RD_DATA_DRIVE_L),       // Read data pulses, 160 ns pulse
    .BUS_RD_CLK_DRIVE_L (BUS_RD_CLK_DRIVE_L),        // Read clock pulses, 160 ns pulse
    .BUS_FILE_READY_DRIVE_L (BUS_FILE_READY_DRIVE_L),    // drive is ready, heads loaded, no error latches
    .BUS_SECTOR_DRIVE_L (BUS_SECTOR_DRIVE_L),        // 160 us negative pulse each time a sector slot passes the transducer
    .BUS_INDEX_DRIVE_L (BUS_INDEX_DRIVE_L),         // 160 us negative pulse for each revolution of the disk, 600 μs after the sector pulse
    .BUS_WRITE_SEL_ERR_DRIVE_L (BUS_WRITE_SEL_ERR_DRIVE_L), // error when attempting write
    .BUS_90S_RELAY_DRIVE_L (BUS_90S_RELAY_DRIVE_L),     // 90 second relay while drive purges - when ends, send heads loaded
    .BUS_UNLOCKED_DRIVE_H (BUS_UNLOCKED_DRIVE_H),      // cart receiver unlocked on real drive - from solenoid
    .BUS_REAL_DRIVE (BUS_REAL_DRIVE),            // 1 if hybrid mode, 0 if virtual mode

//  Controller side 7 signals
    .BUS_10_20_CTRL_L (BUS_10_20_CTRL_L),          // seek step size, one or two tracks
    .BUS_ACC_GO_DRIVE_CTRL_L (BUS_ACC_GO_DRIVE_CTRL_L),   // Strobe to enable movement
    .BUS_ACC_REV_CTRL_L (BUS_ACC_REV_CTRL_L),        // direction of seek, forward or reverse
    .BUS_HEAD_SELECT_CTRL_L (BUS_HEAD_SELECT_CTRL_L),    // Head Select
    .BUS_RD_GATE_CTRL_L (BUS_RD_GATE_CTRL_L),        // Read gate, when active enables read circuitry
    .BUS_WT_GATE_CTRL_L (BUS_WT_GATE_CTRL_L),        // Write gate, when active enables write circuitry
    .BUS_WT_DATA_CLK_CTRL_L (BUS_WT_DATA_CLK_CTRL_L),    // Composite write data and write clock

// BUS Connector Outputs, 17 signals

//  Drive side 8 signals
    .BUS_10_20_DRIVE_L (BUS_10_20_DRIVE_L),        // seek step size, one or two tracks
    .BUS_ACC_GO_DRIVE_DRIVE_L (BUS_ACC_GO_DRIVE_DRIVE_L), // Strobe to enable movement
    .BUS_ACC_REV_DRIVE_L (BUS_ACC_REV_DRIVE_L),      // direction of seek, forward or reverse
    .BUS_HEAD_SELECT_DRIVE_L (BUS_HEAD_SELECT_DRIVE_L),  // Head Select
    .BUS_RD_GATE_DRIVE_L (BUS_RD_GATE_DRIVE_L),      // Read gate, when active enables read circuitry
    .BUS_WT_GATE_DRIVE_L (BUS_WT_GATE_DRIVE_L),      // Write gate, when active enables write circuitry
    .BUS_WT_DATA_CLK_DRIVE_L (BUS_WT_DATA_CLK_DRIVE_L),  // Composite write data and write clock

//  Controller side 10 signals
    .BUS_ACCESS_RDY_CTRL_H (BUS_ACCESS_RDY_CTRL_H),    // Seek ready and on-cylinder
    .BUS_HOME_CTRL_L (BUS_HOME_CTRL_L),          // indicates at track zero
    .BUS_WT_CLOCKB_CTRL_L (BUS_WT_CLOCKB_CTRL_L),     // 720 KHz clock to control writes
    .BUS_RD_DATA_CTRL_L (BUS_RD_DATA_CTRL_L),       // Read data pulses, 160 ns pulse
    .BUS_RD_CLK_CTRL_L (BUS_RD_CLK_CTRL_L),        // Read clock pulses, 160 ns pulse
    .BUS_FILE_READY_CTRL_L (BUS_FILE_READY_CTRL_L),    // data copied from microSD to SDRAM, drive is ready, heads loaded
    .BUS_SECTOR_CTRL_L (BUS_SECTOR_CTRL_L),        // 160 us negative pulse each time a sector slot passes the transducer
    .BUS_INDEX_CTRL_L (BUS_INDEX_CTRL_L),         // 160 us negative pulse for each revolution of the disk, 600 μs after the sector pulse
    .BUS_WRITE_SEL_ERR_CTRL_L (BUS_WRITE_SEL_ERR_CTRL_L), // error when attempting write
    .BUS_90S_RELAY_CTRL_L (BUS_90S_RELAY_CTRL_L),     // 90 second relay while drive purges
    .BUS_UNLOCKED_LIGHT_H (BUS_UNLOCKED_LIGHT_H),     // force UNLOCK lamp on if virtual drive and not running

// SDRAM I/O. 39 signals. 16 - DQ, 13 - Address: A0-A12, 2 - Addr Select: BS0 BS1, 8 - SDRAM Control: WE# CAS# RAS# CS# CLK CKE DQML DQMH
    .SDRAM_Address (SDRAM_Address),      // SDRAM Address
    .SDRAM_BS0 (SDRAM_BS0),	         // SDRAM Bank Select 0
    .SDRAM_BS1 (SDRAM_BS1),	         // SDRAM Bank Select 1
    .SDRAM_WE_n (SDRAM_WE_n),	         // SDRAM Write
    .SDRAM_CAS_n (SDRAM_CAS_n),          // SDRAM Column Address Select
    .SDRAM_RAS_n (SDRAM_RAS_n),          // SDRAM Row Address Select
    .SDRAM_CS_n (SDRAM_CS_n),	         // SDRAM Chip Select
    .SDRAM_CLK (SDRAM_CLK),	         // SDRAM Clock
    .SDRAM_CKE (SDRAM_CKE),	         // SDRAM Clock Enable
    .SDRAM_DQML (SDRAM_DQML),	         // SDRAM DQ Mask for Lower Byte
    .SDRAM_DQMH (SDRAM_DQMH),	         // SDRAM DQ Mask for Upper (High) Byte
    .SDRAM_DQ (SDRAM_DQ),                //SDRAM multiplexed Data Input & Output

// ESP32 CPU SPI Port 6 signals: MISO MOSI CLK CS 2-bit-register-select
    .CPU_SPI_MISO (CPU_SPI_MISO),       // SPI Controller Input Peripheral Output
    .CPU_SPI_MOSI (CPU_SPI_MOSI),       // SPI Controller Output Peripheral Input
    .CPU_SPI_CLK (CPU_SPI_CLK),         // SPI Controller Clock
    .CPU_SPI_CS_n (CPU_SPI_CS_n),       // SPI Controller Chip Select, active low
  
// Front Panel out from FPGA, 4 signals. READ_ONLY_indicator WR_indicator RD_indicator ON_CYL_indicator
    .FPANEL_READ_ONLY_indicator (FPANEL_READ_ONLY_indicator), // R/O indicator
    .FPANEL_WR_indicator (FPANEL_WR_indicator),               // Write indicator
    .FPANEL_RD_indicator (FPANEL_RD_indicator),               // Read indicator
    .FPANEL_ON_CYL_indicator (FPANEL_ON_CYL_indicator),       // On Cylinder indicator
  
// Clock and Reset external pins: pin_clock pin_reset
    .clock (clock),
    .pin_reset_n (pin_reset_n),
    
// Tester Outputs, new in Emulator v1 hardware UNUSED BY 2315
    .TESTER_OUTPUT_3_L (TESTER_OUTPUT_3_L), // this is pin 45

    .Servo_Pulse_FPGA_pin (Servo_Pulse_FPGA_pin),   // this is pin 73
    .SPARE_PIO1_24 (SPARE_PIO1_24),                 // this is pin 74
    .SELECTED_RDY_LED_N (SELECTED_RDY_LED_N),       // this is pin 75
    .CMD_INTERRUPT (CMD_INTERRUPT)                  // this is pin 76
);

// SIMULATION OF DISK DRIVE MACROS

`define ONE 1'b0
`define ZERO 1'b1

`define BIT(whazzit)   \
    @(negedge BUS_WT_CLOCKB_CTRL_L); \
    BUS_WT_DATA_CLK_CTRL_L <= 1'b0; \
    @(posedge BUS_WT_CLOCKB_CTRL_L); \
    BUS_WT_DATA_CLK_CTRL_L <= whazzit;  

`define WORD(bf, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, e0, e1, e2, e3)  \
    @(negedge BUS_WT_CLOCKB_CTRL_L); \
    BUS_WT_DATA_CLK_CTRL_L <= 1'b0; \
    @(posedge BUS_WT_CLOCKB_CTRL_L); \
    BUS_WT_DATA_CLK_CTRL_L <= ~1'b``b15; \
    @(negedge BUS_WT_CLOCKB_CTRL_L); \
    BUS_WT_DATA_CLK_CTRL_L <= 1'b0; \
    @(posedge BUS_WT_CLOCKB_CTRL_L); \
    BUS_WT_DATA_CLK_CTRL_L <= ~1'b``b14; \
    @(negedge BUS_WT_CLOCKB_CTRL_L); \
    BUS_WT_DATA_CLK_CTRL_L <= 1'b0; \
    @(posedge BUS_WT_CLOCKB_CTRL_L); \
    BUS_WT_DATA_CLK_CTRL_L <= ~1'b``b13; \
    @(negedge BUS_WT_CLOCKB_CTRL_L); \
    BUS_WT_DATA_CLK_CTRL_L <= 1'b0; \
    @(posedge BUS_WT_CLOCKB_CTRL_L); \
    BUS_WT_DATA_CLK_CTRL_L <= ~1'b``b12; \
    @(negedge BUS_WT_CLOCKB_CTRL_L); \
    BUS_WT_DATA_CLK_CTRL_L <= 1'b0; \
    @(posedge BUS_WT_CLOCKB_CTRL_L); \
    BUS_WT_DATA_CLK_CTRL_L <= ~1'b``b11; \
    @(negedge BUS_WT_CLOCKB_CTRL_L); \
    BUS_WT_DATA_CLK_CTRL_L <= 1'b0; \
    @(posedge BUS_WT_CLOCKB_CTRL_L); \
    BUS_WT_DATA_CLK_CTRL_L <= ~1'b``b10; \
    @(negedge BUS_WT_CLOCKB_CTRL_L); \
    BUS_WT_DATA_CLK_CTRL_L <= 1'b0; \
    @(posedge BUS_WT_CLOCKB_CTRL_L); \
    BUS_WT_DATA_CLK_CTRL_L <= ~1'b``b9; \
    @(negedge BUS_WT_CLOCKB_CTRL_L); \
    BUS_WT_DATA_CLK_CTRL_L <= 1'b0; \
    @(posedge BUS_WT_CLOCKB_CTRL_L); \
    BUS_WT_DATA_CLK_CTRL_L <= ~1'b``b8; \
    @(negedge BUS_WT_CLOCKB_CTRL_L); \
    BUS_WT_DATA_CLK_CTRL_L <= 1'b0; \
    @(posedge BUS_WT_CLOCKB_CTRL_L); \
    BUS_WT_DATA_CLK_CTRL_L <= ~1'b``b7; \
    @(negedge BUS_WT_CLOCKB_CTRL_L); \
    BUS_WT_DATA_CLK_CTRL_L <= 1'b0; \
    @(posedge BUS_WT_CLOCKB_CTRL_L); \
    BUS_WT_DATA_CLK_CTRL_L <= ~1'b``b6; \
    @(negedge BUS_WT_CLOCKB_CTRL_L); \
    BUS_WT_DATA_CLK_CTRL_L <= 1'b0; \
    @(posedge BUS_WT_CLOCKB_CTRL_L); \
    BUS_WT_DATA_CLK_CTRL_L <= ~1'b``b5; \
    @(negedge BUS_WT_CLOCKB_CTRL_L); \
    BUS_WT_DATA_CLK_CTRL_L <= 1'b0; \
    @(posedge BUS_WT_CLOCKB_CTRL_L); \
    BUS_WT_DATA_CLK_CTRL_L <= ~1'b``b4; \
    @(negedge BUS_WT_CLOCKB_CTRL_L); \
    BUS_WT_DATA_CLK_CTRL_L <= 1'b0; \
    @(posedge BUS_WT_CLOCKB_CTRL_L); \
    BUS_WT_DATA_CLK_CTRL_L <= ~1'b``b3; \
    @(negedge BUS_WT_CLOCKB_CTRL_L); \
    BUS_WT_DATA_CLK_CTRL_L <= 1'b0; \
    @(posedge BUS_WT_CLOCKB_CTRL_L); \
    BUS_WT_DATA_CLK_CTRL_L <= ~1'b``b2; \
    @(negedge BUS_WT_CLOCKB_CTRL_L); \
    BUS_WT_DATA_CLK_CTRL_L <= 1'b0; \
    @(posedge BUS_WT_CLOCKB_CTRL_L); \
    BUS_WT_DATA_CLK_CTRL_L <= ~1'b``b1; \
    @(negedge BUS_WT_CLOCKB_CTRL_L); \
    BUS_WT_DATA_CLK_CTRL_L <= 1'b0; \
    @(posedge BUS_WT_CLOCKB_CTRL_L); \
    BUS_WT_DATA_CLK_CTRL_L <= ~1'b``bf; \
    @(negedge BUS_WT_CLOCKB_CTRL_L); \
    BUS_WT_DATA_CLK_CTRL_L <= 1'b0; \
    @(posedge BUS_WT_CLOCKB_CTRL_L); \
    BUS_WT_DATA_CLK_CTRL_L <= ~1'b``e0; \
    @(negedge BUS_WT_CLOCKB_CTRL_L); \
    BUS_WT_DATA_CLK_CTRL_L <= 1'b0; \
    @(posedge BUS_WT_CLOCKB_CTRL_L); \
    BUS_WT_DATA_CLK_CTRL_L <= ~1'b``e1; \
    @(negedge BUS_WT_CLOCKB_CTRL_L); \
    BUS_WT_DATA_CLK_CTRL_L <= 1'b0; \
    @(posedge BUS_WT_CLOCKB_CTRL_L); \
    BUS_WT_DATA_CLK_CTRL_L <= ~1'b``e2; \
    @(negedge BUS_WT_CLOCKB_CTRL_L); \
    BUS_WT_DATA_CLK_CTRL_L <= 1'b0; \
    @(posedge BUS_WT_CLOCKB_CTRL_L); \
    BUS_WT_DATA_CLK_CTRL_L <= ~1'b``e3; 

// SIMULATION OF SPI LINK MACROS

`define SPIWORD(sp1, sp2, sp3, sp4, sp5, sp6, sp7, sp8, sp9, sp10, sp11, sp12, sp13, sp14, sp15, sp16) \
    CPU_SPI_CS_n = 1'b1; \
    @(negedge CPU_SPI_CLK); \
    CPU_SPI_MOSI <= 1'b``sp1; \
    CPU_SPI_CS_n = 1'b0; \
    @(negedge CPU_SPI_CLK); \
    CPU_SPI_MOSI <= 1'b``sp2; \
    @(negedge CPU_SPI_CLK); \
    CPU_SPI_MOSI <= 1'b``sp3; \
    @(negedge CPU_SPI_CLK); \
    CPU_SPI_MOSI <= 1'b``sp4; \
    @(negedge CPU_SPI_CLK); \
    CPU_SPI_MOSI <= 1'b``sp5; \
    @(negedge CPU_SPI_CLK); \
    CPU_SPI_MOSI <= 1'b``sp6; \
    @(negedge CPU_SPI_CLK); \
    CPU_SPI_MOSI <= 1'b``sp7; \
    @(negedge CPU_SPI_CLK); \
    CPU_SPI_MOSI <= 1'b``sp8; \
    @(negedge CPU_SPI_CLK); \
    CPU_SPI_MOSI <= 1'b``sp9; \
    @(negedge CPU_SPI_CLK); \
    CPU_SPI_MOSI <= 1'b``sp10; \
    @(negedge CPU_SPI_CLK); \
    CPU_SPI_MOSI <= 1'b``sp11; \
    @(negedge CPU_SPI_CLK); \
    CPU_SPI_MOSI <= 1'b``sp12; \
    @(negedge CPU_SPI_CLK); \
    CPU_SPI_MOSI <= 1'b``sp13; \
    @(negedge CPU_SPI_CLK); \
    CPU_SPI_MOSI <= 1'b``sp14; \
    @(negedge CPU_SPI_CLK); \
    CPU_SPI_MOSI <= 1'b``sp15; \
    @(negedge CPU_SPI_CLK); \
    CPU_SPI_MOSI <= 1'b``sp16; \
//    @(negedge CPU_SPI_CLK); \
//    CPU_SPI_CS_n = 1'b0; \
    @(negedge CPU_SPI_CLK); \
    CPU_SPI_CS_n = 1'b1;

// define seek macro
`define SEEK(dir, step) \
      BUS_ACCESS_RDY_DRIVE_H <= 1'b1; \
      BUS_10_20_CTRL_L <= 1'b``step;           // move 10 mils if 0 \
      BUS_ACC_REV_CTRL_L <= 1'b``dir;          // move forward if 1 \
      #1001 \
      BUS_ACC_GO_DRIVE_CTRL_L <= 1'b0;        // request seek \
      @(negedge BUS_ACC_GO_DRIVE_DRIVE_L) \
      BUS_ACCESS_RDY_DRIVE_H <= 1'b0;         // turn off ready \
      #3000 \
      BUS_ACC_GO_DRIVE_CTRL_L <= 1'b1;        // drop seek \
      BUS_10_20_CTRL_L <= 1'b1; \
      BUS_ACC_REV_CTRL_L <= 1'b1; \
      #15000000 \
      BUS_ACCESS_RDY_DRIVE_H <= 1'b1;         // turn on ready

//============================ Start of Code =========================================
// clock and reset
  initial begin
    clock = 1'b0;
    forever #12.5 clock = ~clock;
  end
 
  initial begin
   pin_reset_n = 1'b0;
    #25
   pin_reset_n  = 1'b1;
  end

// generate SPI clock
  initial begin
    CPU_SPI_CLK = 1'b0;
    forever #20 CPU_SPI_CLK = ~CPU_SPI_CLK;
  end

// give me some SPI words to load SDRAM
  initial begin
    CPU_SPI_MOSI <= 1'b0;
    CPU_SPI_CS_n = 1'b1;
    #3331
    // set cart ready and 
    `SPIWORD(0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0)
//    #1000
    // read status back
//    `SPIWORD(1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
//    #1000
    // load address 0001A00 for SDRAM - cyl 1, head 1, sector 1
//    `SPIWORD(0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0)
//    #1000
//    `SPIWORD(0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 1, 1, 0, 1, 0)
//    #1000
//    `SPIWORD(0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0)
//    #5000
    // now we read the words, two 88 messages per word, 001A00 address
//    `SPIWORD(1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
//    #1000
//    `SPIWORD(1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
//    #1000
//    // 001A01 address
//    `SPIWORD(1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
//    #1000
//    `SPIWORD(1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
//    #1000
//    // 001A02 address
//    `SPIWORD(1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
//    #1000
//    `SPIWORD(1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
//    #1000
//    // 001A03 address
//    `SPIWORD(1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
//    #1000
//    `SPIWORD(1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
//    #1000
    // 001A04 address
//    `SPIWORD(1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
//    #1000
//    `SPIWORD(1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
//    #1000
    // 001A05 address
//    `SPIWORD(1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
//    #1000
//    `SPIWORD(1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    @(negedge BUS_FILE_READY_CTRL_L)
    #5000
    `SPIWORD(0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)
    #5000
    `SPIWORD(0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)
    #5000
    `SPIWORD(0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)
  end

// turn on drive
   initial begin
         BUS_90S_RELAY_DRIVE_L <= 1'b1;    // 90 second relay while drive purges
         BUS_FILE_READY_DRIVE_L <= 1'b1;
         BUS_UNLOCKED_DRIVE_H <= 1'b1;
         #2000
         BUS_UNLOCKED_DRIVE_H <= 1'b0;
         #100000
         BUS_90S_RELAY_DRIVE_L <= 1'b0;    // 90 second relay while drive purges
         @(negedge BUS_90S_RELAY_CTRL_L)
         BUS_FILE_READY_DRIVE_L <= 1'b0;
   end

// sector clk pulses
    initial begin 
         BUS_SECTOR_DRIVE_L <= 1'b1;              // Sector pulse for sector module
         #201034
         forever begin
             BUS_SECTOR_DRIVE_L <= 1'b0;              // Sector pulse for sector module
             #165000
             BUS_SECTOR_DRIVE_L <= 1'b1;              // Sector pulse for sector module
             #1835000
             BUS_SECTOR_DRIVE_L <= 1'b1;              // Sector pulse for sector module
             #1500000
             BUS_SECTOR_DRIVE_L <= 1'b1;              // Sector pulse for sector module
             #1500000
             BUS_SECTOR_DRIVE_L <= 1'b1;              // Sector pulse for sector module
         end
    end

// index pulses
  initial begin
         BUS_INDEX_DRIVE_L <= 1'b1;               // index pulse for sector module
         @(negedge BUS_SECTOR_DRIVE_L)
         BUS_INDEX_DRIVE_L <= 1'b1;               // index pulse for sector module
         #200000
         BUS_INDEX_DRIVE_L <= 1'b1;               // index pulse for sector module
         #200000
         BUS_INDEX_DRIVE_L <= 1'b1;               // index pulse for sector module
         #200000
         BUS_INDEX_DRIVE_L <= 1'b1;               // index pulse for sector module
         #10000
         forever begin
            BUS_INDEX_DRIVE_L <= 1'b0;               // index pulse for sector module
            #165000
            BUS_INDEX_DRIVE_L <= 1'b1;               // index pulse for sector module
            #2000000
            BUS_INDEX_DRIVE_L <= 1'b1;               // index pulse for sector module
            #2000000
            BUS_INDEX_DRIVE_L <= 1'b1;               // index pulse for sector module
            #2000000
            BUS_INDEX_DRIVE_L <= 1'b1;               // index pulse for sector module
            #2000000
            BUS_INDEX_DRIVE_L <= 1'b1;               // index pulse for sector module
            #2000000
            BUS_INDEX_DRIVE_L <= 1'b1;               // index pulse for sector module
            #2000000
            BUS_INDEX_DRIVE_L <= 1'b1;               // index pulse for sector module
            #2000000
            BUS_INDEX_DRIVE_L <= 1'b1;               // index pulse for sector module
            #2000000
            BUS_INDEX_DRIVE_L <= 1'b1;               // index pulse for sector module
            #2000000
            BUS_INDEX_DRIVE_L <= 1'b1;               // index pulse for sector module
            #2000000
            BUS_INDEX_DRIVE_L <= 1'b1;               // index pulse for sector module
            #2000000
            BUS_INDEX_DRIVE_L <= 1'b1;               // index pulse for sector module
            #2000000
            BUS_INDEX_DRIVE_L <= 1'b1;               // index pulse for sector module
            #2000000
            BUS_INDEX_DRIVE_L <= 1'b1;               // index pulse for sector module
            #2000000
            BUS_INDEX_DRIVE_L <= 1'b1;               // index pulse for sector module
            #2000000
            BUS_INDEX_DRIVE_L <= 1'b1;               // index pulse for sector module
            #2000000
            BUS_INDEX_DRIVE_L <= 1'b1;               // index pulse for sector module
            #2000000
            BUS_INDEX_DRIVE_L <= 1'b1;               // index pulse for sector module
            #2000000
            BUS_INDEX_DRIVE_L <= 1'b1;               // index pulse for sector module
            #2000000
            BUS_INDEX_DRIVE_L <= 1'b1;               // index pulse for sector module
            #1835000
            BUS_INDEX_DRIVE_L <= 1'b1;               // index pulse for sector module
         end
  end

// do seeks
   initial begin
      BUS_ACCESS_RDY_DRIVE_H <= 1'b1;
      BUS_HOME_DRIVE_L <= 1'b0;     // indicates at track zero
      BUS_10_20_CTRL_L <= 1'b1;               // signal to enable movement for seek module
      BUS_ACC_GO_DRIVE_CTRL_L <= 1'b1;
      BUS_ACC_REV_CTRL_L <= 1'b1;
      @(negedge BUS_FILE_READY_DRIVE_L)
      @(negedge BUS_SECTOR_CTRL_L)
      `SEEK(1,1)
      BUS_HOME_DRIVE_L <= 1'b1;               // not at track zero
      `SEEK(0,0)
   end

// set to head 1 for our read test
   initial begin
      BUS_HEAD_SELECT_CTRL_L <= 1'b1;
   end

// do a read at sector 1
   initial begin
      BUS_RD_GATE_CTRL_L <= 1'b1;
      @(negedge BUS_FILE_READY_DRIVE_L)
      BUS_RD_GATE_CTRL_L <= 1'b1;
      @(negedge BUS_INDEX_CTRL_L) // see index pulse so sector 0 coming up
      BUS_RD_GATE_CTRL_L <= 1'b1;
      @(negedge BUS_INDEX_CTRL_L) // second index pulse sector 0 coming up
      BUS_RD_GATE_CTRL_L <= 1'b1;
      @(negedge BUS_SECTOR_CTRL_L) // wait for skipped pulse before 0
      BUS_RD_GATE_CTRL_L <= 1'b1;
      @(negedge BUS_SECTOR_CTRL_L) // wait for pulse at sector 0
      BUS_RD_GATE_CTRL_L <= 1'b1;
      @(negedge BUS_SECTOR_CTRL_L) // wait for skipped pulse before 1
      BUS_RD_GATE_CTRL_L <= 1'b1;
      @(negedge BUS_SECTOR_CTRL_L) // wait for sector 1 pulse
//      BUS_RD_GATE_CTRL_L <= 1'b0;
      @(negedge BUS_SECTOR_CTRL_L) // wait for skipped pulse before 2
//      BUS_RD_GATE_CTRL_L <= 1'b0;
      @(negedge BUS_SECTOR_CTRL_L) // wait for sector 2
      BUS_RD_GATE_CTRL_L <= 1'b1;
   end

// trigger write at desired point
     initial begin
      BUS_WT_GATE_CTRL_L <= 1'b1;
      @(negedge BUS_FILE_READY_DRIVE_L)
      BUS_WT_GATE_CTRL_L <= 1'b1;
      @(negedge BUS_INDEX_CTRL_L) // see index pulse so sector 0 coming up
      BUS_WT_GATE_CTRL_L <= 1'b1;
      @(negedge BUS_INDEX_CTRL_L) // see next index pulse so sector 0 coming up
      BUS_WT_GATE_CTRL_L <= 1'b1;
      @(negedge BUS_SECTOR_CTRL_L) // wait for skipped pulse before 0
      BUS_WT_GATE_CTRL_L <= 1'b1;
      @(negedge BUS_SECTOR_CTRL_L) // wait for pulse at sector 0
      BUS_WT_GATE_CTRL_L <= 1'b1;
      @(negedge BUS_SECTOR_CTRL_L) // wait for skipped pulse before 1
      BUS_WT_GATE_CTRL_L <= 1'b1;
      @(negedge BUS_SECTOR_CTRL_L) // wait for sector 1 pulse
//      BUS_WT_GATE_CTRL_L <= 1'b0;
      @(negedge BUS_SECTOR_CTRL_L) // wait for skipped pulse before 2
//      BUS_WT_GATE_CTRL_L <= 1'b0;
      @(negedge BUS_SECTOR_CTRL_L) // wait for sector 2
      BUS_WT_GATE_CTRL_L <= 1'b1;
     end

// emit the controlling signal for writes into the controller
    initial begin
         BUS_WT_CLOCKB_DRIVE_L <= 1'b1;      // 720 KHz clock to control writes
         @(negedge BUS_WT_GATE_CTRL_L)
         forever #720 BUS_WT_CLOCKB_DRIVE_L <= ~BUS_WT_CLOCKB_DRIVE_L;
    end

// drive a write of a sector
     initial begin
        BUS_WT_DATA_CLK_CTRL_L <= 1'b1;
        @(posedge pin_reset_n);
        BUS_WT_DATA_CLK_CTRL_L <= 1'b1;
        @(negedge BUS_WT_GATE_CTRL_L)
        BUS_WT_DATA_CLK_CTRL_L <= 1'b1;
        @(posedge BUS_SECTOR_CTRL_L)
        repeat(188)
        begin
            `BIT(`ZERO)
        end
        `BIT(`ONE )                  // 1 bit sync word 8000
        `BIT(`ONE )                  // 1 bit check bit 1
        `BIT(`ONE )                  // 1 bit check bit 2
        `BIT(`ONE )                  // 1 bit check bit 3
        `BIT(`ZERO)                  // 0 bit end of sync,check bit 4
// word one A5A5
        `WORD(1, 0, 1, 0, 0, 1, 0, 1, 1, 0, 1, 0, 0, 1, 0, 1, 0, 0, 0, 0)
// word two 8001
        `WORD(1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0)
// word three 8801
        `WORD(1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0)
// word four  90A2
        `WORD(1, 0, 0, 1, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 1, 0, 1, 1, 1, 0)
// word five  A5A5
        `WORD(1, 0, 1, 0, 0, 1, 0, 1, 1, 0, 1, 0, 0, 1, 0, 1, 0, 0, 0, 0)
// word six  8001
        `WORD(1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0)
// word seven  0000
        `WORD(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
// word eight 0008
        `WORD(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 1, 1, 0)
// word nine  0009
        `WORD(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 1, 1, 0, 0)
// word ten  000A
        `WORD(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 1, 0, 0)
     repeat(310)
         begin   // 1248
             `WORD(0, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0)
         end
// word 321   FFFF
        `WORD(1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0)
// extra words  0000
     `WORD(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
     `WORD(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
     `WORD(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
     `WORD(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
     `WORD(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
     `WORD(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
     `WORD(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
     `WORD(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
     `WORD(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
     `WORD(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
     `WORD(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
     end

// preset inputs
     initial begin
         BUS_REAL_DRIVE <= 1'b1;
         BUS_UNLOCKED_EMUL_L <= 1'b1;       // indicates drive unlocked, ready to accept cartridge
         BUS_RD_DATA_DRIVE_L <= 1'b1;
         BUS_RD_CLK_DRIVE_L <= 1'b1;
         BUS_WRITE_SEL_ERR_DRIVE_L <= 1'b1;
     end

endmodule // End of Module TB_bus_disk_read
