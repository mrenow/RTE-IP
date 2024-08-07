module buf_reg #(parameter N = 1) (
        input clk,
        input reset,
        input en,
        input [N-1: 0] in_data,
        output reg [N-1: 0] out_data
    );
    always @(posedge clk or posedge reset) begin: reg_proc
        if (reset) begin
            out_data <= 0;
        end else if (en) begin                
            out_data <= in_data;
        end
    end
endmodule
