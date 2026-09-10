//==========================================================================================================
// RK05 Emulator
// write disk from the BUS
// File Name: bus_disk_write.v
// Functions: 
//   emulates writing to the disk from the interface bus.
//   When BUS_WT_GATE_L goes active (low) then extract serial data from the BUS_WT_DATA_CLK_L and write it to the SDRAM. 
// Modified for 2310 by Carl Claunch
//
//==========================================================================================================

module bus_disk_write(
    input wire clock,                  // master clock 40 MHz
    input wire reset,                  // active high synchronous reset input
    input wire BUS_WT_GATE_L,          // Write gate and Clock gate, when active enables write circuitry
    input wire BUS_WT_DATA_CLK_L,      // Composite write data and write clock
//    input wire BUS_WT_CLOCKB_L,        // Bit cell data phase gate, when high is data bit time
    input wire Selected_Ready,         // disk contents have been copied from the microSD to the SDRAM & drive selected & ~fault latch
    input wire BUS_SECTOR_L,           // sector pulse
    input wire clkenbl_sector,         // sector enable pulse
    input wire real_drive,             // on if a physical 2310 drive is used
    input wire dram_writeack,          // acknowledge from DRAM write cycle
    input wire Cart_Ready,             // we have a virtual cartridge ready

    output reg dram_write_enbl_buswrite,       // read enable request to DRAM controller
    output reg [15:0] dram_writedata_buswrite, // 16-bit write data to DRAM controller
    output reg load_address_buswrite,          // enable to command the sdram controller to load the address from sector, head select and cylinder
    output wire dram_addr_incr_buswrite,       // address increment enable in buswrite function
    output reg write_indicator,                // active high signal to drive the WT front panel indicator
    output reg ECC_error,                      // routed to the Fault indicator on the front panel
    output reg BUS_WT_CLOCKB_EMUL_L,            // produced 720KHz if not real drive
    output reg write_selected_ready            // output of module
); // End of port list

//============================ Internal Connections ==================================

// state definitions and values for the read state
`define BWST0 2'd0 // 0 - off
`define BWST1 2'd1 // 1 - receive Preamble and Sync
`define BWST2 2'd2 // 2 - receive Data & CRC
`define BWST3 2'd3 // 3 - receive Postamble

// IBM 1130 2310 20 bit words, 321 words with no CRC, 4 logical sectors (8 physical)
// data word is 16 bits, ECC is 1 bits emitted in last four until count mod 4 is 0

reg [1:0] bus_write_state; // read state machine state variable
reg [4:0] bus_write_count; // count bits in a word
reg [11:0] wordcount; // counter to keep track of the number of data & CRC words, in 16-bit increments
reg [15:0] sp_reg; // parallel-to-serial register, receive data LSB first
reg [4:0] datsep_count;    // data separator counter
reg oldBUS_WT_DATA_CLK_L;  // prior version of BUS_WT_DATA_CLK_L
reg catch_one;       // latch the data pulse if it happens
reg oldBUS_SECTOR_L;  // prior version of BUS_SECTOR_L
wire WT_CLOCKB_L;       // clock sent to CPU
reg oldWT_CLOCKB_L;    // saved prior version of the clock to detect edges
reg [5:0] write_tick_counter; // counter to produce a visible flicker of the WT indicator
reg write_gate_safe; // synchronous signal that indicates Write Gate is active
reg [7:0]  sync_bit_count;    // count bits during sync word tail end
reg sync_trigger;             // turn on when we see first 1 bit of the sync word
reg [1:0]  ECC_count;         // count one bits for ECC generation
reg [5:0]  clockb_timer;      // produce 714KHz clock dividing clock by 27
wire debounced_gate;           // debounced BUS_ 

// IBM 1130 use of 2310 turns on a 1.44 MHz clock in the drive which is also sent to the CPU controller logic
// first turn on -Clock Gate to start the oscillator
// with clock gate on, we get out of phase clock A and clock B signals at 720 KHz (bit cell)
// then turn on -Write Gate to begin actual writing, but this is tied to -Clock Gate on the 1130 system
//
// clock pulse is always produced with -Clock B low, ignoring the value on -Write Data
// data pulse if -Write Data is low when -Clock B is high, a 1 data bit, otherwise nothing done
// set up -Write Data with the data value to be written in a bit cell, switching while -Clock B is low

// to retrieve the data bits, we only have to look at -Clock B high transition while -write gate is on
// much less complex than the data seperator mechanism used with the RK-05 controllers
// to be safe will wait a few ticks after -Clock B goes high then sample the -Write Data line
//
// the controller will continue to write zeros to the disk until the next sector pulse
// however we don't care as there is no information to capture to put on DRAM


//============================ Start of Code =========================================

assign dram_addr_incr_buswrite = dram_writeack;
assign WT_CLOCKB_L = BUS_WT_CLOCKB_EMUL_L;

always @ (posedge clock)
begin : DISKWRITE // block name

  if(reset==1'b1) begin
    bus_write_state <= `BWST0;
    dram_write_enbl_buswrite <= 1'b0;
    dram_writedata_buswrite <= 16'd0;
    load_address_buswrite <= 1'b0;
    bus_write_count <= 5'd0;
    wordcount <= 12'd0;
    sp_reg <= 16'd0;
    datsep_count <= 5'd0;
    catch_one <= 1'b0;
    write_tick_counter <= 0;
    write_gate_safe <= 0;
    sync_bit_count <= 8'd0;
    sync_trigger <= 1'b0;
    ECC_count <= 2'd0;
    ECC_error <= 1'b0;
    BUS_WT_CLOCKB_EMUL_L <= 1'b1;
    oldBUS_WT_DATA_CLK_L  <= 1'b1;
    oldWT_CLOCKB_L <= 1'b1;
    oldBUS_SECTOR_L <= 1'b1;
    clockb_timer <= 6'd28;
    write_selected_ready <= 1'b0;
  end
  else begin

    write_gate_safe <=  ~debounced_gate && Cart_Ready;

    write_tick_counter <= (bus_write_state == `BWST1) 
                          ? 16 
                          : (clkenbl_sector 
                            ? ((write_tick_counter == 0) 
                              ? 0 
                              : write_tick_counter - 1) 
                            : write_tick_counter);

    write_indicator <= (write_tick_counter != 0);

    // wait 16 clock counts after WT_CLOCKB_L goes high then capture the data bit value 
    datsep_count <= (WT_CLOCKB_L && ~oldWT_CLOCKB_L) 
                    ? 5'd18
                    : (datsep_count != 0) 
                      ? datsep_count - 1 
                      : 5'd0;
    
    // sample the value of WT_DATA_CLK_L 400ns past when WT_CLOCKB_L went high
    catch_one <= datsep_count == 2
                 ? ~BUS_WT_DATA_CLK_L 
                 : catch_one;
    
    // Shift the captured data bit into bit 15 of the serial-to-parallel converter register at rising edge WT_CLOCKB_L
    sp_reg[15:0] <= (WT_CLOCKB_L && ~oldWT_CLOCKB_L) && bus_write_state == `BWST2 && bus_write_count > 3
                    ?  {catch_one, sp_reg[15:1]} 
                    :  dram_write_enbl_buswrite == 1'b1
                       ? 16'd0
                       :sp_reg[15:0];

    // operate 725Khz timer
    clockb_timer <= clockb_timer == 0
                       ? 5'd29
                       : clockb_timer - 1;

    // produce 725KHz signal for ClockB in all cases but only if write gate is on
    // default condition is low, thus 1130s BUS_WT_DATA_CLK_CTRL_L is steady high
    BUS_WT_CLOCKB_EMUL_L <= clockb_timer == 0
                             ? (BUS_WT_CLOCKB_EMUL_L && write_gate_safe)
                             : (~BUS_WT_CLOCKB_EMUL_L && write_gate_safe);

    // save old BUS_WT_DATA_CLK_L to detect edge
    oldBUS_WT_DATA_CLK_L  <= BUS_WT_DATA_CLK_L;

    // save old WT_CLOCK_L to detect edge
    oldWT_CLOCKB_L <= WT_CLOCKB_L;

    // save old BUS_SECTOR_L to detect edge
    oldBUS_SECTOR_L <= BUS_SECTOR_L;

    case(bus_write_state)

// 0 - write and erase heads are off, waiting for the write gate and end of sector pulse
    `BWST0: begin    
 
      bus_write_state <= (Selected_Ready == 1'b1 && write_gate_safe == 1'b1 && BUS_SECTOR_L == 1'b1 && oldBUS_SECTOR_L == 1'b0) 
                         ? `BWST1 
                         : `BWST0;

      dram_write_enbl_buswrite <= 1'b0;
      dram_writedata_buswrite <= 16'd0;
      load_address_buswrite <= 1'b0;
      bus_write_count <= 5'd0; // set to zero, not used until BWST1
      wordcount <= 12'd0; // set to zero, not used until BWST1
      sync_bit_count <= 8'd4;
      sync_trigger <= 1'b0;

      write_selected_ready <= 1'b0;

      // reset error when disk unloaded
      ECC_error <= Cart_Ready == 1'b1
                   ?  ECC_error
                   :  1'b0;

     end

// 1 - accept Preamble and Sync word
    `BWST1: begin  

      // on falling edge of WT_CLOCKB_L see if we had a 1 bit before
      // that is our first 1 bit - the sync word
      sync_trigger <=  WT_CLOCKB_L && ~oldWT_CLOCKB_L && catch_one
                          ? 1'b1
                          : sync_trigger;

      // when sync trigger is on, count next three bit cells at rising edge of WT_CLOCKB_L
      sync_bit_count <=  ~WT_CLOCKB_L && oldWT_CLOCKB_L && sync_trigger
                          ? (sync_bit_count > 1
                            ? sync_bit_count - 1
                            : 8'd0)
                          : sync_bit_count;

      // change state at falling edge of WT_CLOCKB_L
      bus_write_state <= write_gate_safe 
                         ? (~WT_CLOCKB_L && oldWT_CLOCKB_L)
                           ?   ( sync_bit_count > 0
                               ?`BWST1
                               :`BWST2)
                           : `BWST1 
                         : `BWST0;

      dram_write_enbl_buswrite <= 1'b0;
      dram_writedata_buswrite <= 16'd0;

      // set up write address at falling edge of WT_CLOCKB_L
      load_address_buswrite <= ~WT_CLOCKB_L && oldWT_CLOCKB_L && sync_bit_count == 0;

      // begin count at falling edge of WT_CLOCKB_L when sync bits finished
      bus_write_count <= ~WT_CLOCKB_L && oldWT_CLOCKB_L && sync_bit_count == 0 
                         ? 5'd19 
                         : 5'd0; 

      wordcount <= 12'd321; // set to the number of words to be transferred, which is bit length/16

      ECC_error <= 1'b0;

      write_selected_ready <= 1'b1;

     end

// 2 - grab the Data words
    `BWST2: begin 

      // change state at rising edge of WT_CLOCKB_L, finish when wordcount exhausted
      bus_write_state <= write_gate_safe 
                         ? (WT_CLOCKB_L && ~oldWT_CLOCKB_L && (wordcount == 0) 
                           ? `BWST3 
                           : `BWST2) 
                         : `BWST0;

      // write a word at rising edge of BUS_W&T_CLOCKB_L when count of bits captured hits zero
      dram_write_enbl_buswrite <= WT_CLOCKB_L & ~oldWT_CLOCKB_L && (bus_write_count == 0);

      // change the output register for DRAM write 
      dram_writedata_buswrite <= WT_CLOCKB_L && ~oldWT_CLOCKB_L && (bus_write_count == 0) ? sp_reg : dram_writedata_buswrite;

      load_address_buswrite <= 1'b0;

      // at falling edge of WT_CLOCKB_L we count off bits
      bus_write_count <= ~WT_CLOCKB_L && oldWT_CLOCKB_L
                         ? (bus_write_count == 0 
                           ? 5'd19 
                           : bus_write_count - 1)
                         : bus_write_count;

      // at falling edge of WT_CLOCKB_L count words when bits all captured
      wordcount <= ~WT_CLOCKB_L & oldWT_CLOCKB_L && (bus_write_count == 0) 
                  ? wordcount - 1
                  : wordcount;

      // accumulate one bits during word, caught at rising edge of WT_CLOCKB_L
      ECC_count <= WT_CLOCKB_L && ~oldWT_CLOCKB_L
                   ? (bus_write_count == 0)
                     ? 2'd0 
                     : ECC_count + catch_one 
                   : ECC_count;

      // at rising edge of WT_CLOCKB_L if bits done, check for ECC error
      ECC_error <= WT_CLOCKB_L && ~oldWT_CLOCKB_L && (bus_write_count == 0)
                   ? ECC_count == 2'd0
                      ? ECC_error
                      : 1'b1
                   : ECC_error;

      write_selected_ready <= 1'b1;

     end

// 3 - ignore Postamble
    `BWST3: begin     

      // controller will keep sending zero bits, we just silently ignore until the write gate is dropped
      bus_write_state <= debounced_gate 
                         ? `BWST3 
                         : `BWST0;

      dram_write_enbl_buswrite <= 1'b0;

      dram_writedata_buswrite <= dram_write_enbl_buswrite 
                                 ? sp_reg 
                                 : dram_writedata_buswrite;

      load_address_buswrite <= 1'b0;

      // at rising edge of WT_CLOCKB_L count bits
      bus_write_count <= ~oldBUS_WT_DATA_CLK_L && BUS_WT_DATA_CLK_L && (datsep_count < 4)  // CVC
                         ? (bus_write_count == 0 
                           ? 5'd19 
                           : bus_write_count - 1)
                         : bus_write_count;

      wordcount <= 12'd0;

      write_selected_ready <= 1'b1;

     end


    endcase

  end
end // End of Block DISKWRITE

// ======== Debouncer Module for BUS_WT_GATE_L ========
debouncer BUS_WT_GATE_debouncer (
    // Inputs
    .clock (clock),
    .reset (reset),
    .input_data (BUS_WT_GATE_L),
    .initial_state (1'b1),

    // Outputs
    .debounced_data (debounced_gate)
);

// ======== Serializer Module for BUS_WT_CLOCKB_EMUL_L ========
//serializer BUS_WT_CLOCKB_EMUL_L_serializer (
//    // Inputs
//    .clock (clock),
//    .reset (reset),
//    .input_data (BUS_WT_CLOCKB_EMUL_L),
//    .initial_state (1'b1),

//    // Outputs
//    .serialized (WT_CLOCKB_L)
//);


endmodule // End of Module bus_disk_write
