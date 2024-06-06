module scan_rom #(
    parameter WIDTH = 8 // Width of the scan chain
) (
    input clk,       // Clock input
    input reset,     // Active low reset
    
    input scan_en,   // Scan enable signal
    input scan_in,   // Scan data input
    output scan_out, // Scan data output
    
    output [WIDTH-1:0] d_out // Functional data output
);

// Internal register for holding scan chain data
reg [WIDTH-1:0] scan_reg;

// Sequential logic for scan chain and functional data
always @(posedge clk or posedge reset) begin: scan_proc
    if (reset) begin
        scan_reg <= {WIDTH{1'b0}}; // Reset scan chain to all zeros
    end else if (scan_en) begin
        scan_reg <= {scan_reg[WIDTH-2:0], scan_in}; // Shift in scan data
    end
end

// Assign outputs
assign d_out = scan_reg;
assign scan_out = scan_reg[WIDTH-1];

endmodule
