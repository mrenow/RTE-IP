`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/18/2024 09:46:13 PM
// Design Name: 
// Module Name: rising_edge_detector
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


module rising_edge_detector #(parameter WIDTH=1)(
    input reset,
    input clk,
    input [WIDTH-1:0] signal_i,
    output reg [WIDTH-1:0] pulse_o
    );
    reg [WIDTH-1:0] cancel = {1'b1{WIDTH}};
    
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            pulse_o <= 0;  
            cancel <= {1'b1{WIDTH}};
        end else begin
            pulse_o <= signal_i & cancel;
            cancel <= ~signal_i;
        end
    end
endmodule
