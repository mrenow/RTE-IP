`timescale 1ns / 1ps
/*

module main_memory #(parameter LEN = 64) (
    input clk,
    input reset,

    // Scan chain writes bit by bit.
    input scan_in,
    input scan_en,
    output scan_out,
    
    input [7:0] addr,
    output [7:0] d_out_0,
    output [7:0] d_out_1
);

reg [7:0] memory [LEN-1:0];

assign d_out_0 = memory[addr];
assign d_out_1 = memory[(addr+1)[4:0]];

assign scan_out = memory[LEN-1];

always @(posedge clk or posedge reset) begin
    if(reset) begin
        for(i=0; i<LEN; i=i+1) begin
            memory[i] <= 0;
        end
    end else if(scan_en) begin
        for(i=0; i<LEN; i=i+1) begin
            memory[i][7:1] <= {memory[i][6:0], i == 0 ? scan_in : memory[i-1][7]};
        end
    end
end 

*/
module main_memory_tb;

// Parameters
parameter LEN = 64;

// Inputs
reg clk;
reg reset;
reg scan_in;
reg scan_en;
reg [7:0] addr;

// Outputs
wire [7:0] d_out_0;
wire [7:0] d_out_1;
wire scan_out;

// Instantiate the Unit Under Test (UUT)
main_memory #(.LEN(LEN)) uut (
    .clk(clk), 
    .reset(reset), 
    .scan_in(scan_in), 
    .scan_en(scan_en), 
    .scan_out(scan_out), 
    .addr(addr), 
    .d_out_0(d_out_0), 
    .d_out_1(d_out_1)
);

// Clock generation
always #5 clk = ~clk;

integer i;
integer j;
parameter SCAN_LEN = LEN;
reg [7:0] x;
reg [7:0] data [SCAN_LEN-1:0];

// Test sequence
initial begin
    // Initialize Inputs
    clk = 0;
    reset = 1;
    scan_in = 0;
    scan_en = 0;
    addr = 0;

    // Wait for global reset
    #10;
    reset = 0;
    
    // Stream in data, where each value is the index of the memory location
    for (i=LEN-1; i>=0; i=i-1) begin
        for (j=7; j>=0; j=j-1) begin
            scan_in = i[j];
            scan_en = 1;
            #10;
        end
    end
    scan_en = 0;

    // Stream in data from a file
    $readmemh("data.txt", data); // Read data from file
    for (i=LEN-1; i>0; i=i-1) begin
        for (j=7; j>=0; j=j-1) begin
            scan_in = data[i][j];
            scan_en = 1;
            #10;
        end
    end
    scan_en = 0;


end

endmodule
