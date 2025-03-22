
//==========================================================================================================
// RK05 Emulator
// read disk from the BUS
// File Name: bus_disk_read.v
// Functions: 
//   emulates reading the disk from the interface bus.
//   When BUS_RD_GATE_L goes active (low) then read data from the SDRAM and generate the read data and read clock waveforms. 
// Modified for IBM 2310 by Carl Claunch
//
//==========================================================================================================

module bus_disk_read(
    input wire clock,             // master clock 40 MHz
    input wire reset,             // active high synchronous reset input
    input wire BUS_RD_GATE_L,     // Read gate, when active enables read circuitry
    input wire clkenbl_read_bit,  // enable for disk read clock
    input wire clkenbl_read_data, // enable for disk read data
    input wire clock_pulse,       // clock pulse with proper 160 us width from drive
    input wire data_pulse,        // data pulse with proper 160 us width from drive
    input wire [15:0] dram_readdata, // 16-bit read data from DRAM controller
    input wire Selected_Ready,    // disk contents have been copied from the microSD to the SDRAM & drive selected & ~fault latch
    input wire clkenbl_sector,         // sector enable pulse
    input wire BUS_SECTOR_CTRL_L,      // sector pulse

    output reg dram_read_enbl_busread, // read enable request to DRAM controller
    output reg BUS_RD_DATA_H,          // Read data pulses
    output reg BUS_RD_CLK_H,           // Read clock pulses
    output reg load_address_busread,   // enable to command the sdram controller to load the address from sector, head select and cylinder
    output reg read_indicator,         // active high signal to drive the RD front panel indicator
    output reg read_selected_ready     // read strobe and selected_ready for command interrupt
);

//============================ Internal Connections ==================================

// state definitions and values for the read state
`define BRST0 3'd0 // 0 - off
`define BRST1 3'd1 // 1 - send Preamble
`define BRST2 3'd2 // 2 - send Sync
`define BRST4 3'd4 // 4 - send Data & CRC     no CRC with 2310
`define BRST5 3'd5 // 5 - send Postamble      
reg [2:0] bus_read_state; // read state machine state variable

// IBM 1130 2310 20 bit words, 321 words with no CRC, 4 logical sectors (8 physical)
// data word is 16 bits, ECC is 1 bits emitted in last four until count mod 4 is 0
//
// read begins when -Read Gate goes low (at the end of a sector pulse
// we emit 250 us of zeroes (clock pulses with no data pulses) as preamble
// we then send the sync word - a word with value 0000000000000001 plus check bits 1110
// following sync we grab data from DRAM and send it out on the clock and data lines
// 
// for each word we bump a two bit counter for each 1 data bit we send
// this will be 00 when the count of 1 bits is evenly divisible by four
//
// we have to emit the 16 bit cells for the data then emit the four check bits
// they are emitted as 1 and the counter bumped till it hits 00 then we send 0 bits
//
// the postamble should be all zero bit values until the next sector arrives
// 
// our output of BUS_RD_CLK_H and BUS_RD_DATA_H values always stops when -Read Gate goes high

reg [7:0]  bus_read_count; // count bits in a word or Preamble length
reg [3:0]  metagate; // de-metastable flops for read gate
reg [15:0] psreg; // parallel-to-serial register, send data LSB first
reg [11:0] wordcount; // counter to keep track of the number of data words, in 16-bit increments
reg [5:0]  read_tick_counter; // counter to produce a visible flicker of the RD indicator
reg [7:0]  sync_word_count;   // count bits during sync word tail end
reg [1:0]  ECC_count;         // count one bits for ECC generation
reg        ECC_bit;           // bit to emit for ECC
reg [3:0]  metasector;        // de-metastable flops for sector pulse

//============================ Start of Code =========================================

always @ (posedge clock)
begin : DISKREAD // block name
  read_selected_ready <= Selected_Ready && metagate[3];

  if(reset==1'b1) begin
    dram_read_enbl_busread <= 1'b0;
    BUS_RD_DATA_H <= 1'b0;
    BUS_RD_CLK_H <= 1'b0;
    load_address_busread <= 1'b0;
    bus_read_state <= `BRST0;
    bus_read_count <= 8'd0;
    metagate <= 4'b0000;
    metasector <= 4'b0000;
    wordcount <= 12'd0;
    psreg <= 16'd0;
    read_tick_counter <= 0;
    sync_word_count <= 8'd0;
    ECC_count <= 2'd0;
    ECC_bit <= 1'd0;
  end
  else begin
    // handle clock domain crossing
    metagate[3:0] <= {metagate[2:0], ~BUS_RD_GATE_L};
    metasector[3:0] <= {metasector[2:0], ~BUS_SECTOR_CTRL_L};

    // run counter to manage lamp flicker for read indicator
    read_tick_counter <= (metagate[3] && Selected_Ready) 
                         ? 16 
                         : (clkenbl_sector 
                                ? ((read_tick_counter == 0) 
                                        ? 0 
                                        : read_tick_counter - 1) 
                                : read_tick_counter);

    // turn on read indicator 15 of 16 sector pulses
    read_indicator <= (read_tick_counter != 0);

    case(bus_read_state)
// transmission is off, waiting for the read gate
    `BRST0: begin     
      // when to move out of idle state (read gate on, sector pulse over and we saw a read or clock bit)
      bus_read_state <= (Selected_Ready && metagate[3] && metasector[3] == 1'b0 && (clkenbl_read_bit || clkenbl_read_data)) 
                        ? `BRST1 
                        : `BRST0;

      // ready to send preamble2_length bits of Preamble before Sync
      bus_read_count <= (Selected_Ready && metagate[3] && metasector[3] == 1'b0 && (clkenbl_read_bit || clkenbl_read_data)) 
                        ? 8'd195 
                        : 8'd0; 

      // emit nothing while idle
      BUS_RD_CLK_H <= 1'b0; // send all-zeros, no clocks, when off
      BUS_RD_DATA_H <= 1'b0;  // send all-zeros, no data pulses, when off

      // reset shift register and word count
      psreg <= 16'd0;
      wordcount <= 12'd0;

      // turn off ram read
      load_address_busread <= 1'b0;
      dram_read_enbl_busread <= 1'b0; 

      sync_word_count <= 0;
     end
// send Preamble of all 0's
    `BRST1: begin     
      // clock pulse always passed through
      BUS_RD_CLK_H <= clock_pulse;

      // send all-zeros in the Preamble
      BUS_RD_DATA_H <= 1'b0;  

      // decrement bit count at time for data bit emission
      bus_read_count <= clkenbl_read_data 
                        ? bus_read_count - 1 
                        : bus_read_count;

      // move to sync word when our preamble count goes to 1
      bus_read_state <= metagate[3] 
                        ? (((bus_read_count == 8'd1) && clkenbl_read_data) 
                               ? `BRST2 
                               : `BRST1) 
                        : `BRST0;

      // zero out shift register and word count
      psreg <= 16'd0;
      wordcount <= 12'd0;

      // load sdram address register near end of Preamble
      load_address_busread <= (bus_read_count == 8'd32) & clkenbl_read_data; 

      // first read will occur automatically after the address register is loaded 
      // and be ready in time for sending the first word
      // thus don't request a read now
      dram_read_enbl_busread <= 1'b0;

     end

// send the Sync bit
    `BRST2: begin     
      // always emit clocks
      BUS_RD_CLK_H <= clock_pulse;

      // emit 1 bits for sync word plus ECC first three bits
      BUS_RD_DATA_H <= ((sync_word_count == 8'd4) 
                       ? 1'b0
                       : data_pulse); 

      // set up for usual 20 bit word in data state `BRST3
      bus_read_count <= 8'd20;

      // move on but after correct number of one and zero bits for ECC
      // correct ECC is 1110 for the sync word
      sync_word_count <= clkenbl_read_data 
                         ? ((sync_word_count == 4) 
                                 ? 8'd0 
                                 : sync_word_count + 1) 
                         : sync_word_count;   

      // finished the sync word (15 bits of 0, bit of 1, plus check bits of 1110)   
      bus_read_state <= metagate[3] 
                        ? ((clkenbl_read_data && sync_word_count == 8'd4)
                               ? `BRST4 
                               : `BRST2) 
                        : `BRST0;

      // read first word in advance of actual sector data
      psreg <= clkenbl_read_data 
               ? dram_readdata 
               : psreg;

      // get the count of words in a sector - 321 for 2310 disk drive
      wordcount <= 12'd321;

      // don't read RAM yet
      load_address_busread <= 1'b0;
      dram_read_enbl_busread <= 1'b0; 

     end

// send Data
    `BRST4: begin     
      // emit clock pulse
      BUS_RD_CLK_H <= clock_pulse;

      // don't get the last four bits from the shift register so we can emit ECC
      // send serialized bits from the parallel-to-serial register, LSB first
      BUS_RD_DATA_H <= ((bus_read_count > 8'd4) ? data_pulse & psreg[0] : data_pulse & ECC_bit); 

      // load the ECC output bit
      ECC_bit <= (ECC_count == 2'd0)
                 ? 1'd0
                 : 1'd1;

      // count one bits for the ECC
      ECC_count <= clkenbl_read_data 
                   ? ((bus_read_count > 8'd4) 
                            ? ((psreg[0] == 1'd1) 
                              ? ECC_count + 1 
                              : ECC_count) 
                            : ((ECC_bit == 1'd1) 
                              ? ECC_count + 1
                              : ECC_count))
                   : ECC_count;

      // decrement if clkenbl_read_data == 1 and rollover from 0 to 19 if the count is at zero, otherwise hold at the present count
      bus_read_count <= clkenbl_read_data 
                        ? ((bus_read_count == 8'd1) 
                               ? 8'd20 
                               : bus_read_count - 1) 
                        : bus_read_count;

      // if done with sector, graceful stop
      bus_read_state <= 
          metagate[3] 
          ?    (((bus_read_count == 8'd1) && (wordcount == 12'd1) && clkenbl_read_data) 
               ? `BRST5 
               : `BRST4) 
          : `BRST0;

      // grab next word from DRAM and put in shift register
      psreg <= clkenbl_read_data 
               ? ((bus_read_count == 8'd1) 
                      ? dram_readdata 
                      : psreg >> 1) 
               : psreg;

      // decrement word count 
      wordcount <= ((bus_read_count == 8'd1) && clkenbl_read_data) 
                   ? wordcount - 1 
                   : wordcount;

      // don't go to next sector or cylinder
      load_address_busread <= 1'b0;

      // request the next word from the sdram
      dram_read_enbl_busread <= (bus_read_count == 8'd19) & (wordcount != 12'd1) & clkenbl_read_data; 

     end

// send Postamble of all zeroes
    `BRST5: begin     
      // always clock pulse
      BUS_RD_CLK_H <= clock_pulse;

      // send all-zeros in the Postamble
      BUS_RD_DATA_H <= 1'b0; 

      // just one bit 
      bus_read_count <= 8'd0;

      // continue output clock and data pulses until the
      // read gate goes off or we reach the next sector
      bus_read_state <= (metagate[3] == 1'b0) || (clkenbl_sector == 1'b1)
                        ? `BRST0 
                        : `BRST5;
 
      // zero out register and count
      psreg <= 16'd0;
      wordcount <= 12'd0;

      // dont try to read
      load_address_busread <= 1'b0;
      dram_read_enbl_busread <= 1'b0; 

     end

    default: begin
      bus_read_state <= `BRST0;
    end

    endcase

  end
end // End of Block DISKREAD

endmodule // End of Module bus_disk_read
