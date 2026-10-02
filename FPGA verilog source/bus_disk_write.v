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
    input wire Selected_Ready,         // disk contents have been copied from the microSD to the SDRAM & drive selected & ~fault latch
    input wire clkenbl_sector,         // sector enable pulse
    input wire real_drive,             // on if a physical 2310 drive is used
    input wire dram_writeack,          // acknowledge from DRAM write cycle
    input wire Cart_Ready,             // we have a virtual cartridge ready

    output reg dram_write_enbl_buswrite,       // read enable request to DRAM controller
    output reg [15:0] dram_writedata_buswrite, // 16-bit write data to DRAM controller
    output reg load_address_buswrite,          // enable to command the sdram controller to load the address from sector, head select and cylinder
    output reg write_indicator,                // active high signal to drive the WT front panel indicator
    output reg ECC_error,                      // routed to the Fault indicator on the front panel
    output reg BUS_WT_CLOCKB_EMUL_L,           // produced 720KHz if not real drive
    output reg CVC,                            //  CVC diagnostic output
    output reg write_selected_ready            // output of module
); // End of port list

//============================ Internal Connections ==================================

`define RisingEdge BUS_WT_CLOCKB_EMUL_L && ~oldWT_CLOCKB_L
`define FallingEdge ~BUS_WT_CLOCKB_EMUL_L && oldWT_CLOCKB_L

// state definitions and values for the read state
`define BWST0 2'd0 // 0 - off
`define BWST1 2'd1 // 1 - receive Preamble and Sync
`define BWST2 2'd2 // 2 - receive Data & CRC

// IBM 1130 2310 20 bit words, 321 words with no CRC, 4 logical sectors (8 physical)
// data word is 16 bits, ECC is 1 bits emitted in last four until count mod 4 is 0

reg [1:0] bus_write_state; // read state machine state variable
reg [4:0] bus_write_count; // count bits in a word
reg [11:0] wordcount; // counter to keep track of the number of data & CRC words, in 16-bit increments
reg [15:0] sp_reg; // parallel-to-serial register, receive data LSB first
wire WT_CLOCKB_L;       // clock sent to CPU
reg oldWT_CLOCKB_L;    // saved prior version of the clock to detect edges
reg [5:0] write_tick_counter; // counter to produce a visible flicker of the WT indicator
reg write_gate_safe; // synchronous signal that indicates Write Gate is active
reg [7:0]  sync_bit_count;    // count bits during sync word tail end
reg sync_trigger;             // turn on when we see first 1 bit of the sync word
reg [1:0]  ECC_count;         // count one bits for ECC generation
reg [5:0]  clockb_timer;      // produce 714KHz clock dividing clock by 27
reg CVC;                      // diagnostic bit
wire debounced_gate;          // debounced 

// IBM 1130 write to a 2310 turns on a 1.44 MHz clock in the drive which is also sent to the CPU controller logic
// It is possible to first turn on -Clock Gate to start the oscillator
// with clock gate on, we get out of phase clock A and clock B signals at 720 KHz (bit cell)
// then turn on -Write Gate to begin actual writing.
// However, both -Write Gate and -Clock Gate are tied together on the 1130 system
//
// clock pulse is always produced with -Clock B low, ignoring the value on -Write Data
// data pulse if -Write Data is low when -Clock B is high, a 1 data bit, otherwise nothing done
// set up -Write Data with the data value to be written in a bit cell, switching while -Clock B is low

// to retrieve the data bits, we only have to look at -Clock B low transition while -write gate is on
// much less complex than the data seperator mechanism used with the RK-05 controllers
//
// the controller will continue to write zeros to the disk until the next sector pulse
// and we will store them as words of 0x0000 iin  DRAM


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
    write_tick_counter <= 0;
    write_gate_safe <= 0;
    sync_bit_count <= 8'd0;
    sync_trigger <= 1'b0;
    ECC_count <= 2'd0;
    ECC_error <= 1'b0;
    BUS_WT_CLOCKB_EMUL_L <= 1'b1;
    oldWT_CLOCKB_L <= 1'b1;
    clockb_timer <= 6'd28;
    write_selected_ready <= 1'b0;
    CVC <= 1'b0;  // CVC used to indicate when we are active in the state machine
  end
  else begin

    write_gate_safe <=  ~debounced_gate && Cart_Ready;

    // set when in preample state, decrement on each sector mark, and reset on idle state
    write_tick_counter <= (bus_write_state == `BWST0)
                          ?  0
                          :  (bus_write_state == `BWST1) 
                             ?  16 
                             :  (clkenbl_sector 
                                ?  ((write_tick_counter == 0) 
                                   ? 0 
                                   : write_tick_counter - 1) 
                                :  write_tick_counter);

    write_indicator <= (write_tick_counter != 0);
        
    // Shift the captured data bit into bit 15 of the serial-to-parallel converter register at falling edge WT_CLOCKB_L
    sp_reg[15:0] <= (`FallingEdge) && bus_write_state == `BWST2 && bus_write_count > 3
                    ?  {~BUS_WT_DATA_CLK_L, sp_reg[15:1]} 
                    :  dram_write_enbl_buswrite == 1'b1
                       ? 16'd0
                       :sp_reg[15:0];

    // operate 714 KHz timer
    clockb_timer <= clockb_timer == 0
                       ? 5'd27
                       : clockb_timer - 1;

    // produce bit cell of 1.40 microseconds for ClockB in all cases but only if write gate is on
    // default condition is low, thus 1130s BUS_WT_DATA_CLK_CTRL_L is steady high
    BUS_WT_CLOCKB_EMUL_L <= clockb_timer == 0
                             ? (~BUS_WT_CLOCKB_EMUL_L && ~debounced_gate)
                             : BUS_WT_CLOCKB_EMUL_L;

    // save old WT_CLOCK_L to detect edge
    oldWT_CLOCKB_L <= WT_CLOCKB_L;

    case(bus_write_state)

// 0 - write and erase heads are off, waiting for the write gate and end of sector pulse
    `BWST0: begin    
 
      bus_write_state <= (Selected_Ready == 1'b1 && write_gate_safe == 1'b1) 
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

      CVC <= 1'b0;

      // reset error when disk unloaded
      ECC_error <= Cart_Ready == 1'b1
                   ?  ECC_error
                   :  1'b0;

     end

// 1 - accept Preamble and Sync word
    `BWST1: begin  

      // on falling edge of WT_CLOCKB_L see if we had a 1 bit before
      // that is our first 1 bit - the sync word
      sync_trigger <=  `FallingEdge && ~BUS_WT_DATA_CLK_L
                          ? 1'b1
                          : sync_trigger;

      // when sync trigger is on, count next three bit cells at falling edge of WT_CLOCKB_L
      sync_bit_count <=  `FallingEdge && sync_trigger
                          ? (sync_bit_count > 1
                            ? sync_bit_count - 1
                            : 8'd0)
                          : sync_bit_count;

      // change state at rising edge of WT_CLOCKB_L
      bus_write_state <= ~debounced_gate
                         ? (`RisingEdge)
                           ?   ( sync_bit_count > 0
                               ?`BWST1
                               :`BWST2)
                           : `BWST1 
                         : `BWST0;

      dram_write_enbl_buswrite <= 1'b0;
      dram_writedata_buswrite <= 16'd0;

      // set up write address at falling edge of WT_CLOCKB_L
      load_address_buswrite <= `FallingEdge && sync_bit_count == 2;

      // begin count for next state when we are collecting words
      bus_write_count <= 5'd19; 

      wordcount <= 12'd321; // set to the number of words to be transferred, which is bit length/16

      ECC_error <= 1'b0;

      write_selected_ready <= 1'b1;

      CVC <= 1'b1;

     end

// 2 - grab the Data words
    `BWST2: begin 

      // finish when 1130 drops write gate
      bus_write_state <= ~debounced_gate 
                         ?  `BWST2 
                         :  `BWST0;

      // write a word at rising edge of BUS_WT_CLOCKB_L when count of bits captured hits two and we are still examining ECC
      dram_write_enbl_buswrite <= `RisingEdge && (bus_write_count == 2);

      // change the output register for DRAM write on rising edge of BUS_WT_CLOCKB_L
      dram_writedata_buswrite <= `RisingEdge && (bus_write_count == 3) ? sp_reg : dram_writedata_buswrite;

      load_address_buswrite <= 1'b0;

      // at rising edge of WT_CLOCKB_L we count off bits
      bus_write_count <= `RisingEdge
                         ? (bus_write_count == 0 
                           ? 5'd19 
                           : bus_write_count - 1)
                         : bus_write_count;

      // at rising edge of WT_CLOCKB_L count words when bits all captured
      // this counter does not matter as it is not used to develop a memory 
      // address for the words written during a sector. it is more of a 
      // convenience for simulation where we can observe the behavior
      wordcount <= `RisingEdge && (bus_write_count == 0) 
                  ? wordcount - 1
                  : wordcount;

      // accumulate one bits during word, caught at falling edge of WT_CLOCKB_L
      ECC_count <= `FallingEdge
                   ?  (bus_write_count == 0)
                      ?  2'd0 
                      :  ~BUS_WT_DATA_CLK_L 
                        ?  ECC_count + 1 
                        :  ECC_count
                   :  ECC_count;

      // at rising edge of WT_CLOCKB_L if bits done, check for ECC error
      ECC_error <= `RisingEdge && (bus_write_count == 0) 
                   ? ECC_count == 2'd0
                      ? ECC_error
                      : 1'b1
                   : ECC_error;

      sync_trigger <= 1'b0;

      write_selected_ready <= 1'b1;

      CVC <= 1'b1;

     end

    default: begin

        bus_write_state <= `BWST0;

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

endmodule // End of Module bus_disk_write
