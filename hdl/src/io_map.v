`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/18/2024 09:46:13 PM
// Design Name: 
// Module Name: io_map
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module io_map(
    output VP,
    output AP,
    input VS,
    input AS,
    inout [31:0] gpio_io
  );
    assign VP = gpio_io[31];
    assign AP = gpio_io[30];
    assign gpio_io[29] = VS;
    assign gpio_io[28] = AS;
    assign gpio_io[27:0] = 0;
endmodule
