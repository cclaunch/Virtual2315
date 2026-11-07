//==========================================================================================================
// RK05 Emulator
// read disk from the BUS
// File Name: bus_disk_write.v
// Functions: 
//   TB for my module
//
//==========================================================================================================
module TB_bus_disk_write(
);

//============================ Internal Connections ==================================

     reg clock;
     reg reset;
     reg BUS_WT_GATE_L;     // write gate, when active enables read circuitry
     reg BUS_WT_DATA_CLK_L;  // Composite write data and write clock
     reg BUS_WT_CLOCKB_L;      // Bit cell data phase gate, when high is data bit time
     reg Selected_Ready;     // disk contents have been copied from the microSD to the SDRAM & drive selected & ~fault latch
     reg clkenbl_sector;    // sector enable pulse
     reg real_drive;

     wire dram_write_enbl_buswrite;       // read enable request to DRAM controller
     wire [15:0] dram_writedata_buswrite; // 16-bit write data to DRAM controller
     wire load_address_buswrite;          // enable to command the sdram controller to load the address from sector, head select and cylinder
     wire write_indicator;                // active high signal to drive the WT front panel indicator
     wire write_selected_ready;           // for command interrupt
     wire ECC_error;
     wire BUS_WT_CLOCKB_EMUL_L;               // generated Write Clock B for nonreal drive

     wire clock_pulse;       // clock pulse with proper 160 us width from drive
     wire data_pulse;       // data pulse with proper 160 us width from drive
     wire clkenbl_read_bit;  // enable for disk read clock
     wire clkenbl_read_data; // enable for disk read data
     wire clkenbl_1usec;

     reg dram_read_enbl_busread; // read enable request to DRAM controller
     wire BUS_RD_DATA_H;          // Read data pulses
     wire BUS_RD_CLK_H;          // Read clock pulses
     reg load_address_busread;   // enable to command the sdram controller to load the address from sector, head select and cylinder
     wire read_indicator;         // active high signal to drive the RD front panel indicator
     wire read_selected_ready;     // read strobe and selected_ready for command interrupt

     wire ask_dram;               // advance memory contents when this goes high
     reg [7:0] Cylinder_Address; // register that stores the valid cylinder address
     reg [1:0] Sector_Address; //counter that specifies which sector is present "under the heads"
     wire [15:0] dram_readdata; // 16-bit read data from DRAM controller

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
     reg dram_read_enbl_spi;
     reg dram_write_enbl_spi;
     reg [15:0] dram_writedata_spi;
     reg [7:0] spi_serpar_reg;
reg Head_Select;

 bus_disk_write DUT (
.clock (clock),
.reset (reset),
.BUS_WT_GATE_L (BUS_WT_GATE_L),
.BUS_WT_DATA_CLK_L (BUS_WT_DATA_CLK_L),
.BUS_WT_CLOCKB_L (BUS_WT_CLOCKB_L),
.Selected_Ready (Selected_Ready),
.real_drive (real_drive),
.clkenbl_sector (clkenbl_sector),
.dram_write_enbl_buswrite (dram_write_enbl_buswrite),
.dram_writedata_buswrite (dram_writedata_buswrite),
.load_address_buswrite (load_address_buswrite),
.write_indicator (write_indicator),
.ECC_error (ECC_error),
.BUS_WT_CLOCKB_EMUL_L (BUS_WT_CLOCKB_EMUL_L),
.write_selected_ready (write_selected_ready)
);

 timing_gen mytiming (
     .clock (clock),             // master clock 40 MHz
    .reset (reset),             // active high synchronous reset input
    .clkenbl_read_bit (clkenbl_read_bit),  // enable for disk read clock
    .clkenbl_read_data (clkenbl_read_data), // enable for disk read data
    .clock_pulse (clock_pulse),       // clock pulse with proper 165 us width from drive
    .data_pulse (data_pulse),        // data pulse with proper 165 us width from drive
    .clkenbl_1usec (clkenbl_1usec)     // enable for 1 usec clock pulse
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



`define ONE 1'b0
`define ZERO 1'b1

`define BIT(whazzit)   \
    @(negedge BUS_WT_CLOCKB_L); \
    BUS_WT_DATA_CLK_L <= 1'b0; \
    @(posedge BUS_WT_CLOCKB_L); \
    BUS_WT_DATA_CLK_L <= whazzit;  

`define WORD(bf, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, e0, e1, e2, e3)  \
    @(negedge BUS_WT_CLOCKB_L); \
    BUS_WT_DATA_CLK_L <= 1'b0; \
    @(posedge BUS_WT_CLOCKB_L); \
    BUS_WT_DATA_CLK_L <= ~1'b``b15; \
    @(negedge BUS_WT_CLOCKB_L); \
    BUS_WT_DATA_CLK_L <= 1'b0; \
    @(posedge BUS_WT_CLOCKB_L); \
    BUS_WT_DATA_CLK_L <= ~1'b``b14; \
    @(negedge BUS_WT_CLOCKB_L); \
    BUS_WT_DATA_CLK_L <= 1'b0; \
    @(posedge BUS_WT_CLOCKB_L); \
    BUS_WT_DATA_CLK_L <= ~1'b``b13; \
    @(negedge BUS_WT_CLOCKB_L); \
    BUS_WT_DATA_CLK_L <= 1'b0; \
    @(posedge BUS_WT_CLOCKB_L); \
    BUS_WT_DATA_CLK_L <= ~1'b``b12; \
    @(negedge BUS_WT_CLOCKB_L); \
    BUS_WT_DATA_CLK_L <= 1'b0; \
    @(posedge BUS_WT_CLOCKB_L); \
    BUS_WT_DATA_CLK_L <= ~1'b``b11; \
    @(negedge BUS_WT_CLOCKB_L); \
    BUS_WT_DATA_CLK_L <= 1'b0; \
    @(posedge BUS_WT_CLOCKB_L); \
    BUS_WT_DATA_CLK_L <= ~1'b``b10; \
    @(negedge BUS_WT_CLOCKB_L); \
    BUS_WT_DATA_CLK_L <= 1'b0; \
    @(posedge BUS_WT_CLOCKB_L); \
    BUS_WT_DATA_CLK_L <= ~1'b``b9; \
    @(negedge BUS_WT_CLOCKB_L); \
    BUS_WT_DATA_CLK_L <= 1'b0; \
    @(posedge BUS_WT_CLOCKB_L); \
    BUS_WT_DATA_CLK_L <= ~1'b``b8; \
    @(negedge BUS_WT_CLOCKB_L); \
    BUS_WT_DATA_CLK_L <= 1'b0; \
    @(posedge BUS_WT_CLOCKB_L); \
    BUS_WT_DATA_CLK_L <= ~1'b``b7; \
    @(negedge BUS_WT_CLOCKB_L); \
    BUS_WT_DATA_CLK_L <= 1'b0; \
    @(posedge BUS_WT_CLOCKB_L); \
    BUS_WT_DATA_CLK_L <= ~1'b``b6; \
    @(negedge BUS_WT_CLOCKB_L); \
    BUS_WT_DATA_CLK_L <= 1'b0; \
    @(posedge BUS_WT_CLOCKB_L); \
    BUS_WT_DATA_CLK_L <= ~1'b``b5; \
    @(negedge BUS_WT_CLOCKB_L); \
    BUS_WT_DATA_CLK_L <= 1'b0; \
    @(posedge BUS_WT_CLOCKB_L); \
    BUS_WT_DATA_CLK_L <= ~1'b``b4; \
    @(negedge BUS_WT_CLOCKB_L); \
    BUS_WT_DATA_CLK_L <= 1'b0; \
    @(posedge BUS_WT_CLOCKB_L); \
    BUS_WT_DATA_CLK_L <= ~1'b``b3; \
    @(negedge BUS_WT_CLOCKB_L); \
    BUS_WT_DATA_CLK_L <= 1'b0; \
    @(posedge BUS_WT_CLOCKB_L); \
    BUS_WT_DATA_CLK_L <= ~1'b``b2; \
    @(negedge BUS_WT_CLOCKB_L); \
    BUS_WT_DATA_CLK_L <= 1'b0; \
    @(posedge BUS_WT_CLOCKB_L); \
    BUS_WT_DATA_CLK_L <= ~1'b``b1; \
    @(negedge BUS_WT_CLOCKB_L); \
    BUS_WT_DATA_CLK_L <= 1'b0; \
    @(posedge BUS_WT_CLOCKB_L); \
    BUS_WT_DATA_CLK_L <= ~1'b``bf; \
    @(negedge BUS_WT_CLOCKB_L); \
    BUS_WT_DATA_CLK_L <= 1'b0; \
    @(posedge BUS_WT_CLOCKB_L); \
    BUS_WT_DATA_CLK_L <= ~1'b``e0; \
    @(negedge BUS_WT_CLOCKB_L); \
    BUS_WT_DATA_CLK_L <= 1'b0; \
    @(posedge BUS_WT_CLOCKB_L); \
    BUS_WT_DATA_CLK_L <= ~1'b``e1; \
    @(negedge BUS_WT_CLOCKB_L); \
    BUS_WT_DATA_CLK_L <= 1'b0; \
    @(posedge BUS_WT_CLOCKB_L); \
    BUS_WT_DATA_CLK_L <= ~1'b``e2; \
    @(negedge BUS_WT_CLOCKB_L); \
    BUS_WT_DATA_CLK_L <= 1'b0; \
    @(posedge BUS_WT_CLOCKB_L); \
    BUS_WT_DATA_CLK_L <= ~1'b``e3; 



//============================ Start of Code =========================================
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

// start off our bus write module constants
   initial begin
     Cylinder_Address  <= 8'd161;
     Sector_Address  <= 2'd3;
     Head_Select <= 1'b0;
     dram_read_enbl_spi <= 1'b0;
     dram_write_enbl_spi <= 1'b0;
     dram_read_enbl_busread <= 1'b0;
     spi_serpar_reg <= 8'd0;
     load_address_spi <= 1'b0;
     load_address_busread <= 1'b0;
     dram_writedata_spi <= 8'd0;
   end

// sector clk pulses
    initial begin 
      clkenbl_sector <= 1'b0;
      @(negedge reset);
      clkenbl_sector <= 1'b0;
      #165000
     forever begin
      clkenbl_sector <= 1'b0;
      #10000000
      clkenbl_sector <= 1'b1;
      #40
      clkenbl_sector <= 1'b0;
     end
    end

// drive our write gate
    initial begin
      @(negedge reset);
      BUS_WT_GATE_L <= 1'b1;
      #10165000
      BUS_WT_GATE_L <= 1'b0;
      #10000000
      BUS_WT_GATE_L <= 1'b1;
    end

// drive the write clock signal
    initial begin
      @(negedge reset);
      BUS_WT_CLOCKB_L <= 1'b1;
      #33
      BUS_WT_CLOCKB_L <= 1'b1;
      @(negedge BUS_WT_GATE_L)
      forever begin
         BUS_WT_CLOCKB_L <= 1'b0;
         #725
         BUS_WT_CLOCKB_L <= 1'b1;
         #725
         BUS_WT_CLOCKB_L <= 1'b0;
       end
    end

// drive the sync bits pattern
     initial begin
        @(negedge reset);
        BUS_WT_DATA_CLK_L <= 1'b1;
        #10164900
        repeat(188)
        begin
            `BIT(`ZERO)
        end
        `BIT(`ONE )                  // 1 bit sync word 8000
        `BIT(`ONE )                  // 1 bit check bit 1
        `BIT(`ONE )                  // 1 bit check bit 2
        `BIT(`ONE )                  // 1 bit check bit 3
        `BIT(`ZERO)                  // 0 bit end of sync,check bit 4
// word one
        `WORD(1, 0, 1, 0, 0, 1, 0, 1, 1, 0, 1, 0, 0, 1, 0, 1, 0, 0, 0, 0)
// word two
        `WORD(1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0)
// word three
        `WORD(1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0)
// word four
        `WORD(1, 0, 0, 1, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 1, 0, 1, 1, 1, 0)
// word five
        `WORD(1, 0, 1, 0, 0, 1, 0, 1, 1, 0, 1, 0, 0, 1, 0, 1, 0, 0, 0, 0)
// word six
        `WORD(1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0)
// word seven
        `WORD(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
// word eight
        `WORD(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 1, 1, 0)
// word nine
        `WORD(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 1, 1, 0, 0)
// word ten
        `WORD(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 1, 0, 0)
     repeat(310)
         begin
             `WORD(0, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0)
         end
// word 321
        `WORD(1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0)
// extra word
     `WORD(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
     end

// drive selection
     initial begin
         Selected_Ready <= 1'b1;
         real_drive <= 1'b0;
     end

endmodule // End of Module TB_bus_disk_read
