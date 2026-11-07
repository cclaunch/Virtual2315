//==========================================================================================================
// RK05 Emulator
// Processor SPI Interface
// File Name: spi_interface.v
// Functions: 
//   read and write FPGA hardware control registers.
//   read and write SDRAM data.
//   write SDRAM address register for processor SDRAM accesses.
// Modified for 2310 by Carl Claunch
//
//==========================================================================================================

module spi_interface(
    input wire clock,                    // master clock 40 MHz
    input wire reset,                    // active high synchronous reset input
    input wire spi_clk,                  // SPI clock
    input wire spi_cs_n,                 // SPI active low chip select
    input wire spi_mosi,                 // SPI controller data output, peripheral data input
    input wire [15:0] dram_readdata,     // 16-bit read data from DRAM controller
    input wire [7:0] Cylinder_Address,   // input to be able to read the Cylinder Address
    input wire Head_Select,              // input to be able to read the Head Select bit
    input wire Selected_Ready,           // input to be able to read Selected_Ready
    input wire [7:0] major_version,
    input wire [7:0] minor_version,
    input wire [1:0] Sector_Address,     // Sector Address to be read test visibility mode
    input wire strobe_selected_ready,
    input wire read_selected_ready,
    input wire write_selected_ready,
    input wire BUS_UNLOCKED_EMUL_L,      // driven by drive_select.v
    input wire BUS_FILE_READY_CTRL_L,    // we say the drive is ready for input output operations
    input wire BUS_WRITE_SEL_ERR_DRIVE_L,// got error trying to select/write on drive
    input wire ECC_error,                // got error in four ECC bits during write
    input wire real_drive,               // hybrid or pure virtual mode
    output reg spi_miso,                 // SPI controller data input, peripheral data output
    output reg load_address_spi,         // enable from SPI to command the sdram controller to load address 8 bits at a time
    output reg [7:0] spi_serpar_reg,     // 8-bit serpar register used for writing to the sdram address register
    output reg dram_read_enbl_spi,       // read enable request to DRAM controller
    output reg dram_write_enbl_spi,      // write enable request to DRAM controller
    output reg [15:0] dram_writedata_spi,// 16-bit write data to DRAM controller
    output reg Cart_Ready,               // disk contents have been copied from the microSD to the SDRAM.
    output reg Read_Only,                // CPU register that indicates no writeback of updates to cartridge at shutdown
    output reg Fault_Latch,              // combines faults detected in Pico handling uSD files plus drive fault
    output reg interface_test_mode,
    output reg command_interrupt,
    output reg Servo_Pulse_FPGA
);

//============================ Internal Connections ==================================

//`define EMULATOR_FPGA_CODE_VERSION  8'h51  // hex number that indicates the version of the FPGA code

reg [7:0] spiserialreg;
reg [3:0] metaspi;
reg dramwrite_lowhigh;
reg dramread_lowhigh;
reg [4:0] spicount; // define as 5 bits instead of 4 to prevent the first bit from wrapping around at the end of transmitting the 16-bit data (8 addr + 8 data)
reg [7:0] serialaddress;
wire [7:0] muxed_read_data;
wire pre_spi_miso;
reg frdlyd;
reg toggle_wp;
reg [1:0] operation_id;
reg Disk_Fault;

wire spi_start;

//============================ Start of Code =========================================

// SB_DFFS - D Flip-Flop, Set is asynchronous to the clock.
SB_DFFS SPI_DFFS_inst (
.Q(spi_start), // Registered Output, "Q" output of the DFF
.C(~spi_clk),  // rising-edge Clock, so with ~spi_clk as the input, Q changes on the falling edge of spi_clk
.D(1'b0),      // Data, clocks in a zero on the falling edge of spi_clk
.S(spi_cs_n)   // Asynchronous active-high Set, we perform async set of the DFF while spi_cs_n is inactive
);


// produce inputs to registers we will write up to the Pico when it does a read of these reg address
// these readback have diff # assigned to them, thus reading 00 is done with reg address A0
// others just read out internal state, eg. 81 grabs current cylinder address
assign muxed_read_data = (serialaddress == 8'h80) ? 8'h00 : 
                          ((serialaddress == 8'h81) ? Cylinder_Address[7:0] :
                           ((serialaddress == 8'h82) ? {2'b0, Sector_Address[1:0], operation_id[1:0], 
                                                        Selected_Ready, Head_Select} :
                            ((serialaddress == 8'h83) ? {8'h00} :
                             ((serialaddress == 8'h90) ? major_version[7:0] :
                              ((serialaddress == 8'h91) ? minor_version[7:0] :
                               // A0 reads back status similar to what is sent by 00
                                   // x80 is Read_Only
                                   // x40 is File Ready set by FPGA and lamp lit by Pico
                                   // x20 is Fault_Latch set by FPGA and lamp lit by Pico
                                   // x10 is Cart Ready set in FPGA by Pico and lamp lit by Pico
                                   // x08 is Unlocked drive set in FPGA and lamp controlled by Pico
                                   // x04 and x02 were 2 of the 3 bit drive select value from Pico, now 00
                                   // x01 is real drive mode, 1 means hybrid using physical drive
                               ((serialaddress == 8'ha0) ? {Read_Only, ~BUS_FILE_READY_CTRL_L, 
                                                            Disk_Fault, Cart_Ready, ~BUS_UNLOCKED_EMUL_L, 2'd0, real_drive} : 
                                // 88 reads a byte of one word from SDRAM, two calls gives us one word from SDRAM
                                // dram_readdata[15:0] always has the data ready that was read at the dram_address.
                                // The DRAM word read function is triggered after the odd byte is read.
                                // The next word is requested after reading the high byte from register 0x88.
                                ((serialaddress == 8'h88) 
                                  ? (dramread_lowhigh 
                                    ? dram_readdata[15:8] 
                                    : dram_readdata[7:0])
                                  : 8'b0
                                )))))));

assign pre_spi_miso = ((spicount == 5'd7) & muxed_read_data[7]) | 
                      ((spicount == 5'd8) & muxed_read_data[6]) |
                      ((spicount == 5'd9) & muxed_read_data[5]) |
                      ((spicount == 5'd10) & muxed_read_data[4]) |
                      ((spicount == 5'd11) & muxed_read_data[3]) |
                      ((spicount == 5'd12) & muxed_read_data[2]) |
                      ((spicount == 5'd13) & muxed_read_data[1]) |
                      ((spicount == 5'd14) & muxed_read_data[0]);

always @ (posedge spi_clk)
begin : SPICLKPOSFUNCTIONS // block name
  // Reset the SPI bit counter using the DFF that is set when spi_cs_n is inactive
  // The SPI bit counter is used by a mux to serialize the SPI read data.
  spicount <= spi_start ? 5'd0 : spicount + 1;
  serialaddress <= (spicount == 6) ? {spiserialreg[6:0], spi_mosi} : serialaddress;

  if(spi_cs_n == 1'b0) begin
    spiserialreg[7:0] <= {spiserialreg[6:0], spi_mosi};
  end
  else begin
    spiserialreg[7:0] <= 8'hff;
  end
end

always @ (negedge spi_clk)
begin : SPICLKNEGFUNCTIONS // block name
  spi_miso <= pre_spi_miso;
end

always @ (posedge spi_cs_n)
begin : SPICSPOSFUNCTIONS // block name
    spi_serpar_reg <=  spiserialreg;
end

always @ (posedge clock)
begin : HSCLOCKFUNCTIONS // block name
  if(reset == 1'b1) begin
    dram_read_enbl_spi <= 1'b0;
    dram_write_enbl_spi <= 1'b0;
    Cart_Ready <= 1'b0;
    frdlyd <= 1'b0;
    Read_Only <= 1'b0;
    Fault_Latch <= 1'b0;
    load_address_spi <= 1'b0;
    dramwrite_lowhigh <= 1'b0;
    dramread_lowhigh <= 1'b0;
    dram_writedata_spi <= 16'd0;
    metaspi <= 4'b0000;
    toggle_wp <= 1'b0;
    interface_test_mode <= 1'b0;
    operation_id <= 2'b00;
    command_interrupt <= 1'b0;
    Servo_Pulse_FPGA <= 1'b0;
    Disk_Fault = 1'b0;
  end
  else begin

    Disk_Fault = real_drive == 1'b1
                    ? ~BUS_WRITE_SEL_ERR_DRIVE_L | ECC_error  // actual fault from drive or bad ECC bits on write
                    : ECC_error;                              // bad ECC bits on writeServo_Pulse_FPGA <= 1'b0;
    
    command_interrupt <= strobe_selected_ready || read_selected_ready || write_selected_ready;

    operation_id <= strobe_selected_ready 
                  ? 2'h0 
                  : (read_selected_ready 
                         ? 2'h1 
                         : (write_selected_ready 
                                 ? 2'h2 
                                 : operation_id));

    frdlyd <= Cart_Ready;

    metaspi[3:0] <= {metaspi[2:0], ~spi_cs_n};

    Fault_Latch <= BUS_FILE_READY_CTRL_L == 1'b1
                   ? 1'b0
                   : Disk_Fault == 1'b1
                     ? 1'b1
                     : Fault_Latch;

  //
  // below for register x04 which records the read only condition, controlling the LED
  //
    //toggle_wp is separated only so the code is more readable
    toggle_wp <= (serialaddress == 8'h04) && ~metaspi[2] && metaspi[3] && spi_serpar_reg[0] 
                 ? 1'b1
                 : 1'b0;

    // Q <= (Q | Set) & ~Reset
    // Set when (toggle_wp & ~Q)
    // Reset when (toggle_wp & Q)
    Read_Only <= (Read_Only | ((toggle_wp & ~Read_Only))) & ~((toggle_wp & Read_Only));
 
  //
  // register address 0x00 when written by the Pico
  //
    // x10 is Cart Ready set/clear by Pico
    Cart_Ready <=        ((serialaddress == 8'h00) && ~metaspi[2] && metaspi[3]) 
                 ? spi_serpar_reg[4]   
                 : Cart_Ready; 

  //
  // register address 0x05 written by Pico
  //
    // x05 sets memory address via three sequential messages
    load_address_spi   <= (serialaddress == 8'h05) & ~metaspi[2] & metaspi[3]; // command to load 8 bits of address from SPI

  //
  // register address 0x06 written by Pico
  //
    // register address 0x06 written by Pico sends data word via pair of sequential messages
    dram_writedata_spi[7:0] <=  ((serialaddress == 8'h06) && ~metaspi[2] && metaspi[3]) 
                             ? dram_writedata_spi[15:8] 
                             : dram_writedata_spi[7:0];
    dram_writedata_spi[15:8] <= ((serialaddress == 8'h06) && ~metaspi[2] && metaspi[3]) 
                              ? spi_serpar_reg 
                              : dram_writedata_spi[15:8];
    dram_write_enbl_spi <=       (serialaddress == 8'h06) & ~metaspi[2] & metaspi[3] & dramwrite_lowhigh;

  //
  // register 0x20 used for test mode
  //
    // register address 0x20 written by Pico
    interface_test_mode <= ((serialaddress == 8'h20) && ~metaspi[2] && metaspi[3]) 
                         ? (spi_serpar_reg[7:0] == 8'h55) 
                         : interface_test_mode;

  //
  // register 0x88 retrieves words from memory via pair of sequential messages
  //
    // register address 0x88 written by Pico triggers read on second (low) 88 message
    // dram_readdata[15:0] always has the data ready that was read at the dram_address.
    // The read function is triggered after the odd byte is read.
    // The next word is requested after reading the high byte when the SPI address is 8'h88.
    // toggle respective lowhigh bits on a write or read, clear both bits on address load, otherwise lowhigh bits remain the same
    dram_read_enbl_spi <= (serialaddress == 8'h88) & ~metaspi[2] & metaspi[3] & dramread_lowhigh;

    // dram_readdata[15:0] always has the data ready that was read at the dram_address.
    // The read function is triggered after the odd byte is read.
    // The next word is requested after reading the high byte when the SPI address is 8'h88.
    // toggle respective lowhigh bits on a write or read, clear both bits on address load, otherwise lowhigh bits remain the same
    dramwrite_lowhigh <= ((serialaddress == 8'h06) && ~metaspi[2] && metaspi[3]) 
                       ? ~dramwrite_lowhigh 
                       : (((serialaddress == 8'h05) && ~metaspi[2] && metaspi[3]) 
                               ? 1'b0 
                               : dramwrite_lowhigh);
    dramread_lowhigh  <= ((serialaddress == 8'h88) && ~metaspi[2] && metaspi[3]) 
                       ? ~dramread_lowhigh 
                       : (((serialaddress == 8'h05) && ~metaspi[2] && metaspi[3]) 
                               ? 1'b0 
                               : dramread_lowhigh);
  end
end // End of Block HSCLOCKFUNCTIONS

endmodule // End of Module spi_interface
