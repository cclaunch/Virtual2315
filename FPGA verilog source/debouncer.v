//==========================================================================================================
//
// Debouncer logic - requires 20 straight changed bits to flip state
//                   thus swallows 500 nanoseconds of a glitch with 
//                   a 25 ns lag on output
//
// Modified by Carl V Claunch for 2310 drive
//
//==========================================================================================================

module debouncer(
    input wire clock,                  // FPGA 40MHz clock
    input wire reset,                  // power on reset
    input wire input_data,             // signal that we want to debounce
    input wire initial_state,          // high or low initially
    output reg debounced_data          // smoothed output
);

//============================ Internal Connections ==================================

reg [4:0] counter;                     // 500 nanosecond debounce timer

//============================ Start of Code =========================================


always @ (posedge clock)
begin : SELECT // block name

  if(reset==1'b1) begin

    // set initial output
    debounced_data <= initial_state == 1'b0
                      ?  1'b0
                      :  1'b1;

    // set initial counter
    counter <=        initial_state == 1'b0
                      ?  5'd0
                      :  5'd20;

  end
  else begin

    // manage counter
    counter <=         input_data == 1'b1
                       ?  counter == 5'd20
                          ?  counter
                          :  counter + 1
                       :  counter == 5'd0
                          ?  counter
                          :  counter - 1;

     // emit debounced output
     debounced_data <= (counter == 5'd20)
                       ?  1'b1
                       :  (counter == 5'd0)
                          ?  1'b0
                          :  debounced_data;
              
  end
end // End of Block SELECT


endmodule // End of Module debouncer
