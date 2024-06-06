

`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/28/2024 09:32:38 PM
// Design Name: 
// Module Name: trunc_tb
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

module truncator_tb;

    // Parameters
    parameter N = 5;

    // Inputs
    reg [N-1:0] signal;
    reg [N-2:0] truncator;

    // Outputs
    wire [N-1:0] truncated;

    // Instantiate the Unit Under Test (UUT)
    trunc #(.N(N)) uut (
        .signal(signal), 
        .truncator(truncator), 
        .truncated(truncated)
    );

    initial begin
        // Initialize Inputs
        signal = 0;
        truncator = 0;

        // Wait for global reset
        #100;

        // Test case 1
        signal = 5'b11101;
        truncator = 5'b10000;
        #10;
        if (truncated != 5'b01101) $display("Test case 1 failed: Expected 01101, got %b", truncated);

        // Test case 2
        signal = 5'b11101;
        truncator = 5'b00000;
        #10;
        if (truncated != 5'b11101) $display("Test case 2 failed: Expected 11101, got %b", truncated);

        // Test case 3
        signal = 5'b11101;
        truncator = 5'b00010;
        #10;
        if (truncated != 5'b00001) $display("Test case 3 failed: Expected 00001, got %b", truncated);

        // Finish the simulation
        $finish;
    end

    initial begin
        // Monitor changes to signals
        $monitor("Time = %d, signal = %b, truncator = %b, truncated = %b",
                 $time, signal, truncator, truncated);
    end

endmodule
