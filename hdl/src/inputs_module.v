module inputs_module(
    input clk,                 // Clock signal
    input reset,               // Asynchronous reset signal
    
    input [4:0] wr_addr,       // 5-bit address
    input [4:0] rd_addr,       // 5-bit address

    input [31:0] cfg_clk_flags,    // Config for which addresses are clocks
    
    input val,                 // value to write, produced by clock module

    input en_wr_input,               // Control signal    
    input en_load_input,          // Control signal indicating whether to load input data at this time.
    
    input [31:0] in_data,    // Input data at interception

    //debug outputs
    output [31:0] db_inputs_valid,
    
    output out_val,     // data read from address
    output reg [31:0] out_data,     // data read from address
    output out_valid    // Whether requested data has been computed
        
);


reg [31:0] valid;

assign out_val = out_data >> rd_addr; // In Selector
assign out_valid = valid >> rd_addr;

always @(posedge clk or posedge reset) begin: inputs_proc
    if (reset) begin
        out_data <= 0;
        valid <= 0;
    end else if (en_load_input) begin
        out_data <= in_data;
        valid <= ~cfg_clk_flags;
    end else if(en_wr_input) begin
        out_data[wr_addr] <= val;
        valid[wr_addr] <= 1;
    end
end

// assign db outputs
assign db_inputs_valid = valid;

endmodule