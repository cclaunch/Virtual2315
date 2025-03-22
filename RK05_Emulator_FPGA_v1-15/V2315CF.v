//==========================================================================================================
// RK05 Emulator
// Top Level definition
// File Name: V2315CF.v
//
// Modified for 2310 by Carl Claunch
//
//==========================================================================================================
//
//===============================================================================================//
//                                                                                               //
// This FPGA firmware and related modules included by the top level module and files used to     //
// build the software are provided on an as-is basis. No warrantees or guarantees are provided   //
// or implied. Users of the RK05 Emulator or RK05 Tester shall not hold the developers of this   //
// software, firmware, hardware, or related documentation liable for any damages caused by       //
// any type of malfunction of the product including malfunctions caused by defects in the design //
// or operation of the software, firmware, hardware or use of related documentation or any       //
// combination thereof.                                                                          //
//                                                                                               //
//===============================================================================================//
//

`include "bus_disk_read.v"
`include "bus_disk_write.v"
`include "bus_outputs.v"
`include "clock_and_reset.v"
`include "drive_select.v"
`include "sdram_controller.v"
`include "sector_and_index.v"
`include "seek_to_cylinder.v"
`include "spi_interface.v"
`include "timing_gen.v"

//================================= TOP LEVEL INPUT-OUTPUT DEFINITIONS =====================================
module V2315CF (

// BUS Connector Inputs, 19 signals

//  Drive side 12 signals
    input wire BUS_ACCESS_RDY_DRIVE_H,    // Seek ready and on-cylinder
    input wire BUS_HOME_DRIVE_L,          // indicates at track zero
    input wire BUS_WT_CLOCKB_DRIVE_L,     // 720 KHz clock to control writes
            // These next two signals are not read nor used in this design
            // as the heads are not lowered on the drive nor active
    input wire BUS_RD_DATA_DRIVE_L,       // Read data pulses, 160 ns pulse
    input wire BUS_RD_CLK_DRIVE_L,        // Read clock pulses, 160 ns pulse
    input wire BUS_FILE_READY_DRIVE_L,    // drive is ready, heads loaded, no error latches
    input wire BUS_SECTOR_DRIVE_L,        // 160 us negative pulse each time a sector slot passes the transducer
    input wire BUS_INDEX_DRIVE_L,         // 160 us negative pulse for each revolution of the disk, 600 μs after the sector pulse
    input wire BUS_WRITE_SEL_ERR_DRIVE_L, // error when attempting write
    input wire BUS_90S_RELAY_DRIVE_L,     // 90 second relay while drive purges - when ends, send heads loaded
    input wire BUS_UNLOCKED_DRIVE_H,      // cart receiver unlocked on real drive - from solenoid
    input wire BUS_REAL_DRIVE,            // 1 if hybrid mode, 0 if virtual mode

//  Controller side 7 signals
    input wire BUS_10_20_CTRL_L,          // seek step size, one or two tracks
    input wire BUS_ACC_GO_DRIVE_CTRL_L,   // Strobe to enable movement
    input wire BUS_ACC_REV_CTRL_L,        // direction of seek, forward or reverse
    input wire BUS_HEAD_SELECT_CTRL_L,    // Head Select
    input wire BUS_RD_GATE_CTRL_L,        // Read gate, when active enables read circuitry
    input wire BUS_WT_GATE_CTRL_L,        // Write gate, when active enables write circuitry
    input wire BUS_WT_DATA_CLK_CTRL_L,    // Composite write data and write clock

// BUS Connector Outputs, 18 signals

//  Drive side 7 signals
    output wire BUS_10_20_DRIVE_L,        // seek step size, one or two tracks
    output wire BUS_ACC_GO_DRIVE_DRIVE_L, // Strobe to enable movement
    output wire BUS_ACC_REV_DRIVE_L,      // direction of seek, forward or reverse
    output wire BUS_HEAD_SELECT_DRIVE_L,  // Head Select
    output wire BUS_RD_GATE_DRIVE_L,      // Read gate, when active enables read circuitry
    output wire BUS_WT_GATE_DRIVE_L,      // Write gate, when active enables write circuitry
    output wire BUS_WT_DATA_CLK_DRIVE_L,  // Composite write data and write clock

//  Controller side 11 signals
    output wire BUS_ACCESS_RDY_CTRL_H,    // Seek ready and on-cylinder
    output wire BUS_HOME_CTRL_L,          // indicates at track zero
    output wire BUS_WT_CLOCKB_CTRL_L,     // 720 KHz clock to control writes
    output wire BUS_RD_DATA_CTRL_L,       // Read data pulses, 160 ns pulse
    output wire BUS_RD_CLK_CTRL_L,        // Read clock pulses, 160 ns pulse
    output wire BUS_FILE_READY_CTRL_L,    // data copied from microSD to SDRAM, drive is ready, heads loaded
    output wire BUS_SECTOR_CTRL_L,        // 160 us negative pulse each time a sector slot passes the transducer
    output wire BUS_INDEX_CTRL_L,         // 160 us negative pulse for each revolution of the disk, 600 μs after the sector pulse
    output wire BUS_WRITE_SEL_ERR_CTRL_L, // error when attempting write
    output wire BUS_90S_RELAY_CTRL_L,     // 90 second relay while drive purges
    output wire BUS_UNLOCKED_LIGHT_H,     // force UNLOCK lamp on if virtual drive and not running

// SDRAM I/O. 39 signals. 16 - DQ, 13 - Address: A0-A12, 2 - Addr Select: BS0 BS1, 8 - SDRAM Control: WE# CAS# RAS# CS# CLK CKE DQML DQMH
    output wire [12:0] SDRAM_Address,// SDRAM Address
    output wire SDRAM_BS0,	         // SDRAM Bank Select 0
    output wire SDRAM_BS1,	         // SDRAM Bank Select 1
    output wire SDRAM_WE_n,	         // SDRAM Write
    output wire SDRAM_CAS_n,         // SDRAM Column Address Select
    output wire SDRAM_RAS_n,         // SDRAM Row Address Select
    output wire SDRAM_CS_n,	         // SDRAM Chip Select
    output wire SDRAM_CLK,	         // SDRAM Clock
    output wire SDRAM_CKE,	         // SDRAM Clock Enable
    output wire SDRAM_DQML,	         // SDRAM DQ Mask for Lower Byte
    output wire SDRAM_DQMH,	         // SDRAM DQ Mask for Upper (High) Byte
    inout wire [15:0] SDRAM_DQ,      //SDRAM multiplexed Data Input & Output

// ESP32 CPU SPI Port 4 signals: MISO MOSI CLK CS 
    output wire CPU_SPI_MISO,       // SPI Controller Input Peripheral Output
    input wire CPU_SPI_MOSI,        // SPI Controller Output Peripheral Input
    input wire CPU_SPI_CLK,         // SPI Controller Clock
    input wire CPU_SPI_CS_n,        // SPI Controller Chip Select, active low
  
// Front Panel from FPGA, 4 signals. READ_ONLY_indicator WR_indicator RD_indicator ON_CYL_indicator
    output wire FPANEL_READ_ONLY_indicator, // R/O indicator
    output wire FPANEL_WR_indicator,        // Write indicator
    output wire FPANEL_RD_indicator,        // Read indicator
    output wire FPANEL_ON_CYL_indicator,    // On Cylinder indicator
  
// Clock and Reset external pins: pin_clock pin_reset
    input wire clock,
    input wire pin_reset_n,
    
// Tester Outputs, new in Emulator v1 hardware
    output wire TESTER_OUTPUT_3_L, // this is pin 45

    output wire Servo_Pulse_FPGA_pin,   // this is pin 73
    output wire SPARE_PIO1_24,      // this is pin 74
    output wire SELECTED_RDY_LED_N, // this is pin 75
    output wire CMD_INTERRUPT      // this is pin 76
);

//============================ Internal Connections ==================================

wire [7:0] MAJOR_VERSION;
assign MAJOR_VERSION = 2;
wire [7:0] MINOR_VERSION;
assign MINOR_VERSION = 8;

wire reset;

wire BUS_HOME_DRIVE_EMUL_L;     // indicates at track zero
wire BUS_UNLOCKED_EMUL_L;       // indicates drive unlocked, ready to accept cartridge
wire BUS_WT_CLOCKB_EMUL_L;      // 720 KHz clock to control writes
wire BUS_SECTOR_EMUL_H;         // 160 us negative pulse each time a sector slot passes the transducer
wire BUS_INDEX_EMUL_H;          // 160 us negative pulse for each revolution of the disk, 600 μs after the sector pulse
wire BUS_90SEC_RELAY_EMUL_L;    // 90 second relay while drive purges
wire BUS_ACCESS_RDY_EMUL_H;     // signal from seek to cylinder module
wire BUS_ACC_GO_L;              // Strobe to enable movement for seek module
wire BUS_ACC_REV_L;             // signal to enable movement for seek module
wire BUS_10_20_L;               // signal to enable movement for seek module
wire BUS_SECTOR_L;              // Sector pulse for sector module
wire BUS_INDEX_L;               // Sector pulse for sector module
wire BUS_WT_GATE_L;             // signal for write module
wire BUS_RD_GATE_L;             // signal for read module
wire BUS_HEAD_SELECT_L;         // signal for seek module

wire clkenbl_sector;

wire ECC_error;
wire Read_Only;
wire Cart_Ready;
wire Fault_Latch;
wire real_drive;

wire Selected_Ready;
wire Selected;
wire [7:0] Cylinder_Address;
wire Head_Select;
wire [1:0] Sector_Address;
wire oncylinder_indicator;
wire write_indicator;
wire read_indicator;

wire BUS_RD_DATA_H;
wire BUS_RD_CLK_H;

wire load_address_spi;
wire load_address_busread;
wire load_address_buswrite;
wire dram_read_enbl_spi;
wire dram_read_enbl_busread;
wire dram_write_enbl_spi;
wire dram_write_enbl_buswrite;

wire [7:0] spi_serpar_reg;
wire [15:0] dram_readdata;
wire [15:0] dram_writedata_spi;
wire [15:0] dram_writedata_buswrite;
wire dram_addr_incr_buswrite;
wire dram_writeack;

wire [15:0] SDRAM_DQ_in;
wire [15:0] SDRAM_DQ_output;
wire SDRAM_DQ_enable;

wire clkenbl_read_bit;
wire clkenbl_read_data;
wire clock_pulse;
wire data_pulse;
wire clkenbl_1usec;

wire interface_test_mode;

wire strobe_selected_ready;
wire read_selected_ready;
wire write_selected_ready;

wire Servo_Pulse_FPGA;


//============================ MISC TOP LEVEL LOGIC TO DRIVE THE INDICATORS ==================================

assign FPANEL_READ_ONLY_indicator =  ~Read_Only;
assign FPANEL_WR_indicator =         ~write_indicator;
assign FPANEL_RD_indicator =         ~read_indicator;
assign FPANEL_ON_CYL_indicator =     ~(oncylinder_indicator & ~BUS_FILE_READY_CTRL_L);

assign SPARE_PIO1_24 = Selected;
assign SELECTED_RDY_LED_N = ~Selected_Ready;
assign TESTER_OUTPUT_3_L = interface_test_mode ? ~1'b1 : ~1'b0; // this is pin 45

assign Servo_Pulse_FPGA_pin = Servo_Pulse_FPGA;

assign real_drive = BUS_REAL_DRIVE; // hybrid mode if true

assign Head_Select = ~BUS_HEAD_SELECT_L;

assign BUS_UNLOCKED_LIGHT_H = ~BUS_UNLOCKED_EMUL_L;

// this is on when the cable is connected between 2310 and the 1130 system
// if not on, the drive write circuits are disabled thus we want this at 1
//  assign BUS_CE_INTLK_H = 1'b1;     // not an FPGA output signal, instead hard wired


//============================ SDRAM Bidirectional I/O pins ==================================

SB_IO DQ00
(
.PACKAGE_PIN (SDRAM_DQ[0]), // User's Pin signal name
.OUTPUT_ENABLE (SDRAM_DQ_enable), // Output Pin Tristate/Enable control
.D_OUT_0 (SDRAM_DQ_output[0]), // Data 0 - out to Pin
.D_IN_0 (SDRAM_DQ_in[0]), // Data 0 - Pin input
// n.c. pins we don't use
.LATCH_INPUT_VALUE (), .CLOCK_ENABLE (), .INPUT_CLK (), .OUTPUT_CLK (), .D_OUT_1 (), .D_IN_1 () 
);
defparam DQ00.PIN_TYPE = 6'b101001; // non-latched bi-directional I/O buffer
defparam DQ00.PULLUP = 1'b0;
// By default, the IO will have NO pull up.
// This parameter is used only on bank 0, 1, and 2. Ignored when it is placed at bank 3
defparam DQ00.NEG_TRIGGER = 1'b0;
// Specify the polarity of all FFs in the IO to be falling edge when NEG_TRIGGER = 1.
// Default is rising edge.
//defparam DQ00.IO_STANDARD = "LVCMOS";
// Other IO standards are supported in bank 3 only: SB_SSTL2_CLASS_2, SB_SSTL2_CLASS_1,
// SB_SSTL18_FULL, SB_SSTL18_HALF, SB_MDDR10,SB_MDDR8, SB_MDDR4, SB_MDDR2 etc.

SB_IO DQ01
(
.PACKAGE_PIN (SDRAM_DQ[1]),
.OUTPUT_ENABLE (SDRAM_DQ_enable),
.D_OUT_0 (SDRAM_DQ_output[1]),
.D_IN_0 (SDRAM_DQ_in[1]),
.LATCH_INPUT_VALUE (), .CLOCK_ENABLE (), .INPUT_CLK (), .OUTPUT_CLK (), .D_OUT_1 (), .D_IN_1 () 
);
defparam DQ01.PIN_TYPE = 6'b101001; // non-latched bi-directional I/O buffer
defparam DQ01.PULLUP = 1'b0;
defparam DQ01.NEG_TRIGGER = 1'b0;
//defparam DQ01.IO_STANDARD = "LVCMOS";

SB_IO DQ02
(
.PACKAGE_PIN (SDRAM_DQ[2]),
.OUTPUT_ENABLE (SDRAM_DQ_enable),
.D_OUT_0 (SDRAM_DQ_output[2]),
.D_IN_0 (SDRAM_DQ_in[2]),
// n.c. pins we don't use
.LATCH_INPUT_VALUE (), .CLOCK_ENABLE (), .INPUT_CLK (), .OUTPUT_CLK (), .D_OUT_1 (), .D_IN_1 () 
);
defparam DQ02.PIN_TYPE = 6'b101001; // non-latched bi-directional I/O buffer
defparam DQ02.PULLUP = 1'b0;
defparam DQ02.NEG_TRIGGER = 1'b0;
//defparam DQ02.IO_STANDARD = "LVCMOS";

SB_IO DQ03
(
.PACKAGE_PIN (SDRAM_DQ[3]),
.OUTPUT_ENABLE (SDRAM_DQ_enable),
.D_OUT_0 (SDRAM_DQ_output[3]),
.D_IN_0 (SDRAM_DQ_in[3]),
// n.c. pins we don't use
.LATCH_INPUT_VALUE (), .CLOCK_ENABLE (), .INPUT_CLK (), .OUTPUT_CLK (), .D_OUT_1 (), .D_IN_1 () 
);
defparam DQ03.PIN_TYPE = 6'b101001; // non-latched bi-directional I/O buffer
defparam DQ03.PULLUP = 1'b0;
defparam DQ03.NEG_TRIGGER = 1'b0;
//defparam DQ03.IO_STANDARD = "LVCMOS";

SB_IO DQ04
(
.PACKAGE_PIN (SDRAM_DQ[4]),
.OUTPUT_ENABLE (SDRAM_DQ_enable),
.D_OUT_0 (SDRAM_DQ_output[4]),
.D_IN_0 (SDRAM_DQ_in[4]),
// n.c. pins we don't use
.LATCH_INPUT_VALUE (), .CLOCK_ENABLE (), .INPUT_CLK (), .OUTPUT_CLK (), .D_OUT_1 (), .D_IN_1 () 
);
defparam DQ04.PIN_TYPE = 6'b101001; // non-latched bi-directional I/O buffer
defparam DQ04.PULLUP = 1'b0;
defparam DQ04.NEG_TRIGGER = 1'b0;
//defparam DQ04.IO_STANDARD = "LVCMOS";

SB_IO DQ05
(
.PACKAGE_PIN (SDRAM_DQ[5]),
.OUTPUT_ENABLE (SDRAM_DQ_enable),
.D_OUT_0 (SDRAM_DQ_output[5]),
.D_IN_0 (SDRAM_DQ_in[5]),
// n.c. pins we don't use
.LATCH_INPUT_VALUE (), .CLOCK_ENABLE (), .INPUT_CLK (), .OUTPUT_CLK (), .D_OUT_1 (), .D_IN_1 () 
);
defparam DQ05.PIN_TYPE = 6'b101001; // non-latched bi-directional I/O buffer
defparam DQ05.PULLUP = 1'b0;
defparam DQ05.NEG_TRIGGER = 1'b0;
//defparam DQ05.IO_STANDARD = "LVCMOS";

SB_IO DQ06
(
.PACKAGE_PIN (SDRAM_DQ[6]),
.OUTPUT_ENABLE (SDRAM_DQ_enable),
.D_OUT_0 (SDRAM_DQ_output[6]),
.D_IN_0 (SDRAM_DQ_in[6]),
// n.c. pins we don't use
.LATCH_INPUT_VALUE (), .CLOCK_ENABLE (), .INPUT_CLK (), .OUTPUT_CLK (), .D_OUT_1 (), .D_IN_1 () 
);
defparam DQ06.PIN_TYPE = 6'b101001; // non-latched bi-directional I/O buffer
defparam DQ06.PULLUP = 1'b0;
defparam DQ06.NEG_TRIGGER = 1'b0;
//defparam DQ06.IO_STANDARD = "LVCMOS";

SB_IO DQ07
(
.PACKAGE_PIN (SDRAM_DQ[7]),
.OUTPUT_ENABLE (SDRAM_DQ_enable),
.D_OUT_0 (SDRAM_DQ_output[7]),
.D_IN_0 (SDRAM_DQ_in[7]),
// n.c. pins we don't use
.LATCH_INPUT_VALUE (), .CLOCK_ENABLE (), .INPUT_CLK (), .OUTPUT_CLK (), .D_OUT_1 (), .D_IN_1 () 
);
defparam DQ07.PIN_TYPE = 6'b101001; // non-latched bi-directional I/O buffer
defparam DQ07.PULLUP = 1'b0;
defparam DQ07.NEG_TRIGGER = 1'b0;
//defparam DQ07.IO_STANDARD = "LVCMOS";

SB_IO DQ08
(
.PACKAGE_PIN (SDRAM_DQ[8]),
.OUTPUT_ENABLE (SDRAM_DQ_enable),
.D_OUT_0 (SDRAM_DQ_output[8]),
.D_IN_0 (SDRAM_DQ_in[8]),
// n.c. pins we don't use
.LATCH_INPUT_VALUE (), .CLOCK_ENABLE (), .INPUT_CLK (), .OUTPUT_CLK (), .D_OUT_1 (), .D_IN_1 () 
);
defparam DQ08.PIN_TYPE = 6'b101001; // non-latched bi-directional I/O buffer
defparam DQ08.PULLUP = 1'b0;
defparam DQ08.NEG_TRIGGER = 1'b0;
//defparam DQ08.IO_STANDARD = "LVCMOS";

SB_IO DQ09
(
.PACKAGE_PIN (SDRAM_DQ[9]),
.OUTPUT_ENABLE (SDRAM_DQ_enable),
.D_OUT_0 (SDRAM_DQ_output[9]),
.D_IN_0 (SDRAM_DQ_in[9]),
// n.c. pins we don't use
.LATCH_INPUT_VALUE (), .CLOCK_ENABLE (), .INPUT_CLK (), .OUTPUT_CLK (), .D_OUT_1 (), .D_IN_1 () 
);
defparam DQ09.PIN_TYPE = 6'b101001; // non-latched bi-directional I/O buffer
defparam DQ09.PULLUP = 1'b0;
defparam DQ09.NEG_TRIGGER = 1'b0;
//defparam DQ09.IO_STANDARD = "LVCMOS";

SB_IO DQ10
(
.PACKAGE_PIN (SDRAM_DQ[10]),
.OUTPUT_ENABLE (SDRAM_DQ_enable),
.D_OUT_0 (SDRAM_DQ_output[10]),
.D_IN_0 (SDRAM_DQ_in[10]),
// n.c. pins we don't use
.LATCH_INPUT_VALUE (), .CLOCK_ENABLE (), .INPUT_CLK (), .OUTPUT_CLK (), .D_OUT_1 (), .D_IN_1 () 
);
defparam DQ10.PIN_TYPE = 6'b101001; // non-latched bi-directional I/O buffer
defparam DQ10.PULLUP = 1'b0;
defparam DQ10.NEG_TRIGGER = 1'b0;
//defparam DQ10.IO_STANDARD = "LVCMOS";

SB_IO DQ11
(
.PACKAGE_PIN (SDRAM_DQ[11]),
.OUTPUT_ENABLE (SDRAM_DQ_enable),
.D_OUT_0 (SDRAM_DQ_output[11]),
.D_IN_0 (SDRAM_DQ_in[11]),
// n.c. pins we don't use
.LATCH_INPUT_VALUE (), .CLOCK_ENABLE (), .INPUT_CLK (), .OUTPUT_CLK (), .D_OUT_1 (), .D_IN_1 () 
);
defparam DQ11.PIN_TYPE = 6'b101001; // non-latched bi-directional I/O buffer
defparam DQ11.PULLUP = 1'b0;
defparam DQ11.NEG_TRIGGER = 1'b0;
//defparam DQ11.IO_STANDARD = "LVCMOS";

SB_IO DQ12
(
.PACKAGE_PIN (SDRAM_DQ[12]),
.OUTPUT_ENABLE (SDRAM_DQ_enable),
.D_OUT_0 (SDRAM_DQ_output[12]),
.D_IN_0 (SDRAM_DQ_in[12]),
// n.c. pins we don't use
.LATCH_INPUT_VALUE (), .CLOCK_ENABLE (), .INPUT_CLK (), .OUTPUT_CLK (), .D_OUT_1 (), .D_IN_1 () 
);
defparam DQ12.PIN_TYPE = 6'b101001; // non-latched bi-directional I/O buffer
defparam DQ12.PULLUP = 1'b0;
defparam DQ12.NEG_TRIGGER = 1'b0;
//defparam DQ12.IO_STANDARD = "LVCMOS";

SB_IO DQ13
(
.PACKAGE_PIN (SDRAM_DQ[13]),
.OUTPUT_ENABLE (SDRAM_DQ_enable),
.D_OUT_0 (SDRAM_DQ_output[13]),
.D_IN_0 (SDRAM_DQ_in[13]),
// n.c. pins we don't use
.LATCH_INPUT_VALUE (), .CLOCK_ENABLE (), .INPUT_CLK (), .OUTPUT_CLK (), .D_OUT_1 (), .D_IN_1 () 
);
defparam DQ13.PIN_TYPE = 6'b101001; // non-latched bi-directional I/O buffer
defparam DQ13.PULLUP = 1'b0;
defparam DQ13.NEG_TRIGGER = 1'b0;
//defparam DQ13.IO_STANDARD = "LVCMOS";

SB_IO DQ14
(
.PACKAGE_PIN (SDRAM_DQ[14]),
.OUTPUT_ENABLE (SDRAM_DQ_enable),
.D_OUT_0 (SDRAM_DQ_output[14]),
.D_IN_0 (SDRAM_DQ_in[14]),
// n.c. pins we don't use
.LATCH_INPUT_VALUE (), .CLOCK_ENABLE (), .INPUT_CLK (), .OUTPUT_CLK (), .D_OUT_1 (), .D_IN_1 () 
);
defparam DQ14.PIN_TYPE = 6'b101001; // non-latched bi-directional I/O buffer
defparam DQ14.PULLUP = 1'b0;
defparam DQ14.NEG_TRIGGER = 1'b0;
//defparam DQ14.IO_STANDARD = "LVCMOS";

SB_IO DQ15
(
.PACKAGE_PIN (SDRAM_DQ[15]),
.OUTPUT_ENABLE (SDRAM_DQ_enable),
.D_OUT_0 (SDRAM_DQ_output[15]),
.D_IN_0 (SDRAM_DQ_in[15]),
// n.c. pins we don't use
.LATCH_INPUT_VALUE (), .CLOCK_ENABLE (), .INPUT_CLK (), .OUTPUT_CLK (), .D_OUT_1 (), .D_IN_1 () 
);
defparam DQ15.PIN_TYPE = 6'b101001; // non-latched bi-directional I/O buffer
defparam DQ15.PULLUP = 1'b0;
defparam DQ15.NEG_TRIGGER = 1'b0;
//defparam DQ15.IO_STANDARD = "LVCMOS";


//================================= MODULES =====================================

// ======== Module ======== clock_and_reset =====
clock_and_reset i_clock_and_reset (
    // Inputs
    .clock (clock),
    .pin_reset_n (pin_reset_n),

    // Outputs
    .reset (reset)
);

// ======== Module ======== bus_disk_read =====
bus_disk_read i_bus_disk_read (
    // Inputs
    .clock (clock),
    .reset (reset),
    .BUS_RD_GATE_L (BUS_RD_GATE_L),
    .clkenbl_read_bit (clkenbl_read_bit),
    .clkenbl_read_data (clkenbl_read_data),
    .clock_pulse (clock_pulse),
    .data_pulse (data_pulse),
    .dram_readdata (dram_readdata),
    .Selected_Ready (Selected_Ready),
    .BUS_SECTOR_CTRL_L (BUS_SECTOR_CTRL_L),
    .clkenbl_sector (clkenbl_sector),

    // Outputs
    .dram_read_enbl_busread (dram_read_enbl_busread),
    .BUS_RD_DATA_H (BUS_RD_DATA_H),
    .BUS_RD_CLK_H (BUS_RD_CLK_H),
    .load_address_busread (load_address_busread),
    .read_indicator (read_indicator),
    .read_selected_ready (read_selected_ready)
);

// ======== Module ======== bus_disk_write =====
bus_disk_write i_bus_disk_write (
    // Inputs
    .clock (clock),
    .reset (reset),
    .BUS_WT_GATE_L (BUS_WT_GATE_L),
    .BUS_WT_DATA_CLK_CTRL_L (BUS_WT_DATA_CLK_CTRL_L),
    .BUS_WT_CLOCKB_L (BUS_WT_CLOCKB_L),
    .Selected_Ready (Selected_Ready),
    .BUS_SECTOR_CTRL_L (BUS_SECTOR_CTRL_L),
    .clkenbl_sector (clkenbl_sector),
    .real_drive (real_drive),
    .dram_writeack (dram_writeack),

    // Outputs
    .dram_write_enbl_buswrite (dram_write_enbl_buswrite),
    .dram_writedata_buswrite (dram_writedata_buswrite),
    .load_address_buswrite (load_address_buswrite),
    .dram_addr_incr_buswrite (dram_addr_incr_buswrite),
    .write_indicator (write_indicator),
    .write_selected_ready (write_selected_ready),
    .ECC_error (ECC_error),
    .BUS_WT_CLOCKB_EMUL_L (BUS_WT_CLOCKB_EMUL_L)
);

// ======== Module ======== bus_outputs =====
bus_outputs i_bus_outputs (
    // Inputs
    .Selected (Selected),
    .Cart_Ready (Cart_Ready),
    .Fault_Latch (Fault_Latch),
    .real_drive (real_drive),
    .BUS_FILE_READY_DRIVE_L (BUS_FILE_READY_DRIVE_L),
    .BUS_ACCESS_RDY_DRIVE_H (BUS_ACCESS_RDY_DRIVE_H),
    .BUS_HOME_DRIVE_L (BUS_HOME_DRIVE_L),
    .BUS_WT_CLOCKB_DRIVE_L (BUS_WT_CLOCKB_DRIVE_L),
    .BUS_SECTOR_DRIVE_L (BUS_SECTOR_DRIVE_L),
    .BUS_INDEX_DRIVE_L (BUS_INDEX_DRIVE_L),
    .BUS_WRITE_SEL_ERR_DRIVE_L (BUS_WRITE_SEL_ERR_DRIVE_L),
    .BUS_90S_RELAY_DRIVE_L (BUS_90S_RELAY_DRIVE_L),
    .BUS_10_20_CTRL_L (BUS_10_20_CTRL_L),
    .BUS_ACC_GO_DRIVE_CTRL_L (BUS_ACC_GO_DRIVE_CTRL_L),
    .BUS_ACC_REV_CTRL_L (BUS_ACC_REV_CTRL_L),
    .BUS_HEAD_SELECT_CTRL_L (BUS_HEAD_SELECT_CTRL_L),
    .BUS_RD_GATE_CTRL_L (BUS_RD_GATE_CTRL_L),
    .BUS_WT_GATE_CTRL_L (BUS_WT_GATE_CTRL_L),
    .BUS_WT_DATA_CLK_CTRL_L (BUS_WT_DATA_CLK_CTRL_L),
    .BUS_ACCESS_RDY_EMUL_H (BUS_ACCESS_RDY_EMUL_H),
    .BUS_HOME_DRIVE_EMUL_L (BUS_HOME_DRIVE_EMUL_L),
    .BUS_WT_CLOCKB_EMUL_L (BUS_WT_CLOCKB_EMUL_L),
    .BUS_SECTOR_EMUL_H (BUS_SECTOR_EMUL_H),
    .BUS_INDEX_EMUL_H (BUS_INDEX_EMUL_H),
    .BUS_90SEC_RELAY_EMUL_L (BUS_90SEC_RELAY_EMUL_L),
    .BUS_RD_DATA_H (BUS_RD_DATA_H),
    .BUS_RD_CLK_H (BUS_RD_CLK_H),

    // Outputs
    .BUS_10_20_DRIVE_L (BUS_10_20_DRIVE_L),
    .BUS_ACC_GO_DRIVE_DRIVE_L (BUS_ACC_GO_DRIVE_DRIVE_L),
    .BUS_ACC_REV_DRIVE_L (BUS_ACC_REV_DRIVE_L),
    .BUS_HEAD_SELECT_DRIVE_L (BUS_HEAD_SELECT_DRIVE_L),
    .BUS_RD_GATE_DRIVE_L (BUS_RD_GATE_DRIVE_L),
    .BUS_WT_GATE_DRIVE_L (BUS_WT_GATE_DRIVE_L),
    .BUS_WT_DATA_CLK_DRIVE_L (BUS_WT_DATA_CLK_DRIVE_L),
    .BUS_ACCESS_RDY_CTRL_H (BUS_ACCESS_RDY_CTRL_H),
    .BUS_HOME_CTRL_L (BUS_HOME_CTRL_L),
    .BUS_WT_CLOCKB_CTRL_L (BUS_WT_CLOCKB_CTRL_L),
    .BUS_RD_DATA_CTRL_L (BUS_RD_DATA_CTRL_L),
    .BUS_RD_CLK_CTRL_L (BUS_RD_CLK_CTRL_L),
    .BUS_FILE_READY_CTRL_L (BUS_FILE_READY_CTRL_L),
    .BUS_SECTOR_CTRL_L (BUS_SECTOR_CTRL_L),
    .BUS_INDEX_CTRL_L (BUS_INDEX_CTRL_L),
    .BUS_WRITE_SEL_ERR_CTRL_L (BUS_WRITE_SEL_ERR_CTRL_L),
    .BUS_90S_RELAY_CTRL_L (BUS_90S_RELAY_CTRL_L),
    .BUS_WT_CLOCKB_L (BUS_WT_CLOCKB_L),
    .BUS_ACC_GO_L (BUS_ACC_GO_L),
    .BUS_ACC_REV_L (BUS_ACC_REV_L),
    .BUS_10_20_L (BUS_10_20_L),
    .BUS_SECTOR_L (BUS_SECTOR_L),
    .BUS_INDEX_L (BUS_INDEX_L),
    .BUS_WT_GATE_L (BUS_WT_GATE_L),
    .BUS_RD_GATE_L (BUS_RD_GATE_L),
    .BUS_HEAD_SELECT_L (BUS_HEAD_SELECT_L),
    .Selected_Ready (Selected_Ready)
);

// ======== Module ======== drive_select =====
drive_select i_drive_select (
    // Inputs
    .clock (clock),
    .reset (reset),
    .Cart_Ready (Cart_Ready),
    .BUS_UNLOCKED_DRIVE_H (BUS_UNLOCKED_DRIVE_H),
    .real_drive (real_drive),
    .clkenbl_1usec (clkenbl_1usec),

    // Outputs
    .BUS_90SEC_RELAY_EMUL_L (BUS_90SEC_RELAY_EMUL_L),
    .BUS_UNLOCKED_EMUL_L (BUS_UNLOCKED_EMUL_L),
    .Selected (Selected)
);

// ======== Module ======== sdram_controller =====
 sdram_controller i_sdram_controller ( 
    // Inputs
    .clock (clock),
    .reset (reset),
    .load_address_spi (load_address_spi),
    .load_address_busread (load_address_busread),
    .load_address_buswrite (load_address_buswrite),
    .dram_read_enbl_spi (dram_read_enbl_spi),
    .dram_read_enbl_busread (dram_read_enbl_busread),
    .dram_write_enbl_spi (dram_write_enbl_spi),
    .dram_write_enbl_buswrite (dram_write_enbl_buswrite),
    .dram_addr_incr_buswrite (dram_addr_incr_buswrite),
    .dram_writedata_spi (dram_writedata_spi),
    .dram_writedata_buswrite (dram_writedata_buswrite),
    .spi_serpar_reg (spi_serpar_reg),
    .Sector_Address (Sector_Address),
    .Cylinder_Address (Cylinder_Address),
    .Head_Select (Head_Select),

    .SDRAM_DQ_in (SDRAM_DQ_in),

    // Outputs
    .dram_readdata (dram_readdata),

    .dram_writeack (dram_writeack),

    .SDRAM_DQ_output (SDRAM_DQ_output),
    .SDRAM_DQ_enable (SDRAM_DQ_enable),
    .SDRAM_Address (SDRAM_Address),
    .SDRAM_BS0 (SDRAM_BS0),
    .SDRAM_BS1 (SDRAM_BS1),
    .SDRAM_WE_n (SDRAM_WE_n),
    .SDRAM_CAS_n (SDRAM_CAS_n),
    .SDRAM_RAS_n (SDRAM_RAS_n),
    .SDRAM_CS_n (SDRAM_CS_n),
    .SDRAM_CLK (SDRAM_CLK),
    .SDRAM_CKE (SDRAM_CKE),
    .SDRAM_DQML (SDRAM_DQML),
    .SDRAM_DQMH (SDRAM_DQMH)
);


// ======== Module ======== sector_and_index =====
sector_and_index i_sector_and_index (
    // Inputs
    .clock (clock),
    .reset (reset),
    .clkenbl_1usec (clkenbl_1usec),
    .real_drive (real_drive),
    .BUS_SECTOR_L (BUS_SECTOR_L),
    .BUS_INDEX_L (BUS_INDEX_L),

    // Outputs
    .clkenbl_sector (clkenbl_sector),
    .BUS_SECTOR_EMUL_H (BUS_SECTOR_EMUL_H),
    .BUS_INDEX_EMUL_H (BUS_INDEX_EMUL_H),
    .Sector_Address (Sector_Address)
);

// ======== Module ======== seek_to_cylinder =====
seek_to_cylinder i_seek_to_cylinder (
    // Inputs
    .clock (clock),
    .reset (reset),
    .Selected_Ready (Selected_Ready),
    .BUS_ACC_GO_L (BUS_ACC_GO_L),
    .BUS_ACC_REV_L (BUS_ACC_REV_L),
    .BUS_10_20_L (BUS_10_20_L),
    .clkenbl_1usec (clkenbl_1usec),
    .clkenbl_sector (clkenbl_sector),

    // Outputs
    .Cylinder_Address (Cylinder_Address),
    .BUS_ACCESS_RDY_EMUL_H (BUS_ACCESS_RDY_EMUL_H),
    .BUS_HOME_DRIVE_EMUL_L (BUS_HOME_DRIVE_EMUL_L),
    .oncylinder_indicator (oncylinder_indicator),
    .strobe_selected_ready (strobe_selected_ready)
);

// ======== Module ======== spi_interface =====
spi_interface i_spi_interface (
    // Inputs
    .clock (clock),
    .reset (reset),
    .spi_clk (CPU_SPI_CLK),
    .spi_cs_n (CPU_SPI_CS_n),
    .spi_mosi (CPU_SPI_MOSI),
    .dram_readdata (dram_readdata),
    .Cylinder_Address (Cylinder_Address),
    .Head_Select (Head_Select),
    .Selected_Ready (Selected_Ready),
    .BUS_UNLOCKED_EMUL_L (BUS_UNLOCKED_EMUL_L),
    .BUS_FILE_READY_CTRL_L (BUS_FILE_READY_CTRL_L),
    .BUS_WRITE_SEL_ERR_DRIVE_L (BUS_WRITE_SEL_ERR_DRIVE_L),
    .major_version (MAJOR_VERSION),
    .minor_version (MINOR_VERSION),
    .Sector_Address (Sector_Address),
    .strobe_selected_ready (strobe_selected_ready),
    .read_selected_ready (read_selected_ready),
    .write_selected_ready (write_selected_ready),
    .ECC_error (ECC_error),
    .real_drive (real_drive),

    // Outputs
    .spi_miso (CPU_SPI_MISO),
    .load_address_spi (load_address_spi),
    .spi_serpar_reg (spi_serpar_reg),
    .dram_read_enbl_spi (dram_read_enbl_spi),
    .dram_write_enbl_spi (dram_write_enbl_spi),
    .dram_writedata_spi (dram_writedata_spi),
    .Cart_Ready (Cart_Ready),
    .Read_Only (Read_Only),
    .Fault_Latch (Fault_Latch),
    .interface_test_mode (interface_test_mode),
    .command_interrupt (CMD_INTERRUPT),
    .Servo_Pulse_FPGA (Servo_Pulse_FPGA)
);

// ======== Module ======== timing_gen =====
timing_gen i_timing_gen (
    // Inputs
    .clock (clock),
    .reset (reset),

    // Outputs
    .clkenbl_read_bit (clkenbl_read_bit),
    .clkenbl_read_data (clkenbl_read_data),
    .clock_pulse (clock_pulse),
    .data_pulse (data_pulse),
    .clkenbl_1usec (clkenbl_1usec)
);

endmodule // V2315CF
