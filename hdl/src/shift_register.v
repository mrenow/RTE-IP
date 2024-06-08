module shift_register #(
    parameter N = 5  // Stack length
) (
    input clk,             // Clock signal
    input reset,           // Synchronous reset
    
    input wr_en,           // Write enable
    input wr_data,         // Write data
    input pop,             // Pop signal
    input push,            // Push signal
    
    output [N-1:0] out_stack  // N-bit stack data
);

    // Internal shift register
    reg [N-1:0] shift_reg;

    // Stack control logic
    always @(posedge clk or posedge reset) begin: stack_proc
        if (reset) begin
            // Reset the stack
            shift_reg <= 0;
        end else begin
            if (push) begin
                // Shift data up the stack
                shift_reg <= shift_reg << 1;
            end else if (pop) begin
                // Shift data down the stack
                shift_reg <= shift_reg >> 1;
            end

            if (wr_en) begin
            // Write data to the first register
                shift_reg[0] <= wr_data;
            end
        end
    end
       
    assign out_stack = shift_reg;

endmodule
