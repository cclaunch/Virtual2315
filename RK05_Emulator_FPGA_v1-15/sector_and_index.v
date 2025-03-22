//==========================================================================================================
// RK05 Emulator
// sector and index pulse timing generators
// File Name: sector_and_index.v
// Functions: 
//   Divide the 1 microsecond clock to generate a sector pulse enable signal.
//   After number_of_sectors sector pulses, generate an index pulse offset by 600 usec.
//   The Sector interval is defined by the parameter microseconds_per_sector.
//   The 2310 has eight physical sector pulses but controller divides by 2 to see four sectors
//
//   If sector and index pulses are coming from the real drive, use them, otherwise generate them
//   in this module. A switch is set in configuration to choose between real and emulated pulses
//   
// Modified for 2310 by Carl Claunch
//
//==========================================================================================================

module sector_and_index(
    input wire clock,                          // master clock 40 MHz
    input wire reset,                          // active high synchronous reset input
    input wire clkenbl_1usec,                  // 1 usec clock enable input from the timing generator
    input wire real_drive,                     // on to relay the real pulses from the 2310
    input wire BUS_SECTOR_L,                   // sector pulse from the 2310
    input wire BUS_INDEX_L,                    // index pulse from the 2310

    output reg clkenbl_sector,                 // enable for disk read clock
    output reg BUS_SECTOR_EMUL_H,              // active-high 165 usec sector pulse
    output reg BUS_INDEX_EMUL_H,               // active-high 165 usec index pulse
    output reg [1:0] Sector_Address           //counter that specifies which sector is present "under the heads"
);

//============================ Internal Connections ==================================

reg [15:0] int_usec_in_sector;
reg [17:0] int_usec_in_track;
reg [15:0] microseconds_per_sector;
reg [3:0] meta_bus_sector;
reg [3:0] meta_bus_index;
reg [0:0] eat_pulses;
reg [2:0] PSector_Address;      
reg clkenbl_index;      

//============================ Start of Code ========================================= 

always @ (posedge clock)
begin : SECTORCOUNTERS // block name

  if(reset == 1'b1) begin
    int_usec_in_sector <= 16'd4999;
    int_usec_in_track <= 18'd4999;
    PSector_Address <= 3'd7;
    Sector_Address <= 2'd0;
    clkenbl_sector <= 1'b0;
    BUS_SECTOR_EMUL_H <= 1'b0;
    BUS_INDEX_EMUL_H <=  1'b0;
    microseconds_per_sector = 16'd9999;
    meta_bus_sector <= 4'd0;
    meta_bus_index <= 4'd0;
    eat_pulses <= 1'd0;
  end
  else begin

    meta_bus_sector[3:0] <= {meta_bus_sector[2:0], ~BUS_SECTOR_L};
    meta_bus_index[3:0] <= {meta_bus_index[2:0], ~BUS_INDEX_L};

    // reset at rising edge of index (falling edge of BUS_INDEX_L)
    // flip on each falling edge of sector (rising edge of BUS_SECTOR_L)
    eat_pulses <= meta_bus_index[3] == 1'b0 && meta_bus_index[2] == 1'b1
                  ? 1'b0
                  : meta_bus_sector[3] == 1'b1 && meta_bus_sector[2] == 1'b0
                    ? ~eat_pulses
                    : eat_pulses;

    // emit index pulse in last sector, offset from sector pulse
    BUS_INDEX_EMUL_H <= (
                              (
                                  (int_usec_in_track == 16'd599)
                                  &&
                                  clkenbl_1usec
                              )
                              |
                              BUS_INDEX_EMUL_H
                        ) 
                        & 
                        ~(
                              (int_usec_in_track == 16'd764)
                              &&
                              clkenbl_1usec
                        );

    // create index pulse at start of BUS_INDEX or begin of track
    clkenbl_index <= real_drive == 1'b1 
                      ? meta_bus_index[3] == 1'b0 && meta_bus_index[2] == 1'b1 
                          ? 1'b1
                          : 1'b0
                      : ((int_usec_in_track == 18'd599) && clkenbl_1usec);

    // at the end of the full sector: assert the sector enable, 
    //  wrap the usec in sector counter, increment the sector address
    // eat_pulses is off at index, on at next sector and every other sector
    clkenbl_sector <= real_drive == 1'b1 
                      ? meta_bus_sector[3] == 1'b1 && meta_bus_sector[2] == 1'b0 && eat_pulses[0] == 1'b1
                          ? 1'b1
                          : 1'b0
                      : ((int_usec_in_sector == 165) && clkenbl_1usec);

    // at the end of each physical sector, turn on the sector pulse
    BUS_SECTOR_EMUL_H <= (
                               (
                                 (int_usec_in_sector == 5000)
                                 &&
                                 clkenbl_1usec
                               ) 
                               | 
                               (
                                  (int_usec_in_sector == 0) 
                                  &&
                                  clkenbl_1usec
                               )
                               | BUS_SECTOR_EMUL_H
                               ) 
                               & 
                               ~(
                                (
                                    (int_usec_in_sector == 16'd165) 
                                    && 
                                    clkenbl_1usec
                                )
                                | 
                                (
                                  (int_usec_in_sector == 16'd5165) 
                                  &&
                                  clkenbl_1usec
                                ) 
                         );

    // count microseconds in this sector
    int_usec_in_sector <= real_drive == 1'b1
                          ? ((meta_bus_index[1] == 1'b1) && (meta_bus_index[0] == 1'b0))
                              ? 16'd600
                              : clkenbl_1usec 
                                  ?  (int_usec_in_sector == microseconds_per_sector) 
                                      ? 16'd0 
                                      : int_usec_in_sector + 1 
                                  : int_usec_in_sector
                          : clkenbl_1usec 
                              ?  (int_usec_in_sector == microseconds_per_sector) 
                                  ? 16'd0 
                                  : int_usec_in_sector + 1 
                              : int_usec_in_sector;


    // count microseconds in the track for virtual mode
    int_usec_in_track <= real_drive == 1'b1
                          ? 1
                          : clkenbl_1usec 
                              ?  (int_usec_in_track == 18'd39999) 
                                  ? 16'd0
                                  : int_usec_in_track + 1 
                              : int_usec_in_track;
          

    // count physical sectors   
    PSector_Address <= real_drive == 1'b1
                       // for hybrid with real drive sending sector and index pulses
                       ? meta_bus_sector[3] == 1'b1 && meta_bus_sector[2] == 1'b0
                         // at sector pulse end, bump address
                         ? PSector_Address + 1
                         // otherwise look for beginning of index pulse
                         : meta_bus_index[3] == 1'b0 && meta_bus_index[2] == 1'b1
                           // index pulse resets counter
                           ? 3'd7
                           // otherwise retain it
                           : PSector_Address
                       // for pure virtual drive, at end of each of 8 logical sectors
                       : (
                           (int_usec_in_sector == microseconds_per_sector)
                           && 
                           clkenbl_1usec
                         )
                         // bump it
                         ? PSector_Address + 2
                         // at index marker
                         :  clkenbl_index == 1'b1
                              // set current sector number as 3
                              ? 3'd7
                              // keep current value
                             : PSector_Address;

    // emit sector address as 1130 system knows it
    Sector_Address <= real_drive == 1'b1
                      ? clkenbl_sector == 1'b1
                        ? {1'b0 , PSector_Address[2:1]}
                        : Sector_Address
                      : clkenbl_sector == 1'b1
                        ? {1'b0 , PSector_Address[2:1]}
                        : Sector_Address;

  end

end // End of Block COUNTERS

endmodule // End of Module sector_and_index
