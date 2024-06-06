`timescale 1ns / 1ps

module clock_module_tb;

// Parameters for the testbench
localparam CLK_CYCLE = 10; // Clock cycle period in ns

// Testbench signals
reg clk_tb;
reg reset_tb;
reg op_tb;
reg [3:0] imm_lo_tb;
reg [7:0] imm_hi_tb;
reg [1:0] addr_tb;
reg long_tb;
reg en_clk_reset_tb;
reg [7:0] clk_reset_tb;
reg [7:0] cfg_clk_joins_tb;
reg [39:0] cfg_div_limits_tb;
wire out_val_tb;

// Instantiate the module under test (MUT)
clocks_module mut(
    .clk(clk_tb),
    .reset(reset_tb),
    .op(op_tb),
    .imm_lo(imm_lo_tb),
    .imm_hi(imm_hi_tb),
    .addr(addr_tb),
    .long(long_tb),
    .en_clk_reset(en_clk_reset_tb),
    .clk_reset(clk_reset_tb),
    .cfg_clk_joins(cfg_clk_joins_tb),
    .cfg_div_limits(cfg_div_limits_tb),
    .out_val(out_val_tb)
);

// Clock generation
initial begin
    clk_tb = 0;
    forever #(CLK_CYCLE / 2) clk_tb = ~clk_tb;
end

// Test sequence
initial begin
    // Initialize testbench signals
    reset_tb = 1;
    op_tb = 0;
    imm_lo_tb = 0;
    imm_hi_tb = 0;
    addr_tb = 0;
    long_tb = 0;
    en_clk_reset_tb = 0;
    clk_reset_tb = 0;
    cfg_clk_joins_tb = 8'b00011100;
    cfg_div_limits_tb = {10'd10, 10'd2, 10'd4, 10'd0};

    // Reset the DUT
    #(CLK_CYCLE * 2) reset_tb = 0;

    // Test clock operation with 4-bit clocks
    #CLK_CYCLE imm_lo_tb = 4'h0; // Set lower immediate to a value that will be compared
    addr_tb = 0; // Select clock 0 for comparison
    op_tb = 1; // Set operation to less than
    long_tb = 0; // Select from 4-bit clocks
    #(CLK_CYCLE*4096);
    

//    #(CLK_CYCLE*50)

//    // Test reset functionality
//    #CLK_CYCLE en_clk_reset_tb = 1; // Enable clock reset
//    clk_reset_tb = 8'b1111_1111; // Reset all clocks


//    // Test 12-bit clocks
//    #CLK_CYCLE long_tb = 1; // Now select from 12-bit clocks
//    imm_hi_tb = 8'hFF; // Set higher immediate for comparison
//    addr_tb = 3'd1; // Select clock 1 for comparison
//    op_tb = 0; // Set operation to 'less than'

//    // Test clock divider configuration
//    #CLK_CYCLE cfg_div_limits_tb = 40'hFFFFFFFFFF; // Set divider values
//    addr_tb = 3'd3; // Select one of the dividers
//    long_tb = 0; // Dividers are still considered 4-bit for selection

//    // Finish the simulation
    #CLK_CYCLE;
end

// Monitor outputs
initial begin
    $monitor("At time %t, op=%b, imm_lo=%h, imm_hi=%h, addr=%d, long=%b, en_clk_reset=%b, clk_reset=%h, cfg_clk_joins=%h, cfg_div_limits=%h, out_val=%b",
             $time, op_tb, imm_lo_tb, imm_hi_tb, addr_tb, long_tb, en_clk_reset_tb, clk_reset_tb, cfg_clk_joins_tb, cfg_div_limits_tb, out_val_tb);
end

endmodule
