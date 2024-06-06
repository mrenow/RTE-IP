module trunc #(
    parameter N = 5  // Number of bits in the signal
)(
    input wire [N-1:0] signal,         // Input signal
    input wire [N-1:0] truncator,       // Truncator signal
    output wire [N-1:0] truncated       // Truncated output signal
);

    wire [N-1:0] mask;  // Mask for truncation

    // Generate mask based on truncator signal
    genvar i;
    generate
        for (i = 0; i < N; i = i + 1) begin : gen_mask
            assign mask[i] = |truncator[i:0];
        end
    endgenerate
    // Apply mask to input signal
    assign truncated = signal[N-1:0] & ~mask[N-1:0];

endmodule
