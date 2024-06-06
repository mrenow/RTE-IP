`timescale 1ns / 1ps

module outputs_module_tb;
    // Testbench signals
    reg clk_tb;
    reg reset_tb;
    reg [31:0] in_data_tb;
    reg out_en_tb;
    reg out_en_all_tb;
    reg stack0;
    reg val;
    reg mux_data;
    reg [4:0] addr;
    wire [31:0] out_buf_tb;
    
    // Instantiate the module under test (MUT)
    outputs_module mut (
        .clk(clk_tb),
        .reset(reset_tb),
        .in_data(in_data_tb),
        .out_en(out_en_tb),
        .out_en_all(out_en_all_tb),
        .out_buf(out_buf_tb),
        .mux_data(mux_data),
        .val(val),
        .stack0(stack0),
        .addr(addr)
    );
    
    // Clock generation
    initial begin
        clk_tb = 0;
        forever #5 clk_tb = ~clk_tb; // Generate a clock with a period of 10ns
    end
    
    // Test sequence
    initial begin
        // Initialize inputs
        reset_tb = 1;
        in_data_tb = 0;
        out_en_tb = 0;
        mux_data=0;
        out_en_all_tb = 0;
        addr = 0;
        val = 0;
        stack0=0;
    
        // Release reset
        #10;
        reset_tb = 0;
        
        // Test case 1: Write a value to the buffer
        #10;
        in_data_tb = 32'h3;
        mux_data = 1;
        out_en_all_tb = 1; // Enable output globally
        stack0 = 0;
        val = 0;
        // Wait for a clock cycle
        #10;
        out_en_all_tb = 0; // Enable output globally
        mux_data = 0;
        // Test case 2: Disable all outputs
        #10;
        out_en_all_tb = 0;
    
        // Test case 3: Enable individual outputs
        #10;
        addr = 6;
        out_en_tb = 1;
        val = 1;
        stack0 = 1;
        #10;
        addr = 31;
        out_en_tb = 1;
        val = 1;
        stack0 = 1;
        #10;
        #10;
        // Test case 4: Reset the module
        #10;
        reset_tb = 1;
        #10;
        reset_tb = 0;
    
        // Finish the simulation
        #10;
        $finish;
    end
    
    // Monitor the outputs
    initial begin
        $monitor("Time=%g, Reset=%b, InData=%h, out_en=%b, out_en_all=%b, OutBuf=%h",
                 $time, reset_tb, in_data_tb, out_en_tb, out_en_all_tb, out_buf_tb);
    end
endmodule


