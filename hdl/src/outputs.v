module outputs_module(
    input clk,                 // Clock signal
    input reset,               // Asynchronous reset signal
    
    input [4:0] addr,          // 5-bit address
    input do_write,            // Condition flag deciding whether to perform write at addr.
    input val,                 // value to write in 

    input [31:0] in_data,      // Setup: Input data at interception.

        
    input en_edit,               // Control: Enable writing to addr conditional on do_write_flag
    input en_load_input,           // Control: Global output enable
    input mux_data,            // Control: Get input data source
    
    output reg [31:0] out_buf  // 32-bit output buffer register
);

// Internal signals
wire [31:0] data_mux_out;      // Output of the multiplexer
wire [31:0] enable;            // Enable signal

// Multiplexer logic

assign enable = {32{en_load_input}} | ((en_edit & do_write) << addr);

// Output buffer register logic
always @(posedge clk or posedge reset) begin: output_buffer
    integer i;
    if (reset) begin
        out_buf <= 32'd0;
    end else begin
        for (i=0; i<32; i=i+1) begin
            if(enable[i]) begin
                out_buf[i] <= mux_data ? in_data[i]: val;
            end
        end
    end
end
endmodule
