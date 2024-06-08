`timescale 1ns / 1ps


module inputs_module_tb;

// Testbench signals
reg clk_tb;
reg reset_tb;
reg [4:0] wr_addr_tb;
reg [4:0] rd_addr_tb;
reg [31:0] CLK_FLAGS_tb;
reg val_tb;
reg in_en_tb;
reg load_input_tb;
reg [31:0] in_data_tb;
wire out_data_tb;
wire out_valid_tb;

// Instantiate the module under test (MUT)
inputs_module mut (
    .clk(clk_tb),
    .reset(reset_tb),
    .wr_addr(wr_addr_tb),
    .rd_addr(rd_addr_tb),
    .CLK_FLAGS(CLK_FLAGS_tb),
    .val(val_tb),
    .in_en(in_en_tb),
    .load_input(load_input_tb),
    .in_data(in_data_tb),
    .out_data(out_data_tb),
    .out_valid(out_valid_tb)
);

// Clock generation
initial begin
    clk_tb = 0;
    forever #5 clk_tb = ~clk_tb; // 10ns clock period
end

// Test sequence
initial begin
    // Initialize inputs
    reset_tb = 1;
    wr_addr_tb = 0;
    rd_addr_tb = 0;
    CLK_FLAGS_tb = 0;
    val_tb = 0;
    in_en_tb = 0;
    load_input_tb = 0;
    in_data_tb = 0;

    // Release reset
    #10 reset_tb = 0;

    // Test case 1: Load input data
    #10 load_input_tb = 1;
        in_data_tb = 32'hAAAA_AAAA;
        CLK_FLAGS_tb = 32'h5555_5555;
        load_input_tb = 0;

    // Test case 2: Write a value to a specific address
    #10 wr_addr_tb = 5'd16; // Choose an address to write to
        val_tb = 1'b1;       // Value to write
        in_en_tb = 1'b1;     // Enable the write

    // Test case 3: Read from the same address
    #10 rd_addr_tb = wr_addr_tb;
        in_en_tb = 0;       // Disable the write

    // Wait for changes to propagate
    #10;

    // Test case 4: Read from an address that hasn't been written to
    #10 rd_addr_tb = 5'd2;

    // Test case 5: Load new input while keeping old valid bits
    #10 load_input_tb = 1;
        in_data_tb = 32'hFFFF_0000;
        // CLK_FLAGS unchanged
        load_input_tb = 0;

    // Finish the simulation
    #10;
end

// Monitor the outputs
initial begin
    $monitor("Time=%g, Reset=%b, InData=%h, wr_addr=%h, rd_addr=%h, out_data=%b, out_valid=%b",
             $time, reset_tb, in_data_tb, wr_addr_tb, rd_addr_tb, out_data_tb, out_valid_tb);
end

endmodule
