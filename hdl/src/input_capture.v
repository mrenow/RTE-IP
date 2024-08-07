`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/25/2024 07:57:33 PM
// Design Name: 
// Module Name: input_capture
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


module input_capture #(parameter N=1) (
    input clk,
    input r,
    input [N-1:0] s,
    output [N-1:0] d
);
    reg [N-1:0] d_buf = 0;
    integer i;
    always @(posedge clk) if (r) begin
        d_buf <= 0;     
    end else for (i=0; i<N; i=i+1) begin
        if (s[i]) d_buf[i] <= 1;
    end

    assign d = d_buf | s;
endmodule
