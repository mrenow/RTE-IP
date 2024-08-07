`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/24/2024 06:04:27 PM
// Design Name: 
// Module Name: io_unit
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


(* KEEP_HIERARCHY = "TRUE" *) module io_unit(
    output VP,
    output AP,
    input VS,
    input AS,
    input [31:0] ps_gpio_o,
    input [31:0] pl_gpio_o,
    output [31:0] ps_gpio_i,
    output [31:0] pl_gpio_i
    );
    assign VP = pl_gpio_o[31];
    assign pl_gpio_i[31] = ps_gpio_o[31];
    
    assign AP = pl_gpio_o[30];
    assign pl_gpio_i[30] = ps_gpio_o[30];
    
    assign pl_gpio_i[29] = VS;
    assign ps_gpio_i[29] = pl_gpio_o[29];
    
    assign pl_gpio_i[28] = AS;
    assign ps_gpio_i[28] = pl_gpio_o[28];
    
    assign ps_gpio_i[31:30] = 0;
    assign ps_gpio_i[27:0] = 0;
    assign pl_gpio_i[27:0] = 0;
endmodule
