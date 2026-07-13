//==========================================================================================================
// RK05 Emulator
// read disk from the BUS
// File Name: bus_disk_read.v
// Functions: 
//   TB for my module
//
//==========================================================================================================

module TB_bus_disk_read(
);

//============================ Internal Connections ==================================

reg clock;
reg reset;
     reg BUS_RD_GATE_L;     // Read gate, when active enables read circuitry
     wire [15:0] dram_readdata; // 16-bit read data from DRAM controller
     reg Selected_Ready;    // disk contents have been copied from the microSD to the SDRAM & drive selected & ~fault latch
     reg [7:0] Cylinder_Address; // register that stores the valid cylinder address

     wire clock_pulse;       // clock pulse with proper 160 us width from drive
     wire data_pulse;       // data pulse with proper 160 us width from drive
     wire clkenbl_read_bit;  // enable for disk read clock
     wire clkenbl_read_data; // enable for disk read data
     wire clkenbl_1usec;

    reg [4:0] number_of_sectors;
    reg [15:0] microseconds_per_sector; // number of microseconds per sector to generate sector timing
    reg real_drive;
    wire clkenbl_sector;      // enable for disk read clock
    wire clkenbl_index;       // enable for disk read data
    reg BUS_SECTOR_L;                   // sector pulse from the 2310
    reg BUS_INDEX_L;                    // index pulse from the 2310
    wire BUS_SECTOR_EMUL_H;    // active-high 165 usec sector pulse
    wire BUS_INDEX_EMUL_H;     // active-high 165 usec index pulse
    wire[1:0] Sector_Address; //counter that specifies which sector is present "under the heads"
     wire dram_read_enbl_busread; // read enable request to DRAM controller


     wire dram_read_enbl_busread; // read enable request to DRAM controller
     wire BUS_RD_DATA_H;          // Read data pulses
     wire BUS_RD_CLK_H;          // Read clock pulses
     wire load_address_busread;   // enable to command the sdram controller to load the address from sector, head select and cylinder
     wire read_indicator;         // active high signal to drive the RD front panel indicator
     wire read_selected_ready;     // read strobe and selected_ready for command interrupt

     wire ask_dram;               // advance memory contents when this goes high

wire [15:0] SDRAM_DQ_in;
wire [15:0] SDRAM_DQ_output;
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
reg load_address_spi;
     reg load_address_buswrite;
     reg dram_read_enbl_spi;
     reg dram_write_enbl_spi;
     reg dram_write_enbl_buswrite;
     reg [15:0] dram_writedata_spi;
     reg [15:0] dram_writedata_buswrite;
     reg [7:0] spi_serpar_reg;
reg Head_Select;

 bus_disk_read DUT (
.clock (clock),
.reset (reset),
.BUS_RD_GATE_L (BUS_RD_GATE_L),
.clkenbl_read_bit (clkenbl_read_bit),
.clkenbl_read_data (clkenbl_read_data),
.clock_pulse (clock_pulse),
.data_pulse (data_pulse),
.dram_readdata (dram_readdata),
.Selected_Ready  (Selected_Ready),
.clkenbl_sector (clkenbl_sector),
.dram_read_enbl_busread (dram_read_enbl_busread),
.BUS_RD_DATA_H (BUS_RD_DATA_H),
.BUS_RD_CLK_H (BUS_RD_CLK_H),
.load_address_busread (load_address_busread),
.read_indicator (read_indicator),
.read_selected_ready (read_selected_ready)
);

 TB_sdram_controller my_sdram_controller (
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
    .dram_writedata_spi (dram_writedata_spi),
    .dram_writedata_buswrite (dram_writedata_buswrite),
    .spi_serpar_reg (spi_serpar_reg),
    .Sector_Address (Sector_Address),
    .Cylinder_Address (Cylinder_Address),
    .Head_Select (Head_Select),

    .SDRAM_DQ_in (SDRAM_DQ_in),

    // Outputs
    .dram_readdata (dram_readdata),

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


 timing_gen mytiming (
     .clock (clock),                                   // master clock 40 MHz
    .reset (reset),                                    // active high synchronous reset input
    .clkenbl_read_bit (clkenbl_read_bit),              // enable for disk read clock
    .clkenbl_read_data (clkenbl_read_data),            // enable for disk read data
    .clock_pulse (clock_pulse),                        // clock pulse with proper 165 us width from drive
    .data_pulse (data_pulse),                          // data pulse with proper 165 us width from drive
    .clkenbl_1usec (clkenbl_1usec)                     // enable for 1 usec clock pulse
);

 sector_and_index mysector (
    .clock (clock),                                    // master clock 40 MHz
    .reset (reset),                                    // active high synchronous reset input
    .clkenbl_1usec (clkenbl_1usec),                    // 1 usec clock enable input from the timing generator
    .real_drive (real_drive),                          // on to relay the real pulses from the 2310, off to generate
    .BUS_SECTOR_L (BUS_SECTOR_L),      
    .BUS_INDEX_L (BUS_INDEX_L),      
    .clkenbl_sector (clkenbl_sector),                  // enable for disk read clock
    .clkenbl_index (clkenbl_index),                    // enable for disk read data
    .BUS_SECTOR_EMUL_H (BUS_SECTOR_EMUL_H),            // active-high 165 usec sector pulse
    .BUS_INDEX_EMUL_H (BUS_INDEX_EMUL_H),              // active-high 165 usec index pulse
    .Sector_Address  (Sector_Address)                  //counter that specifies sector present "under the heads"
);

//============================ Start of Code =========================================

assign ask_dram = load_address_busread | dram_read_enbl_busread;

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

// start off our bus read module constants
   initial begin
     Cylinder_Address  <= 8'd0;
     Head_Select <= 1'b0;
     dram_read_enbl_spi <= 1'b0;
     dram_write_enbl_spi <= 1'b0;
     dram_write_enbl_buswrite <= 1'b0;
     spi_serpar_reg <= 8'd0;
     dram_writedata_spi <= 16'd0;
     dram_writedata_buswrite <= 16'd0;
     load_address_spi <= 1'b0;
     load_address_buswrite <= 1'b0;
   end


// drive our read gate
    initial begin
      @(negedge reset)
      BUS_RD_GATE_L <= 1'b1;
      #85166033
      BUS_RD_GATE_L <= 1'b0;
      #9768004
      BUS_RD_GATE_L <= 1'b1;
    end


// drive selection
     initial begin
         Selected_Ready <= 1'b1;
         real_drive <= 1'b1;
     end

// sector pulses
  initial begin
    BUS_SECTOR_L <= 1'b1;
    @(negedge reset)
    BUS_SECTOR_L <= 1'b1;
    #1114
    BUS_SECTOR_L <= 1'b0;
    #165000
    forever 
      begin
       BUS_SECTOR_L <= 1'b1;
       #4835000
       BUS_SECTOR_L <= 1'b0;
       #165000
       BUS_SECTOR_L <= 1'b1;
      end
  end
 
// index pulses
  initial begin
    BUS_INDEX_L <= 1'b1;
    @(negedge reset)
    BUS_INDEX_L <= 1'b1;
    #1114
    BUS_INDEX_L <= 1'b1;
    #600000
    forever begin
       BUS_INDEX_L <= 1'b0;
       #165000
       BUS_INDEX_L <= 1'b1;
       #39835000
       BUS_INDEX_L <= 1'b0;
    end
  end


endmodule // End of Module TB_bus_disk_read
