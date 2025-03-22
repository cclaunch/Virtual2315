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
    input wire BUS_WT_DATA_CLK_CTRL_L, // Composite write data and write clock
    input wire BUS_WT_CLOCKB_L,        // Bit cell data phase gate, when high is data bit time
    input wire Selected_Ready,         // disk contents have been copied from the microSD to the SDRAM & drive selected & ~fault latch
    input wire BUS_SECTOR_CTRL_L,      // sector pulse
    input wire clkenbl_sector,         // sector enable pulse
    input wire real_drive,             // on if a physical 2310 drive is used
    input wire dram_writeack,          // acknowledge from DRAM write cycle

    output reg dram_write_enbl_buswrite,       // read enable request to DRAM controller
    output reg [15:0] dram_writedata_buswrite, // 16-bit write data to DRAM controller
    output reg load_address_buswrite,          // enable to command the sdram controller to load the address from sector, head select and cylinder
    output wire dram_addr_incr_buswrite,       // address increment enable in buswrite function
    output reg write_indicator,                // active high signal to drive the WT front panel indicator
    output reg write_selected_ready,           // for command interrupt
    output reg ECC_error,                      // routed to the Fault indicator on the front panel
    output reg BUS_WT_CLOCKB_EMUL_L            // produced 720KHz if not real drive
); // End of port list

//============================ Internal Connections ==================================

// state definitions and values for the read state
`define BWST0 3'd0 // 0 - off
`define BWST1 3'd1 // 1 - receive Preamble and Sync
`define BWST3 3'd3 // 3 - receive Data & CRC
`define BWST4 3'd4 // 4 - receive Postamble

// IBM 1130 2310 20 bit words, 321 words with no CRC, 4 logical sectors (8 physical)
// data word is 16 bits, ECC is 1 bits emitted in last four until count mod 4 is 0

reg [2:0] bus_write_state; // read state machine state variable
reg [4:0] bus_write_count; // count bits in a word
reg [11:0] wordcount; // counter to keep track of the number of data & CRC words, in 16-bit increments
reg [15:0] sp_reg; // parallel-to-serial register, receive data LSB first
//reg clkenbl_write_bit;  // enable for disk write clock
reg [4:0] datsep_count;    // data separator counter
reg catch_one;       // latch the data pulse if it happens
reg [3:0] metawrgate; // de-metastable flops for write gate
reg [3:0] metaspgate; // de-metastable flops for sector pulse
reg [3:0] metawcgate; // de-metastable flops for write clock B
reg [3:0] metaclkdata; // de-metastable flops for composite clock and data
reg [5:0] write_tick_counter; // counter to produce a visible flicker of the WT indicator
reg write_gate_safe; // synchronous signal that indicates Write Gate is active
reg [7:0]  sync_bit_count;    // count bits during sync word tail end
reg sync_trigger;             // turn on when we see first 1 bit of the sync word
reg [1:0]  ECC_count;         // count one bits for ECC generation
reg [5:0]  clockb_timer;      // produce 714KHz clock dividing clock by 27

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

always @ (posedge clock)
begin : DISKWRITE // block name
  write_selected_ready <= write_gate_safe && Selected_Ready;

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
    metawrgate <= 4'b1111;
    metaspgate <= 4'b1111;
    metawcgate <= 4'b1111;
    metaclkdata <= 4'b1111;
    write_tick_counter <= 0;
    write_gate_safe <= 0;
    sync_bit_count <= 8'd0;
    sync_trigger <= 1'b0;
    ECC_count <= 2'd0;
    ECC_error <= 1'b0;
    BUS_WT_CLOCKB_EMUL_L <= 1'b1;
    clockb_timer <= 6'd28;
  end
  else begin
    // fix for metastability risk of external signals not aligned to clock domain
    metawrgate[3:0] <= {metawrgate[2:0], BUS_WT_GATE_L};
    metawcgate[3:0] <= {metawcgate[2:0], BUS_WT_CLOCKB_L};
    metaclkdata[3:0] <= {metaclkdata[2:0], BUS_WT_DATA_CLK_CTRL_L};
    metaspgate[3:0] <= {metaspgate[2:0], BUS_SECTOR_CTRL_L};


    write_gate_safe <=  ~metawrgate[3];

    write_tick_counter <= (write_gate_safe && Selected_Ready) 
                          ? 16 
                          : (clkenbl_sector 
                            ? ((write_tick_counter == 0) 
                              ? 0 
                              : write_tick_counter - 1) 
                            : write_tick_counter);

    write_indicator <= (write_tick_counter != 0);

    // wait 16 clock counts after BUS_WT_CLOCKB_L goes high then capture the data bit value 
    datsep_count <= (metawcgate[2] & ~metawcgate[3] 
                    ? 5'd18 
                    : (datsep_count != 0 
                      ? datsep_count - 1 
                      : 5'd0));
    
    // sample the value of BUS_WT_DATA_CLK_L 400ns past when BUS_WT_CLOCKB_L went high
    catch_one <= datsep_count == 2
                 ? ~metaclkdata[3] 
                 : catch_one;
    
    // Shift the captured data bit into bit 15 of the serial-to-parallel converter register at rising edge BUS_WT_CLOCKB_L
    sp_reg[15:0] <= (metawcgate[2] & ~metawcgate[3]) && bus_write_state == `BWST3 && bus_write_count > 2
                    ?  {catch_one, sp_reg[15:1]} 
                    :  dram_write_enbl_buswrite == 1'b1
                       ? 16'd0
                       :sp_reg[15:0];

    // operate 725Khz timer
    clockb_timer <= clockb_timer == 0
                       ? 5'd28
                       : clockb_timer - 1;

    // produce 725KHz signal for ClockB if we are not using a real drive
    BUS_WT_CLOCKB_EMUL_L <= (real_drive == 1'b0) && (BUS_WT_GATE_L == 1'b0)
                        ? clockb_timer == 0
                             ? ~BUS_WT_CLOCKB_EMUL_L
                             : BUS_WT_CLOCKB_EMUL_L
                        : 1'b1;

    case(bus_write_state)

// 0 - write and erase heads are off, waiting for the write gate and end of sector pulse
    `BWST0: begin    
 
      bus_write_state <= (Selected_Ready == 1'b1 && write_gate_safe == 1'b1 && metaspgate[3] == 1'b0 && metaspgate[2] == 1'b1) 
                         ? `BWST1 
                         : `BWST0;

      dram_write_enbl_buswrite <= 1'b0;
      dram_writedata_buswrite <= 16'd0;
      load_address_buswrite <= 1'b0;
      bus_write_count <= 5'd0; // set to zero, not used until BWST1
      wordcount <= 12'd0; // set to zero, not used until BWST1
      sync_bit_count <= 8'd4;
      sync_trigger <= 1'b0;

     end

// 1 - accept Preamble and Sync word
    `BWST1: begin  

      // on falling edge of BUS_WT_CLOCKB_L see if we had a 1 bit before
      // that is our first 1 bit - the sync word
      sync_trigger <=  metawcgate[3] & ~metawcgate[2] & catch_one
                          ? 1'b1
                          : sync_trigger;

      // when sync trigger is on, count next three bit cells at rising edge of BUS_WT_CLOCKB_L
      sync_bit_count <=  ~metawcgate[3] & metawcgate[2] & sync_trigger
                          ? (sync_bit_count > 1
                            ? sync_bit_count - 1
                            : 8'd0)
                          : sync_bit_count;

      // change state at falling edge of BUS_WT_CLOCKB_L
      bus_write_state <= write_gate_safe 
                         ? (~metawcgate[2] & metawcgate[3])
                           ?   ( sync_bit_count > 0
                               ?`BWST1
                               :`BWST3)
                           : `BWST1 
                         : `BWST0;

      dram_write_enbl_buswrite <= 1'b0;
      dram_writedata_buswrite <= 16'd0;

      // set up write address at falling edge of BUS_WT_CLOCKB_L
      load_address_buswrite <= ~metawcgate[2] & metawcgate[3] & sync_bit_count == 0;

      // begin count at falling edge of BUS_WT_CLOCKB_L when sync bits finished
      bus_write_count <= ~metawcgate[2] & metawcgate[3] & sync_bit_count == 0 
                         ? 5'd19 
                         : 5'd0; 

      wordcount <= 12'd321; // set to the number of words to be transferred, which is bit length/16

      ECC_error <= 1'b0;

     end

// 3 - grab the Data words
    `BWST3: begin 

      // change state at rising edge of BUS_WT_CLOCKB_L, finish when wordcount exhausted
      bus_write_state <= write_gate_safe 
                         ? (metawcgate[2] & ~metawcgate[3] & (wordcount == 0) 
                           ? `BWST4 
                           : `BWST3) 
                         : `BWST0;

      // write a word at rising edge of BUS_WT_CLOCKB_L when count of bits captured hits zero
      dram_write_enbl_buswrite <= metawcgate[2] & ~metawcgate[3] & (bus_write_count == 0);

      // change the output register for DRAM write 
      dram_writedata_buswrite <= metawcgate[2] & ~metawcgate[3] & (bus_write_count == 0) ? sp_reg : dram_writedata_buswrite;

      load_address_buswrite <= 1'b0;

      // at falling edge of BUS_WT_CLOCKB_L we count off bits
      bus_write_count <= metawcgate[3] & ~metawcgate[2]
                         ? (bus_write_count == 0 
                           ? 5'd19 
                           : bus_write_count - 1)
                         : bus_write_count;

      // at falling edge of BUS_WT_CLOCKB_L count words when bits all captured
      wordcount <= ~metawcgate[2] & metawcgate[3]  & (bus_write_count == 0) 
                  ? wordcount - 1
                  : wordcount;

      // accumulate one bits during word, caught at falling edge of BUS_WT_CLOCKB_L
      ECC_count <= ~metawcgate[2] & metawcgate[3]
                   ? (bus_write_count == 0)
                     ? 2'd0 
                     : ECC_count + catch_one 
                   : ECC_count;

      // at rising edge of BUS_WT_CLOCKB_L if bits done, check for ECC error
      ECC_error <= metawcgate[2] & ~metawcgate[3] & (bus_write_count == 0)
                   ? ECC_count == 2'd0
                      ? ECC_error
                      : 1'b1
                   : ECC_error;

     end

// 4 - ignore Postamble
    `BWST4: begin     

      // controller will keep sending zero bits, we just silently ignore until the write gate is dropped
      bus_write_state <= write_gate_safe 
                         ? `BWST4 
                         : `BWST0;

      dram_write_enbl_buswrite <= 1'b0;

      dram_writedata_buswrite <= dram_write_enbl_buswrite 
                                 ? sp_reg 
                                 : dram_writedata_buswrite;

      load_address_buswrite <= 1'b0;

      // at rising edge of BUS_WT_CLOCKB_L count bits
      bus_write_count <= ~metaclkdata[2] & metaclkdata[3] & (datsep_count < 4) 
                         ? (bus_write_count == 0 
                           ? 5'd19 
                           : bus_write_count - 1)
                         : bus_write_count;

      wordcount <= 12'd0;

     end

    default: begin
      bus_write_state <= `BWST0;
    end

    endcase

  end
end // End of Block DISKWRITE

endmodule // End of Module bus_disk_write
