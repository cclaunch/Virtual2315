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
     reg  BUS_WT_CLOCKB_L;      // Bit cell data phase gate, when high is data bit time
     reg BUS_SECTOR_CTRL_L;    // sector itself

     reg Selected_Ready;     // disk contents have been copied from the microSD to the SDRAM & drive selected & ~fault latch
     reg clkenbl_sector;    // sector enable pulse
     reg real_drive;
     wire Cart_Ready;

     wire dram_write_enbl_buswrite;       // read enable request to DRAM controller
//     wire dram_addr_incr_buswrite;        // kdkdk
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
     reg Head_Select;
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

wire clock_dumbass;
wire data_dumbass;
reg  data_glitched;

wire load_address_spi;
     wire dram_read_enbl_spi;
     wire dram_write_enbl_spi;
     wire [15:0] dram_writedata_spi;
     wire [7:0] spi_serpar_reg;


    reg spi_clk;
    reg spi_cs_n;
    reg spi_mosi;
    wire spi_miso;
    
// Storage for captured read data
    reg [7:0] spi_rx_byte;

 bus_disk_write DUT (
.clock (clock),
.reset (reset),
.BUS_WT_GATE_L (BUS_WT_GATE_L),
.BUS_WT_DATA_CLK_L (data_glitched),
.Selected_Ready (Selected_Ready),
.BUS_SECTOR_L (BUS_SECTOR_CTRL_L),
.real_drive (real_drive),
.Cart_Ready (Cart_Ready),
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
     .clock (clock),             // master clock 40 MHz - 25ns per cycle
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

 spi_interface myspi (
     .clock (clock),             // master clock 40 MHz - 25ns per cycle
    .reset (reset),             // active high synchronous reset input
    .spi_clk (spi_clk),                  // SPI clock
    .spi_cs_n (spi_cs_n),                 // SPI active low chip select
    .spi_mosi (spi_mosi),                 // SPI controller data output, peripheral data input
    .dram_readdata (dram_readdata),     // 16-bit read data from DRAM controller
    .Cylinder_Address (Cylinder_Address),   // input to be able to read the Cylinder Address
    .Head_Select (Head_Select),              // input to be able to read the Head Select bit
    .Selected_Ready (Selected_Ready),           // input to be able to read Selected_Ready
    .Sector_Address (Sector_Address),     // Sector Address to be read test visibility mode
    .strobe_selected_ready (1'b0),
    .read_selected_ready (1'b0),
    .write_selected_ready (write_selected_ready),
    .BUS_UNLOCKED_EMUL_L (1'b1),      // driven by drive_select.v
    .BUS_FILE_READY_CTRL_L (1'b0),    // we say the drive is ready for input output operations
    .BUS_WRITE_SEL_ERR_L (1'b1),      // got error trying to select/write on drive
    .ECC_error (ECC_error),                // got error in four ECC bits during write
    .real_drive (real_drive),               // hybrid or pure virtual mode
    .spi_miso (spi_miso),                 // SPI controller data input, peripheral data output
    .load_address_spi (load_address_spi),         // enable from SPI to command the sdram controller to load address 8 bits at a time
    .spi_serpar_reg (spi_serpar_reg),     // 8-bit serpar register used for writing to the sdram address register
    .dram_read_enbl_spi (dram_read_enbl_spi),       // read enable request to DRAM controller
    .dram_write_enbl_spi (dram_write_enbl_spi),      // write enable request to DRAM controller
    .dram_writedata_spi (dram_writedata_spi),// 16-bit write data to DRAM controller
    .Cart_Ready (Cart_Ready),               // disk contents have been copied from the microSD to the SDRAM.
    .Read_Only (Read_Only),                // CPU register that indicates no writeback of updates to cartridge at shutdown
    .Fault_Latch (Fault_Latch),              // combines faults detected in Pico handling uSD files plus drive fault
    .Reset_Cylinder (Reset_Cylinder),           // drive powered down causes arm retract to cylinder 0
    .command_interrupt (command_interrupt)
);

`define ONE 1'b0
`define ZERO 1'b1

`define BIT(whazzit)   \
    @(negedge BUS_WT_CLOCKB_EMUL_L); \
    #40                        \
    BUS_WT_DATA_CLK_L <= 1'b0;  \
    @(posedge BUS_WT_CLOCKB_EMUL_L); \
    #40                        \
    BUS_WT_DATA_CLK_L <= whazzit;  

`define WORD(bf, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, e0, e1, e2, e3)  \
    @(negedge BUS_WT_CLOCKB_EMUL_L); \
    #40                        \
    BUS_WT_DATA_CLK_L <= 1'b0; \
    @(posedge BUS_WT_CLOCKB_EMUL_L); \
    #40                        \
    BUS_WT_DATA_CLK_L <= ~1'b``b15; \
    @(negedge BUS_WT_CLOCKB_EMUL_L); \
    #40                        \
    BUS_WT_DATA_CLK_L <= 1'b0; \
    @(posedge BUS_WT_CLOCKB_EMUL_L); \
    #40                        \
    BUS_WT_DATA_CLK_L <= ~1'b``b14; \
    @(negedge BUS_WT_CLOCKB_EMUL_L); \
    #40                        \
    BUS_WT_DATA_CLK_L <= 1'b0; \
    @(posedge BUS_WT_CLOCKB_EMUL_L); \
    #40                        \
    BUS_WT_DATA_CLK_L <= ~1'b``b13; \
    @(negedge BUS_WT_CLOCKB_EMUL_L); \
    #40                        \
    BUS_WT_DATA_CLK_L <= 1'b0; \
    @(posedge BUS_WT_CLOCKB_EMUL_L); \
    #40                        \
    BUS_WT_DATA_CLK_L <= ~1'b``b12; \
    @(negedge BUS_WT_CLOCKB_EMUL_L); \
    #40                        \
    BUS_WT_DATA_CLK_L <= 1'b0; \
    @(posedge BUS_WT_CLOCKB_EMUL_L); \
    #40                        \
    BUS_WT_DATA_CLK_L <= ~1'b``b11; \
    @(negedge BUS_WT_CLOCKB_EMUL_L); \
    #40                        \
    BUS_WT_DATA_CLK_L <= 1'b0; \
    @(posedge BUS_WT_CLOCKB_EMUL_L); \
    #40                        \
    BUS_WT_DATA_CLK_L <= ~1'b``b10; \
    @(negedge BUS_WT_CLOCKB_EMUL_L); \
    #40                        \
    BUS_WT_DATA_CLK_L <= 1'b0; \
    @(posedge BUS_WT_CLOCKB_EMUL_L); \
    #40                        \
    BUS_WT_DATA_CLK_L <= ~1'b``b9; \
    @(negedge BUS_WT_CLOCKB_EMUL_L); \
    #40                        \
    BUS_WT_DATA_CLK_L <= 1'b0; \
    @(posedge BUS_WT_CLOCKB_EMUL_L); \
    #40                        \
    BUS_WT_DATA_CLK_L <= ~1'b``b8; \
    @(negedge BUS_WT_CLOCKB_EMUL_L); \
    #40                        \
    BUS_WT_DATA_CLK_L <= 1'b0; \
    @(posedge BUS_WT_CLOCKB_EMUL_L); \
    #40                        \
    BUS_WT_DATA_CLK_L <= ~1'b``b7; \
    @(negedge BUS_WT_CLOCKB_EMUL_L); \
    #40                        \
    BUS_WT_DATA_CLK_L <= 1'b0; \
    @(posedge BUS_WT_CLOCKB_EMUL_L); \
    #40                        \
    BUS_WT_DATA_CLK_L <= ~1'b``b6; \
    @(negedge BUS_WT_CLOCKB_EMUL_L); \
    #40                        \
    BUS_WT_DATA_CLK_L <= 1'b0; \
    @(posedge BUS_WT_CLOCKB_EMUL_L); \
    #40                        \
    BUS_WT_DATA_CLK_L <= ~1'b``b5; \
    @(negedge BUS_WT_CLOCKB_EMUL_L); \
    #40                        \
    BUS_WT_DATA_CLK_L <= 1'b0; \
    @(posedge BUS_WT_CLOCKB_EMUL_L); \
    #40                        \
    BUS_WT_DATA_CLK_L <= ~1'b``b4; \
    @(negedge BUS_WT_CLOCKB_EMUL_L); \
    #40                        \
    BUS_WT_DATA_CLK_L <= 1'b0; \
    @(posedge BUS_WT_CLOCKB_EMUL_L); \
    #40                        \
    BUS_WT_DATA_CLK_L <= ~1'b``b3; \
    @(negedge BUS_WT_CLOCKB_EMUL_L); \
    #40                        \
    BUS_WT_DATA_CLK_L <= 1'b0; \
    @(posedge BUS_WT_CLOCKB_EMUL_L); \
    #40                        \
    BUS_WT_DATA_CLK_L <= ~1'b``b2; \
    @(negedge BUS_WT_CLOCKB_EMUL_L); \
    #40                        \
    BUS_WT_DATA_CLK_L <= 1'b0; \
    @(posedge BUS_WT_CLOCKB_EMUL_L); \
    #40                        \
    BUS_WT_DATA_CLK_L <= ~1'b``b1; \
    @(negedge BUS_WT_CLOCKB_EMUL_L); \
    #40                        \
    BUS_WT_DATA_CLK_L <= 1'b0; \
    @(posedge BUS_WT_CLOCKB_EMUL_L); \
    #40                        \
    BUS_WT_DATA_CLK_L <= ~1'b``bf; \
    @(negedge BUS_WT_CLOCKB_EMUL_L); \
    #40                        \
    BUS_WT_DATA_CLK_L <= 1'b0; \
    @(posedge BUS_WT_CLOCKB_EMUL_L); \
    #40                        \
    BUS_WT_DATA_CLK_L <= ~1'b``e0; \
    @(negedge BUS_WT_CLOCKB_EMUL_L); \
    #40                        \
    BUS_WT_DATA_CLK_L <= 1'b0; \
    @(posedge BUS_WT_CLOCKB_EMUL_L); \
    #40                        \
    BUS_WT_DATA_CLK_L <= ~1'b``e1; \
    @(negedge BUS_WT_CLOCKB_EMUL_L); \
    #40                        \
    BUS_WT_DATA_CLK_L <= 1'b0; \
    @(posedge BUS_WT_CLOCKB_EMUL_L); \
    #40                        \
    BUS_WT_DATA_CLK_L <= ~1'b``e2; \
    @(negedge BUS_WT_CLOCKB_EMUL_L); \
    #40                        \
    BUS_WT_DATA_CLK_L <= 1'b0; \
    @(posedge BUS_WT_CLOCKB_EMUL_L); \
    #40                        \
    BUS_WT_DATA_CLK_L <= ~1'b``e3; 



//============================ Start of Code =========================================
assign clock_dumbass = ~BUS_WT_CLOCKB_EMUL_L;
assign data_dumbass = ~BUS_WT_DATA_CLK_L;

// clock and reset
  initial begin
    clock = 1'b0;
    forever #12.5 clock = ~clock;
  end
  
    // ---------------------------------------------------------
    //  Combinational Glitch Injector
    // ---------------------------------------------------------
    // Triggers every time your combinational data line transitions
    always @(BUS_WT_CLOCKB_L, BUS_WT_DATA_CLK_L) begin
        
        if (BUS_WT_CLOCKB_L == 1'b0) begin
           data_glitched <= 1'b0;
        end
        // Roll a dice: 75% chance this transition causes a glitch
        else if ($urandom_range(0, 99) < 75) begin

            data_glitched <= BUS_WT_DATA_CLK_L;
            
	       // Step A: Wait a random amount of time between 40 and 100ns
       	    #($urandom_range(40, 100));

            // Step B: Let the path delay begin, but output a partial/wrong transition
            data_glitched <=  !BUS_WT_DATA_CLK_L; // Wrong state (glitch peak)
            
            // Step B: Hold the glitch for a random narrow window
            #($urandom_range(40, 200));      
            data_glitched <= BUS_WT_DATA_CLK_L;  // Finally settles to correct value
            
        end else begin
            // 25% chance: Line behaves perfectly with standard path delay
            #2;
            data_glitched <= BUS_WT_DATA_CLK_L;
        end
    end

  initial begin
     BUS_WT_CLOCKB_L <= 1'b1;
     forever
         begin
            @(negedge BUS_WT_CLOCKB_EMUL_L);
            BUS_WT_CLOCKB_L <= 1'b0;
            @(posedge BUS_WT_CLOCKB_EMUL_L);
            BUS_WT_CLOCKB_L <= 1'b1;
         end
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
//     dram_read_enbl_spi <= 1'b0;
//     dram_write_enbl_spi <= 1'b0;
     dram_read_enbl_busread <= 1'b0;
 //    spi_serpar_reg <= 8'd0;
//     load_address_spi <= 1'b0;
     load_address_busread <= 1'b0;
//     dram_writedata_spi <= 8'd0;
   end

// sector clk pulses
    initial begin 
      clkenbl_sector <= 1'b0;
      @(negedge reset);
      clkenbl_sector <= 1'b0;
      #165080
     forever begin
      clkenbl_sector <= 1'b0;
      #9999960
      clkenbl_sector <= 1'b1;
      #40
      clkenbl_sector <= 1'b0;
     end
    end
    
// sector pulses
  initial begin
    BUS_SECTOR_CTRL_L <= 1'b1;
    @(negedge reset)
    BUS_SECTOR_CTRL_L <= 1'b1;
    #165040
    forever 
      begin
       BUS_SECTOR_CTRL_L <= 1'b1;
       #4835000
       BUS_SECTOR_CTRL_L <= 1'b0;
       #165000
       BUS_SECTOR_CTRL_L <= 1'b1;
      end
  end
    

// drive our write gate
    initial begin
      @(negedge reset);
      BUS_WT_GATE_L <= 1'b1;
      #10000005
      BUS_WT_GATE_L <= 1'b0;
      #5000000
      BUS_WT_GATE_L <= 1'b1;
      #75
      BUS_WT_GATE_L <= 1'b0;
      #4721500
      BUS_WT_GATE_L <= 1'b1;
    end


// drive the sync bits pattern
     initial begin
        @(negedge reset);
        BUS_WT_DATA_CLK_L <= 1'b1;
        #10164900
        repeat(185)
        begin
            `BIT(`ZERO)
        end
        `BIT(`ONE )                  // 1 bit sync word 8000
        `BIT(`ONE )                  // 1 bit check bit 1
        `BIT(`ONE )                  // 1 bit check bit 2
        `BIT(`ONE )                  // 1 bit check bit 3
        `BIT(`ZERO)                  // 0 bit end of sync,check bit 4
// word one 6969
        `WORD(0, 1, 1, 0, 1, 0, 0, 1, 0, 1, 1, 0, 1, 0, 0, 1, 0, 0, 0, 0)
// word two 8000
        `WORD(1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0)
// word three  6969 
        `WORD(0, 1, 1, 0, 1, 0, 0, 1, 0, 1, 1, 0, 1, 0, 0, 1, 0, 0, 0, 0)
// word four 1313
        `WORD(0, 0, 0, 1, 0, 0, 1, 1, 0, 0, 0, 1, 0, 0, 1, 1, 1, 1, 0, 0)
// word five  1313
        `WORD(0, 0, 0, 1, 0, 0, 1, 1, 0, 0, 0, 1, 0, 0, 1, 1, 1, 1, 0, 0)
// word six 8000
        `WORD(1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0)
// word seven
        `WORD(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
// word eight
        `WORD(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 1, 1, 0)
// word nine
        `WORD(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 1, 1, 0, 0)
// word ten
        `WORD(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 1, 0, 0)
     repeat(309)
         begin
             `WORD(0, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0)
         end
// word 320 
        `WORD(0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0) 
// word 321
        `WORD(1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0)
// extra word
     `WORD(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
     end

// drive selection
     initial begin
  //       Cart_Ready <= 1'b1;
         Selected_Ready <= 1'b1;
         real_drive <= 1'b0;
     end

// SPI section

  // Tasks for modular SPI transactions
    task send_spi_byte;
        input [15:0] data_to_send;
        integer i;
        begin
            spi_cs_n = 1'b0; // Activate transaction
            #50;
            for (i = 15; i >= 8; i = i - 1) begin
                spi_mosi = data_to_send[i]; // Drive MOSI (Mode 0 setup)
                #100;
                spi_clk = 1'b1;            // Rising Edge (DUT samples & increments count)
                #100;
                spi_clk = 1'b0;            // Falling Edge (DUT updates MISO)
                spi_rx_byte[i] = spi_miso; // Sample returned data bit
            end
            #50;
            for (i = 7; i >= 0; i = i - 1) begin
                spi_mosi = data_to_send[i]; // Drive MOSI (Mode 0 setup)
                #100;
                spi_clk = 1'b1;            // Rising Edge (DUT samples & increments count)
                #100;
                spi_clk = 1'b0;            // Falling Edge (DUT updates MISO)
                spi_rx_byte[i] = spi_miso; // Sample returned data bit
            end
            #50;
            spi_cs_n = 1'b1; // Deactivate transaction
            #200;            // Wait before next byte
        end
   endtask

// Main Simulation Block
    initial begin

        // Initialize Inputs
        spi_clk = 0;
        spi_cs_n = 1;
        spi_mosi = 0;
 

        // TEST 1: Perform a Write operation to verify `spi_serpar_reg` update
#1000
        send_spi_byte(16'ha000);
#1000
        send_spi_byte(16'h0050);
#1000
        send_spi_byte(16'ha000);
        #5000

        send_spi_byte(16'h0509);
        #1000
        send_spi_byte(16'h0511);
        #1000
        send_spi_byte(16'h0500);
        
        #6000
        send_spi_byte(16'h0634);
        #1000
        send_spi_byte(16'h0612);
                
        #6000
        send_spi_byte(16'h0669);
        #1000
        send_spi_byte(16'h0669);
                
        #21000000
        send_spi_byte(16'h050a);
        #1000
        send_spi_byte(16'h0516);
        #1000
        send_spi_byte(16'h0500);
        
        #4000        
        send_spi_byte(16'h8800);
         #4000        
        send_spi_byte(16'h8800);
       
//        send_spi_byte(16'h8200);

        // TEST 2: write Register 00
//        send_spi_byte(16'h0000);
        
        // Second transaction clocks out the data associated with address 8'h00
//        send_spi_byte(16'ha000); // Send dummy byte while listening to MISO

  end
endmodule // End of Module TB_bus_disk_read

// Behavioral model of Lattice SB_DFFS for standalone simulation
module SB_DFFS (
    output reg Q,
    input wire C,
    input wire D,
    input wire S
);
    always @(posedge C or posedge S) begin
        if (S) begin
            Q <= 1'b1;
        end else begin
            Q <= D;
        end
    end
endmodule
`timescale 1ns/1ps

module tb_glitch_generator;

    reg  data_ideal;       // Clean combinational logic driver from testbench
    wire data_to_dut;      // The actual line connected to your DUT input
    
    reg  data_glitched;    // Internal register to hold the glitchy state
    assign data_to_dut = data_glitched;

    // ---------------------------------------------------------
    // 1. Clean Combinational Data Driver (Your Testbench Stimulus)
    // ---------------------------------------------------------
    initial begin
        data_ideal = 0;
        
        // Generate random test vectors at varying intervals
        forever begin
            #($urandom_range(40, 100)); 
            data_ideal = $urandom_range(0, 1);
        end
    end

    // ---------------------------------------------------------
    // 2. Combinational Glitch Injector
    // ---------------------------------------------------------
    // Triggers every time your combinational data line transitions
    always @(data_ideal) begin
        
        // Roll a dice: 40% chance this transition causes a glitch
        if ($urandom_range(0, 99) < 40) begin
            
            // Step A: Let the path delay begin, but output a partial/wrong transition
            #2; 
            data_glitched <= !data_ideal; // Wrong state (glitch peak)
            
            // Step B: Hold the glitch for a random narrow window
            #($urandom_range(1, 4));      
            data_glitched <= data_ideal;  // Finally settles to correct value
            
        end else begin
            // 60% chance: Line behaves perfectly with standard path delay
            #2;
            data_glitched <= data_ideal;
        end
    end

endmodule
