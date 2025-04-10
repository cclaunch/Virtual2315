//==========================================================================================================
// RK05 Emulator
// Bus Outputs Logic
// File Name: bus_outputs.v
// Functions: 
//   Translate internal signals to the polarity of the 2310 outputs.
//   Output polarity is switchable so any open collector chip can be used
//   Gate all outputs with the internal Selected and Ready signal.
//
// Modified by Carl V Claunch to emulate the IBM 2310
//
//==========================================================================================================

module bus_outputs (
    input wire Selected,                  // active high signal indicates that the drive is selected
    input wire Fault_Latch,               // included for future support. Software will always write zero to Fault_Latch.
    input wire Cart_Ready,                // PICO says we are ready to do input output operations
    input wire BUS_ACCESS_RDY_DRIVE_H,    // Seek ready and on-cylinder
    input wire BUS_HOME_DRIVE_L,          // indicates at track zero
    input wire BUS_WT_CLOCKB_DRIVE_L,     // 720 KHz clock to control writes
    input wire BUS_SECTOR_DRIVE_L,        // 160 us negative pulse each time a sector slot passes the transducer
    input wire BUS_INDEX_DRIVE_L,         // 160 us negative pulse for each revolution of the disk, 600 μs after the sector pulse
    input wire BUS_WRITE_SEL_ERR_DRIVE_L, // error when attempting write
    input wire BUS_90S_RELAY_DRIVE_L,     // 90 second relay while drive purges
    input wire BUS_10_20_CTRL_L,          // seek step size, one or two tracks
    input wire BUS_ACC_GO_DRIVE_CTRL_L,   // Strobe to enable movement
    input wire BUS_ACC_REV_CTRL_L,        // direction of seek, forward or reverse
    input wire BUS_HEAD_SELECT_CTRL_L,    // Head Select
    input wire BUS_RD_GATE_CTRL_L,        // Read gate, when active enables read circuitry
    input wire BUS_WT_GATE_CTRL_L,        // Write gate, when active enables write circuitry
    input wire BUS_WT_DATA_CLK_CTRL_L,    // Composite write data and write clock
    input wire BUS_ACCESS_RDY_EMUL_H,     // indicates at track zero
    input wire BUS_HOME_DRIVE_EMUL_L,     // indicates at track zero
    input wire BUS_WT_CLOCKB_EMUL_L,      // 720 KHz clock to control writes
    input wire BUS_SECTOR_EMUL_H,         // 165 us positive pulse each time a sector slot passes the transducer
    input wire BUS_INDEX_EMUL_H,          // 165 us positive pulse for each revolution of the disk, 600 μs after the sector pulse
    input wire BUS_90SEC_RELAY_EMUL_L,    // 90 second relay while drive purges
    input wire BUS_RD_DATA_H,             // output of read module
    input wire BUS_RD_CLK_H,              // output of read module
    input wire BUS_FILE_READY_DRIVE_L,    // real drive is ready, heads loaded
    input wire real_drive,                // do we have physical drive in hybrid mode or all virtual
    output wire BUS_10_20_DRIVE_L,        // seek step size, one or two tracks
    output wire BUS_ACC_GO_DRIVE_DRIVE_L, // Strobe to enable movement
    output wire BUS_ACC_REV_DRIVE_L,      // direction of seek, forward or reverse
    output wire BUS_HEAD_SELECT_DRIVE_L,  // Head Select
    output wire BUS_RD_GATE_DRIVE_L,      // Read gate, when active enables read circuitry
    output wire BUS_WT_GATE_DRIVE_L,      // Write gate, when active enables write circuitry
    output wire BUS_WT_DATA_CLK_DRIVE_L,  // Composite write data and write clock
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
    output wire BUS_WT_CLOCKB_L,          // clock to send for disk_write module
    output wire BUS_ACC_GO_L,             // Strobe to enable movement for seek module
    output wire BUS_ACC_REV_L,            // signal to enable movement for seek module
    output wire BUS_10_20_L,              // signal to enable movement for seek module
    output wire BUS_SECTOR_L,             // Sector pulse for sector module
    output wire BUS_INDEX_L,              // Sector pulse for sector module
    output wire BUS_WT_GATE_L,            // signal for write module
    output wire BUS_RD_GATE_L,            // signal for read module
    output wire BUS_HEAD_SELECT_L,        // signal for seek module
    output wire Selected_Ready            // disk contents have been copied from the microSD to the SDRAM & drive selected & ~fault latch
);

//============================ Start of Code =========================================

// we are always selected. need cartridge loaded from SD card, 1130 controller indicating File Ready and no fault
assign Selected_Ready =           real_drive == 1'b1
                                                ? 1'b1
                                                : Selected & Cart_Ready & ~Fault_Latch;


// Signals that don't depend on real_drive status
assign BUS_10_20_DRIVE_L =                      (BUS_10_20_CTRL_L | ~Selected_Ready);
assign BUS_ACC_GO_DRIVE_DRIVE_L =               (BUS_ACC_GO_DRIVE_CTRL_L | ~Selected_Ready);
assign BUS_ACC_REV_DRIVE_L =                    (BUS_ACC_REV_CTRL_L | ~Selected_Ready);
assign BUS_HEAD_SELECT_DRIVE_L =                (BUS_HEAD_SELECT_CTRL_L | ~Selected_Ready);
assign BUS_RD_GATE_DRIVE_L =                    (BUS_RD_GATE_CTRL_L | ~Selected_Ready);
assign BUS_WT_GATE_DRIVE_L =                    (BUS_WT_GATE_CTRL_L | ~Selected_Ready);
assign BUS_WT_DATA_CLK_DRIVE_L =                (BUS_WT_DATA_CLK_CTRL_L | ~Selected_Ready);
assign BUS_RD_DATA_CTRL_L =                     (~BUS_RD_DATA_H | ~Selected_Ready);
assign BUS_RD_CLK_CTRL_L =                      (~BUS_RD_CLK_H | ~Selected_Ready);
assign BUS_ACC_GO_L  =                          (BUS_ACC_GO_DRIVE_CTRL_L | ~Selected_Ready);
assign BUS_ACC_REV_L =                          (BUS_ACC_REV_CTRL_L | ~Selected_Ready);
assign BUS_10_20_L =                            (BUS_10_20_CTRL_L | ~Selected_Ready);
assign BUS_SECTOR_L =                           (BUS_SECTOR_DRIVE_L | ~Selected_Ready);
assign BUS_INDEX_L =                            (BUS_INDEX_DRIVE_L | ~Selected_Ready);
assign BUS_WT_GATE_L =                          (BUS_WT_GATE_CTRL_L | ~Selected_Ready);
assign BUS_RD_GATE_L =                          (BUS_RD_GATE_CTRL_L | ~Selected_Ready);
assign BUS_HEAD_SELECT_L =                      (BUS_HEAD_SELECT_CTRL_L | ~Selected_Ready);

// Signals that depend on real_drive status
assign BUS_ACCESS_RDY_CTRL_H =       real_drive == 1'b1
                                                ? (BUS_ACCESS_RDY_DRIVE_H & Selected_Ready)
                                                : (BUS_ACCESS_RDY_EMUL_H & Cart_Ready);
assign BUS_HOME_CTRL_L =             real_drive == 1'b1
                                                ? (BUS_HOME_DRIVE_L | ~Selected_Ready)
                                                : (BUS_HOME_DRIVE_EMUL_L | ~Cart_Ready);
assign BUS_SECTOR_CTRL_L =           real_drive == 1'b1
                                                ? BUS_SECTOR_DRIVE_L & Selected_Ready
                                                : ~(BUS_SECTOR_EMUL_H | ~Cart_Ready);
assign BUS_INDEX_CTRL_L =            real_drive == 1'b1
                                                ? BUS_INDEX_DRIVE_L & Selected_Ready
                                                : ~(BUS_INDEX_EMUL_H | ~Cart_Ready);
assign BUS_WRITE_SEL_ERR_CTRL_L =    real_drive == 1'b1
                                                ? (BUS_WRITE_SEL_ERR_DRIVE_L | ~Selected_Ready)
                                                : 1'b1;
assign BUS_90S_RELAY_CTRL_L =        real_drive == 1'b1
                                                ? (BUS_90S_RELAY_DRIVE_L) & Selected_Ready
                                                : (BUS_90SEC_RELAY_EMUL_L | ~Cart_Ready);
assign BUS_WT_CLOCKB_L =             real_drive == 1'b1
                                                ? (BUS_WT_CLOCKB_DRIVE_L | ~Selected_Ready)
                                                : (BUS_WT_CLOCKB_EMUL_L | ~Cart_Ready);

assign BUS_WT_CLOCKB_CTRL_L =        real_drive == 1'b1
                                                ? (BUS_WT_CLOCKB_DRIVE_L | ~Selected_Ready)
                                                : (BUS_WT_CLOCKB_EMUL_L | ~Cart_Ready);

assign BUS_FILE_READY_CTRL_L =       real_drive == 1'b1
                                                ? (BUS_FILE_READY_DRIVE_L | ~Cart_Ready)        
                                                : (~Cart_Ready | ~Selected);

endmodule // End of Module bus_outputs
