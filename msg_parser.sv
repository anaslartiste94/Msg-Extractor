`timescale 1ns / 1ps
module msg_parser #(
  parameter MAX_MSG_BYTES = 32
)(
  output logic        s_tready,
  input  logic        s_tvalid,
  input  logic        s_tlast,
  input  logic [63:0] s_tdata,
  input  logic [7:0]  s_tkeep,
  input  logic        s_tuser, // Used as an error input signal, valid on tlast

  output logic                       msg_valid,   // High for one clock to output a message
  output logic [15:0]                msg_length,  // Length of the message
  output logic [8*MAX_MSG_BYTES-1:0] msg_data,    // Data with the LSB on [0]
  output logic.                      msg_error,   // Output if issue with the message

  input  logic clk,
  input  logic rst
);


endmodule

/*
Sample inputs:

tvalid,tlast,tdata,tkeep,terror
1,0,abcddcef_00080001,11111111,0
1,1,00000000_630d658d,00001111,0
1,0,045de506_000e0002,11111111,0
1,0,03889560_84130858,11111111,0
1,0,85468052_0008a5b0,11111111,0
1,1,00000000_d845a30c,00001111,0
1,0,62626262_00080008,11111111,0
1,0,6868000c_62626262,11111111,0
1,0,68686868_68686868,11111111,0
1,0,70707070_000a6868,11111111,0
1,0,000f7070_70707070,11111111,0
1,0,7a7a7a7a_7a7a7a7a,11111111,0
1,0,0e7a7a7a_7a7a7a7a,11111111,0
1,0,4d4d4d4d_4d4d4d00,11111111,0
1,0,114d4d4d_4d4d4d4d,11111111,0
1,0,38383838_38383800,11111111,0
1,0,38383838_38383838,11111111,0
1,0,31313131_000b3838,11111111,0
1,0,09313131_31313131,11111111,0
1,0,5a5a5a5a_5a5a5a00,11111111,0
1,1,00000000_00005a5a,00000011,0
*/
