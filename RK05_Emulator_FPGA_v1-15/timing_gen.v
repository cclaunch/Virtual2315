//==========================================================================================================
// RK05 Emulator
// clock timing generators
// File Name: timing_gen.v
// Functions: 
//   divide the global clock to generate a 1x rate 720 KHz read bit clock enable and twice-rate bit clock enable.
//   1 microsecond clock timing generator - divide the global clock to generate a 1 microsecond timing enable signal used for sector and index logic and seek logic. 
//
//==========================================================================================================

module timing_gen(
    input wire clock,             // master clock 40 MHz
    input wire reset,             // active high synchronous reset input

    output reg clkenbl_read_bit,  // enable for disk read clock
    output reg clkenbl_read_data, // enable for disk read data
    output reg clock_pulse,       // clock pulse with proper 160 us width from drive
    output reg data_pulse,        // data pulse with proper 160 us width from drive
    output reg clkenbl_1usec      // enable for 1 usec clock pulse
);

//============================ Internal Connections ==================================

reg [7:0] half_bit;
reg data_phase;
reg [6:0] usec_counter;
`define USEC_LOAD_VALUE 7'd40  // reload value for the usec_counter

//============================ Start of Code =========================================

always @ (posedge clock)
begin : COUNTERS // block name
  if(reset==1'b1) begin
    half_bit <= 8'd1;
    data_phase <= 1'b1;
    usec_counter <= `USEC_LOAD_VALUE;
    clkenbl_1usec <= 1'b0;
    clkenbl_read_bit <= 1'b0;
    clkenbl_read_data <= 1'b0;
    clock_pulse <= 1'b0;
    data_pulse <= 1'b0;
  end
  else begin
    clkenbl_read_bit  <= (half_bit==8'd2) && ~data_phase;
    clkenbl_read_data <= (half_bit==8'd2) &&  data_phase;

    half_bit <= (half_bit==8'd1) ? 8'd28 : half_bit - 1; // decrement, but if at the end, load opposite phase count
    data_phase <= (half_bit==8'd1) ? ~data_phase : data_phase; // toggle data_phase when counter == 1 at the end of the phase

    clock_pulse <= (half_bit > 8'd12) && ~data_phase;
    data_pulse  <= (half_bit > 8'd12) && data_phase;

    usec_counter <= (usec_counter == 7'd1) ? `USEC_LOAD_VALUE : usec_counter - 1; // for divide by 40, if counter == 1 then load 40

    clkenbl_1usec <= (usec_counter == 7'd1);
  end
end // End of Block COUNTERS

endmodule // End of Module timing_gen
