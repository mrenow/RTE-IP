`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/17/2024 12:10:01 PM
// Design Name: 
// Module Name: io_router
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
module router(
    input gpio_t,  // 
    input ps_gpio_o,
    input pl_gpio_o,
    output ps_gpio_i,
    output pl_gpio_i,
    inout ext_gpio
);    
    assign ext_gpio = gpio_t ? pl_gpio_o: 1'bz;
    assign pl_gpio_i = gpio_t ? ps_gpio_o: ext_gpio;
    assign ps_gpio_i = gpio_t ? 1'bz : pl_gpio_o; 
endmodule

(* KEEP_HIERARCHY = "TRUE" *) module io_router(
    input [31:0] gpio_t,
    input [31:0] ps_gpio_o,
    input [31:0] pl_gpio_o,
    output [31:0] ps_gpio_i,
    output [31:0] pl_gpio_i,
    inout [31:0] ext_gpio
);
    genvar i;
    generate
        for (i=0; i<32; i=i+1) begin
           (* KEEP_HIERARCHY = "TRUE" *) router routing_unit(gpio_t[i], ps_gpio_o[i], pl_gpio_o[i], ps_gpio_i[i], pl_gpio_i[i], ext_gpio[i]);
        end
    endgenerate
endmodule
