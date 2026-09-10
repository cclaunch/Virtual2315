//==========================================================================================================
//
// Serializer logic - passes signal through a chain of four D flip flops
//                    to reduce the risk of metastable states and sync the
//                    the incoming signal to the clock of the FPGA
//
// Written by Carl V Claunch
//
//==========================================================================================================

module serializer(
    input wire clock,                  // FPGA 40MHz clock
    input wire reset,                  // power on reset
    input wire input_data,             // signal that we want to serialize
    input wire initial_state,          // high or low initially
    output reg serialized              // protected output
);

//============================ Internal Connections ==================================

reg [3:0] meta;                        // chain of D flipflop outputs

//============================ Start of Code =========================================


always @ (posedge clock)
begin : SHIFTER // block name

  if(reset==1'b1) begin

      // set initial output
      serialized <=       initial_state == 1'b0
                          ?  1'b0
                          :  1'b1;

      // set initial meta value
      meta[3:0]       <=  initial_state == 1'b0
                          ?  4'b0000
                          :  4'b1111;

  end
  else begin

      // shift bits in
      meta[3:0]      <=   {meta[2:0],input_data};

      // emit debounced output
      serialized     <=   meta[3];
              
  end

end // End of Block SHIFTER


endmodule // End of Module serializer
