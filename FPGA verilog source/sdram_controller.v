//==========================================================================================================
// RK05 Emulator
// SDRAM Controller
// File Name: sdram_controller.v
// Functions: 
//   initialization, 
//   refresh, 
//   read from bus, 
//   read from SPI, 
//   write from bus, 
//   write from SPI.
//
//   for simulation - grade 6, CAS 2, BL1
//==========================================================================================================

module sdram_controller(
    input wire clock,                    // master clock 40 MHz
    input wire reset,                    // active high synchronous reset input
    input wire load_address_spi,         // enable from SPI to sdram controller to load the address from sector, head select and cylinder
    input wire load_address_busread,     // enable from bus read to sdram controller to load the address from sector, head select and cylinder
    input wire load_address_buswrite,    // enable from bus write to sdram controller to load the address from sector, head select and cylinder
    input wire dram_read_enbl_spi,       // read enable request to DRAM controller from SPI
    input wire dram_read_enbl_busread,   // read enable request to DRAM controller from the BUS interface
    input wire dram_write_enbl_spi,      // write enable request to DRAM controller from SPI
    input wire dram_write_enbl_buswrite, // write enable request to DRAM controller from the BUS interface
    input wire dram_addr_incr_buswrite,  // addr increment exists so the bus write state machine can advance the address pointer without writing to the DRAM
    input wire [15:0] dram_writedata_spi,      // 16-bit write data to DRAM controller from SPI
    input wire [15:0] dram_writedata_buswrite, // 16-bit write data to DRAM controller from bus
    input wire [7:0] spi_serpar_reg,           // 8-bit SPI serpar register used for writing to the sdram address register
    input wire [1:0] Sector_Address,           // specifies which sector is present "under the heads"
    input wire [7:0] Cylinder_Address,         // valid cylinder address
    input wire Head_Select,                    // head selection (upper or lower)

    input wire [15:0] SDRAM_DQ_in,     // input from DQ signal receivers

    output reg dram_writeack,           // dram read acknowledge

    output reg [15:0] dram_readdata,   // 16-bit read data from DRAM controller

    output reg [15:0] SDRAM_DQ_output, // outputs to DQ signal drivers
    output reg SDRAM_DQ_enable, // DQ output enable, active high
    output reg [12:0] SDRAM_Address,   // SDRAM Address
    output reg SDRAM_BS0,	     // SDRAM Bank Select 0
    output reg SDRAM_BS1,	     // SDRAM Bank Select 1
    output reg SDRAM_WE_n,	     // SDRAM Write
    output reg SDRAM_CAS_n,	 // SDRAM Column Address Select
    output reg SDRAM_RAS_n,	 // SDRAM Row Address Select
    output reg SDRAM_CS_n,	     // SDRAM Chip Select
    output wire SDRAM_CLK,	     // SDRAM Clock
    output reg SDRAM_CKE,	     // SDRAM Clock Enable
    output reg SDRAM_DQML,	     // SDRAM DQ Mask for Lower Byte
    output reg SDRAM_DQMH	     // SDRAM DQ Mask for Upper (High) Byte
);

//============================ Internal Connections ==================================

// === COMMANDS USED BY THE SDRAM CONTROLLER ===
// CS RAS CAS WE Bank A10 An
// == === === == ==== === ==  ========================================================
// H   x   x  x   x    x  x   No Operation
// L   L   L  L   00  .mode.  Load Mode Register
// L   L   H  H  bank .row..  Activate, open a row
// L   H   L  H  bank  H col  Read with auto precharge (read and close row)
// L   H   L  L  bank  H col  Write with auto precharge (Write and close row)
// L   L   L  H   x    x  x   Auto Refresh
// L   L   H  L   x    H  x   Precharge All, precharge the current row of all banks
//
// During Reset, 200 us pause, DQML, DQMH and CKE held high during initial pause period
// After the 200 us pause, set the mode register, then issue eight Auto Refresh cycles
// Many Auto Refresh cycles will happen automatically from controller ST0 (command dispatch NOP)

// SDRAM Controller state definitions and values
`define CC0  5'd0  
`define CC1  5'd1  
`define CC2  5'd2 
`define CC3  5'd3 
`define CC4  5'd4 
`define CC5  5'd5 
`define CC6  5'd6 
`define CC7  5'd7 
`define CC8  5'd8 
`define CC9  5'd9  
`define CC10 5'd10 
`define CC11 5'd11
`define CC12 5'd12 
`define CC13 5'd13 
`define CC14 5'd14 
`define CC15 5'd15 
`define CC16 5'd16 
`define CC17 5'd17
// 0  - command dispatch NOP
// 1  - Read Activate
// 2  - pre-Read NOP
// 3  - Read Auto Precharge
// 4  - Read Precharge Wait
// 5  - Read Capture Data
// 6  - Write Activate
// 7  - pre-Write NOP
// 8  - Write Auto Precharge
// 9  - Write Precharge Wait
// 10 - Write After Precharge Wait
// 11 - Auto Refresh
// 12 - After Auto Refresh Wait
// 17 - After Auto Refresh 2nd Wait
// 13 - Init Precharge All
// 14 - Init Precharge Wait
// 15 - Init Load Mode Register
// 16 - Init NOP before Precharge All


reg [23:0] memory_address; // memory address register
reg [15:0] spi_mem_addr;   // register to save prior bytes of SPI memory address
reg [4:0] memstate; // memory controller state
reg readrequest;
reg writerequest_spi;
reg writerequest_buswrite;
reg capture_readdata;
wire [23:0] loading_address; 

//============================ Start of Code =========================================

// dram_readdata[15:0] always has the data ready that was read at the memory_address.
// The read function is triggered after the odd byte is read.
// The following code is triggered when spi_cs_n is low and counts clocks
//   which is used by a mux to serialize the low or high byte of dram_readdata[15:0].
// The next word is requested after reading the high byte when spi_reg_select == 3.

assign SDRAM_CLK = ~clock;

assign loading_address = {4'b0000, Cylinder_Address[7:0], Head_Select, Sector_Address[1:0], 9'h0};

always @ (posedge clock)
begin : HSCLOCKFUNCTIONS // block name
  if(reset) begin
    dram_readdata <= 16'd0;
    dram_writeack <= 1'd0;
    memory_address <= 24'd0;
    spi_mem_addr <= 16'd0;
    memstate <= `CC16;
    readrequest <= 1'd0;
    writerequest_spi <= 1'd0;
    writerequest_buswrite <= 1'd0;
    capture_readdata <= 1'd0;

    SDRAM_CS_n <= 1'b1;
    SDRAM_RAS_n <= 1'b1;
    SDRAM_CAS_n <= 1'b1;
    SDRAM_WE_n <= 1'b1;
    SDRAM_BS1 <= 1'b0;
    SDRAM_BS0 <= 1'b0;
    SDRAM_Address <= 13'd0;
    SDRAM_DQ_output <= 16'd0;
    SDRAM_DQ_enable <= 1'b0;
    SDRAM_CKE <= 1'b1;
    SDRAM_DQML <= 1'b1;
    SDRAM_DQMH <= 1'b1;
  end
  else begin
    SDRAM_CKE <= 1'b1;

    // memory_address affected by:
    //   load_address_spi;  load_address_busread;  load_address_buswrite;
    //   dram_writeack;  <if none of these - then no change to memory_address;>
    spi_mem_addr <= load_address_spi ? {spi_mem_addr[7:0], spi_serpar_reg[7:0]}: spi_mem_addr;
    memory_address <=  load_address_spi 
                    ? {spi_mem_addr[15:8], spi_mem_addr[7:0], spi_serpar_reg[7:0]} 
                    : (load_address_busread | load_address_buswrite 
                            ? loading_address
                            : ((dram_read_enbl_spi | dram_read_enbl_busread | dram_addr_incr_buswrite | dram_writeack ) 
                                  ?  memory_address + 1 
                                  : memory_address));

    capture_readdata <= (memstate == `CC5); // capture sdram read data the clock cycle after state CC5
    dram_readdata <= capture_readdata 
                   ? SDRAM_DQ_in 
                   : dram_readdata; // capture sdram read data in state CC5

    // readrequest: SET on (dram_read_enbl_spi | dram_read_enbl_busread | dram_read_enbl_buswrite | load_address_spi), CLEAR on (memstate == 'CC5)
    readrequest <= (dram_read_enbl_spi | dram_read_enbl_busread | load_address_spi | load_address_busread) | (readrequest & ~(memstate == `CC5));
    
    // writerequest_spi: SET on (dram_write_enbl_spi), CLEAR on (memstate == 'CC10)
    writerequest_spi <=  (dram_write_enbl_spi ) | (writerequest_spi & ~(memstate == `CC10));  

    // writerequest_buswrite: SET on (dram_write_enbl_buswrite ), CLEAR on (memstate == 'CC10);
    writerequest_buswrite <= (dram_write_enbl_buswrite) | (writerequest_buswrite & ~(memstate == `CC10));

    dram_writeack <= (memstate == `CC9);

    case(memstate)  // SDRAM Controller state machine

    `CC0: begin     // 0  - command dispatch NOP
      memstate <= readrequest 
                ? `CC1 
                : ((writerequest_spi | writerequest_buswrite) 
                      ? `CC6 
                      : `CC11);
      SDRAM_CS_n <= 1'b1;
      SDRAM_RAS_n <= 1'b1;
      SDRAM_CAS_n <= 1'b1;
      SDRAM_WE_n <= 1'b1;
      SDRAM_BS1 <= 1'b0;
      SDRAM_BS0 <= 1'b0;
      SDRAM_Address <= 13'd0;
      SDRAM_DQ_output <= 16'd0;
      SDRAM_DQ_enable <= 1'b0;
      SDRAM_DQML <= 1'b0;
      SDRAM_DQMH <= 1'b0;
     end

    `CC1: begin     // 1  - Read Activate
      memstate <= `CC2;
      SDRAM_CS_n <= 1'b0;
      SDRAM_RAS_n <= 1'b0;
      SDRAM_CAS_n <= 1'b1;
      SDRAM_WE_n <= 1'b1;
      SDRAM_BS1 <= memory_address[23];
      SDRAM_BS0 <= memory_address[22];
      SDRAM_Address <= memory_address[21:9];
      SDRAM_DQ_output <= 16'd0;
      SDRAM_DQ_enable <= 1'b0;
      SDRAM_DQML <= 1'b0;
      SDRAM_DQMH <= 1'b0;
     end

    `CC2: begin     // 2  - pre-Read NOP
      memstate <= `CC3;
      SDRAM_CS_n <= 1'b1;
      SDRAM_RAS_n <= 1'b1;
      SDRAM_CAS_n <= 1'b1;
      SDRAM_WE_n <= 1'b1;
      SDRAM_BS1 <= 1'b0;
      SDRAM_BS0 <= 1'b0;
      SDRAM_Address <= 13'd0;
      SDRAM_DQ_output <= 16'd0;
      SDRAM_DQ_enable <= 1'b0;
      SDRAM_DQML <= 1'b0;
      SDRAM_DQMH <= 1'b0;
     end

    `CC3: begin     // 3  - Read Auto Precharge
      memstate <= `CC4;
      SDRAM_CS_n <= 1'b0;
      SDRAM_RAS_n <= 1'b1;
      SDRAM_CAS_n <= 1'b0;
      SDRAM_WE_n <= 1'b1;
      SDRAM_BS1 <= memory_address[23];
      SDRAM_BS0 <= memory_address[22];
      SDRAM_Address <= {4'b0010, memory_address[8:0]}; // 9 lower bits of memory address with A10 <= 1
      SDRAM_DQ_output <= 16'd0;
      SDRAM_DQ_enable <= 1'b0;
      SDRAM_DQML <= 1'b0;
      SDRAM_DQMH <= 1'b0;
     end

    `CC4: begin     // 4  - Read Precharge Wait
      memstate <= `CC5;
      SDRAM_CS_n <= 1'b1;
      SDRAM_RAS_n <= 1'b1;
      SDRAM_CAS_n <= 1'b1;
      SDRAM_WE_n <= 1'b1;
      SDRAM_BS1 <= 1'b0;
      SDRAM_BS0 <= 1'b0;
      SDRAM_Address <= 13'd0;
      SDRAM_DQ_output <= 16'd0;
      SDRAM_DQ_enable <= 1'b0;
      SDRAM_DQML <= 1'b0;
      SDRAM_DQMH <= 1'b0;
     end

    `CC5: begin     // 5  - Read Capture Data
      memstate <= `CC0;
      SDRAM_CS_n <= 1'b1;
      SDRAM_RAS_n <= 1'b1;
      SDRAM_CAS_n <= 1'b1;
      SDRAM_WE_n <= 1'b1;
      SDRAM_BS1 <= 1'b0;
      SDRAM_BS0 <= 1'b0;
      SDRAM_Address <= 13'd0;
      SDRAM_DQ_output <= 16'd0;
      SDRAM_DQ_enable <= 1'b0;
      SDRAM_DQML <= 1'b0;
      SDRAM_DQMH <= 1'b0;
     end

    `CC6: begin     // 6  - Write Activate
      memstate <= `CC7;
      SDRAM_CS_n <= 1'b0;
      SDRAM_RAS_n <= 1'b0;
      SDRAM_CAS_n <= 1'b1;
      SDRAM_WE_n <= 1'b1;
      SDRAM_BS1 <= memory_address[23];
      SDRAM_BS0 <= memory_address[22];
      SDRAM_Address <= memory_address[21:9];
      SDRAM_DQ_output <= 16'd0;
      SDRAM_DQ_enable <= 1'b0;
      SDRAM_DQML <= 1'b0;
      SDRAM_DQMH <= 1'b0;
     end

    `CC7: begin     // 7  - pre-Write NOP
      memstate <= `CC8;
      SDRAM_CS_n <= 1'b1;
      SDRAM_RAS_n <= 1'b1;
      SDRAM_CAS_n <= 1'b1;
      SDRAM_WE_n <= 1'b1;
      SDRAM_BS1 <= 1'b0;
      SDRAM_BS0 <= 1'b0;
      SDRAM_Address <= 13'd0;
      SDRAM_DQ_output <= 16'd0;
      SDRAM_DQ_enable <= 1'b0;
      SDRAM_DQML <= 1'b0;
      SDRAM_DQMH <= 1'b0;
     end

    `CC8: begin     // 8  - Write Auto Precharge
      memstate <= `CC9;
      SDRAM_CS_n <= 1'b0;
      SDRAM_RAS_n <= 1'b1;
      SDRAM_CAS_n <= 1'b0;
      SDRAM_WE_n <= 1'b0;
      SDRAM_BS1 <= memory_address[23];
      SDRAM_BS0 <= memory_address[22];
      SDRAM_Address <= {4'b0010, memory_address[8:0]}; // 9 lower bits of memory address with A10 <= 1
      SDRAM_DQ_output <= writerequest_spi 
                       ? dram_writedata_spi 
                       : (writerequest_buswrite 
                               ? dram_writedata_buswrite 
                               : 16'd0);
      SDRAM_DQ_enable <= 1'b1;
      SDRAM_DQML <= 1'b0;
      SDRAM_DQMH <= 1'b0;
     end

    `CC9: begin     // 9  - Write Precharge Wait
      memstate <= `CC10;
      SDRAM_CS_n <= 1'b1;
      SDRAM_RAS_n <= 1'b1;
      SDRAM_CAS_n <= 1'b1;
      SDRAM_WE_n <= 1'b1;
      SDRAM_BS1 <= 1'b0;
      SDRAM_BS0 <= 1'b0;
      SDRAM_Address <= 13'd0;
      SDRAM_DQ_output <= 16'd0;
      SDRAM_DQ_enable <= 1'b0;
      SDRAM_DQML <= 1'b0;
      SDRAM_DQMH <= 1'b0;
     end

    `CC10: begin     // 10 - Write After Precharge Wait
      memstate <= `CC0;
      SDRAM_CS_n <= 1'b1;
      SDRAM_RAS_n <= 1'b1;
      SDRAM_CAS_n <= 1'b1;
      SDRAM_WE_n <= 1'b1;
      SDRAM_BS1 <= 1'b0;
      SDRAM_BS0 <= 1'b0;
      SDRAM_Address <= 13'd0;
      SDRAM_DQ_output <= 16'd0;
      SDRAM_DQ_enable <= 1'b0;
      SDRAM_DQML <= 1'b0;
      SDRAM_DQMH <= 1'b0;
     end

    `CC11: begin     // 11 - Auto Refresh
      memstate <= `CC12;
      SDRAM_CS_n <= 1'b0;
      SDRAM_RAS_n <= 1'b0;
      SDRAM_CAS_n <= 1'b0;
      SDRAM_WE_n <= 1'b1;
      SDRAM_BS1 <= 1'b0;
      SDRAM_BS0 <= 1'b0;
      SDRAM_Address <= 13'd0;
      SDRAM_DQ_output <= 16'd0;
      SDRAM_DQ_enable <= 1'b0;
      SDRAM_DQML <= 1'b0;
      SDRAM_DQMH <= 1'b0;
     end

    `CC12: begin     // 12 - After Auto Refresh Wait
      memstate <= `CC17;
      SDRAM_CS_n <= 1'b1;
      SDRAM_RAS_n <= 1'b1;
      SDRAM_CAS_n <= 1'b1;
      SDRAM_WE_n <= 1'b1;
      SDRAM_BS1 <= 1'b0;
      SDRAM_BS0 <= 1'b0;
      SDRAM_Address <= 13'd0;
      SDRAM_DQ_output <= 16'd0;
      SDRAM_DQ_enable <= 1'b0;
      SDRAM_DQML <= 1'b0;
      SDRAM_DQMH <= 1'b0;
     end

    `CC17: begin     // 17 - After Auto Refresh 2nd Wait
      memstate <= `CC0;
      SDRAM_CS_n <= 1'b1;
      SDRAM_RAS_n <= 1'b1;
      SDRAM_CAS_n <= 1'b1;
      SDRAM_WE_n <= 1'b1;
      SDRAM_BS1 <= 1'b0;
      SDRAM_BS0 <= 1'b0;
      SDRAM_Address <= 13'd0;
      SDRAM_DQ_output <= 16'd0;
      SDRAM_DQ_enable <= 1'b0;
      SDRAM_DQML <= 1'b0;
      SDRAM_DQMH <= 1'b0;
     end

    `CC13: begin     // 13 - Init Precharge All
      memstate <= `CC14;
      SDRAM_CS_n <= 1'b0;
      SDRAM_RAS_n <= 1'b0;
      SDRAM_CAS_n <= 1'b1;
      SDRAM_WE_n <= 1'b0;
      SDRAM_BS1 <= 1'b0;
      SDRAM_BS0 <= 1'b0;
      SDRAM_Address <= 13'b0010000000000; // Precharge All requires A10 to be high
      SDRAM_DQ_output <= 16'd0;
      SDRAM_DQ_enable <= 1'b0;
      SDRAM_DQML <= 1'b0;
      SDRAM_DQMH <= 1'b0;
     end

    `CC14: begin     // 14 - Init Precharge Wait
      memstate <= `CC15;
      SDRAM_CS_n <= 1'b1;
      SDRAM_RAS_n <= 1'b1;
      SDRAM_CAS_n <= 1'b1;
      SDRAM_WE_n <= 1'b1;
      SDRAM_BS1 <= 1'b0;
      SDRAM_BS0 <= 1'b0;
      SDRAM_Address <= 13'd0;
      SDRAM_DQ_output <= 16'd0;
      SDRAM_DQ_enable <= 1'b0;
      SDRAM_DQML <= 1'b0;
      SDRAM_DQMH <= 1'b0;
     end

    `CC15: begin     // 15 - Init Load Mode Register
      // SDRAM Mode Register setting
      // BS1,BS0,A12,A11,A10 = 5'b00000
      // A9 = 1 Burst read and single write
      // A8,A7 = 2'b00 Reserved and Test Mode
      // A6,A5,A4 = 3'b010 CAS Latency = 2
      // A3 = 0 Sequential
      // A2,A1,A0 = 3'b000 Burst Length = 1
      //
      memstate <= `CC0;
      SDRAM_CS_n <= 1'b0;
      SDRAM_RAS_n <= 1'b0;
      SDRAM_CAS_n <= 1'b0;
      SDRAM_WE_n <= 1'b0;
      SDRAM_BS1 <= 1'b0;
      SDRAM_BS0 <= 1'b0;
      SDRAM_Address <= 13'b0001000100000;
      SDRAM_DQ_output <= 16'd0;
      SDRAM_DQ_enable <= 1'b0;
      SDRAM_DQML <= 1'b0;
      SDRAM_DQMH <= 1'b0;
     end

    `CC16: begin     // 16 - Init NOP before Precharge All
      memstate <= `CC13;
      SDRAM_CS_n <= 1'b1;
      SDRAM_RAS_n <= 1'b1;
      SDRAM_CAS_n <= 1'b1;
      SDRAM_WE_n <= 1'b1;
      SDRAM_BS1 <= 1'b0;
      SDRAM_BS0 <= 1'b0;
      SDRAM_Address <= 13'd0;
      SDRAM_DQ_output <= 16'd0;
      SDRAM_DQ_enable <= 1'b0;
      SDRAM_DQML <= 1'b1;
      SDRAM_DQMH <= 1'b1;
     end

    default: begin      // should never happen
      memstate <= `CC16;
    end

    endcase
  end
end // End of Block HSCLOCKFUNCTIONS

endmodule // End of Module sdram_controller
