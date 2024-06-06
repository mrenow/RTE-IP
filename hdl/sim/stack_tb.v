`timescale 1ns / 1ps

module stack_tb;

    // Parameters
    parameter N = 5;

    // Inputs
    reg clk;
    reg reset;
    reg wr_en;
    reg wr_data;
    reg pop;
    reg push;

    // Outputs
    wire [N-1:0] out_stack;

    // Instantiate the Unit Under Test (UUT)
    stack #(.N(N)) uut (
        .clk(clk), 
        .reset(reset), 
        .wr_en(wr_en), 
        .wr_data(wr_data), 
        .pop(pop), 
        .push(push), 
        .out_stack(out_stack)
    );

    // Clock generation
    always #5 clk = ~clk;

    initial begin
        // Initialize Inputs
        clk = 0;
        reset = 1;
        wr_en = 0;
        wr_data = 0;
        pop = 0;
        push = 0;

        // Wait for global reset
        #100;
        reset = 0;

        // Write data to the first register
        #10;
        wr_en = 1;
        wr_data = 1;
        #10;
        wr_en = 0;
        if (out_stack !== 5'b00001) $display("Test failed: Expected stack to be 00001, got %b", out_stack);

        // Push data up the stack
        #10;
        push = 1;
        wr_data = 0;
        #10;
        push = 0;
        if (out_stack !== 5'b00010) $display("Test failed: Expected stack to be 00010, got %b", out_stack);

        // Pop data down the stack and write
        #10;
        pop = 1;
        #10;
        pop = 0;
        if (out_stack !== 5'b00001) $display("Test failed: Expected stack to be 00001, got %b", out_stack);

        // push and write data 
        #10;
        push = 1;
        wr_en = 1;
        wr_data = 1;
        #10;
        push = 0;
        wr_en = 0;
        if (out_stack !== 5'b00011) $display("Test failed: Expected stack to be 00011, got %b", out_stack);
        
        // Pop data down the stack
        #10;
        pop = 1;
        wr_en = 1;
        wr_data = 0;
        #10;
        pop = 0;
        wr_en = 0;
        if (out_stack !== 5'b00000) $display("Test failed: Expected stack to be 00000, got %b", out_stack);
        
        
        // Add more test cases as needed

        // Finish the simulation
        $finish;
    end

    initial begin
        // Monitor changes to signals
        $monitor("Time = %d, clk = %b, reset = %b, wr_en = %b, wr_data = %b, pop = %b, push = %b, out_stack = %b",
                 $time, clk, reset, wr_en, wr_data, pop, push, out_stack);
    end

endmodule
