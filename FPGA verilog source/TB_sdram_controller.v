//==========================================================================================================
// testbench for SDRAM Controller
//==========================================================================================================

module TB_sdram_controller(
    input wire clock,                    // master clock 40 MHz
    input wire reset,                    // active high synchronous reset input
    input wire load_address_spi,         // enable from SPI to sdram controller to load the address from sector, head select and cylinder
    input wire load_address_busread,     // enable from bus read to sdram controller to load the address from sector, head select and cylinder
    input wire load_address_buswrite,    // enable from bus write to sdram controller to load the address from sector, head select and cylinder
    input wire dram_read_enbl_spi,       // read enable request to DRAM controller from SPI
    input wire dram_read_enbl_busread,   // read enable request to DRAM controller from the BUS interface
    input wire dram_addr_incr_buswrite,  // increment address without write
    input wire dram_write_enbl_spi,      // write enable request to DRAM controller from SPI
    input wire dram_write_enbl_buswrite, // write enable request to DRAM controller from the BUS interface
    input wire [15:0] dram_writedata_spi,       // 16-bit write data to DRAM controller from SPI
    input wire [15:0] dram_writedata_buswrite,   // 16-bit write data to DRAM controller from bus
    input wire [7:0] spi_serpar_reg,           // 8-bit SPI serpar register used for writing to the sdram address register
    input wire [1:0] Sector_Address,           // specifies which sector is present "under the heads"
    input wire [7:0] Cylinder_Address,         // valid cylinder address
    input wire Head_Select,              // head selection (upper or lower)


    input wire [15:0] SDRAM_DQ_in,     // input from DQ signal receivers

    output reg [15:0] dram_readdata,   // 16-bit read data from DRAM controller

    output wire  dram_readack,
    output wire  dram_writeack,

    output wire [15:0] SDRAM_DQ_output, // outputs to DQ signal drivers
    output wire SDRAM_DQ_enable, // DQ output enable, active high
    output wire [12:0] SDRAM_Address,   // SDRAM Address
    output wire SDRAM_BS0,	     // SDRAM Bank Select 0
    output wire SDRAM_BS1,	     // SDRAM Bank Select 1
    output wire SDRAM_WE_n,	     // SDRAM Write
    output wire SDRAM_CAS_n,	 // SDRAM Column Address Select
    output wire SDRAM_RAS_n,	 // SDRAM Row Address Select
    output wire SDRAM_CS_n,	     // SDRAM Chip Select
    output wire SDRAM_CLK,	     // SDRAM Clock
    output wire SDRAM_CKE,	     // SDRAM Clock Enable
    output wire SDRAM_DQML,	     // SDRAM DQ Mask for Lower Byte
    output wire SDRAM_DQMH	     // SDRAM DQ Mask for Upper (High) Byte
);

//============================ Internal Connections ==================================


wire [15:0] real_dram_readdata;
wire readrequest;
wire writerequest;
wire loadaddrrequest;
wire [15:0] dramoutput;
reg [31:0] outfile; 
reg [31:0] infile; 

//
//============================ Start of Code =========================================

assign loadaddrrequest = load_address_spi | load_address_busread | load_address_buswrite;
assign readrequest = dram_read_enbl_spi | dram_read_enbl_busread | load_address_busread;
assign writerequest = dram_write_enbl_spi | dram_write_enbl_buswrite;
assign dramoutput = dram_write_enbl_spi ? dram_writedata_spi : dram_writedata_buswrite;


initial begin
  forever begin
    outfile = $fopen("log.txt", "w");
    @(posedge loadaddrrequest)
    infile = $fopen("SDRAM.txt","r");
  end
end

initial begin
   forever begin
    @(posedge writerequest)
    $fdisplay(outfile, "data %h\n",dramoutput);
  end
end

initial begin
  dram_readdata <= 16'b0;
  forever begin
    @(posedge readrequest)
    $fscanf(infile, "%h", dram_readdata);
  end
end

// ======== Module ======== sdram_controller =====
sdram_controller real_sdram_controller (
    // Inputs
    .clock (clock),
    .reset (reset),
    .load_address_spi (load_address_spi),
    .load_address_busread (load_address_busread),
    .load_address_buswrite (load_address_buswrite),
    .dram_read_enbl_spi (dram_read_enbl_spi),
    .dram_read_enbl_busread (dram_read_enbl_busread),
    .dram_write_enbl_spi (dram_write_enbl_spi),
    .dram_addr_incr_buswrite (dram_addr_incr_buswrite),
    .dram_write_enbl_buswrite (dram_write_enbl_buswrite),
    .dram_writedata_spi (dram_writedata_spi),
    .dram_writedata_buswrite (dram_writedata_buswrite),
    .spi_serpar_reg (spi_serpar_reg),
    .Sector_Address (Sector_Address),
    .Cylinder_Address (Cylinder_Address),
    .Head_Select (Head_Select),

    .SDRAM_DQ_in (SDRAM_DQ_in),

    // Outputs
    .dram_readdata (real_dram_readdata),
    .dram_readack (dram_readack),
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

endmodule // End of Module TB_sdram_controller
