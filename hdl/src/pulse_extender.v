
    
    
module pulse_extender #(parameter WIDTH=1, parameter CYCLES=100)(
    input reset,
    input clk,
    input [WIDTH-1:0] signal_i,
    output reg [WIDTH-1:0] pulse_o
);
    function integer bit_len;
       input integer i;
    // integer 	i = value;
       begin
          bit_len = 0;
          for(i=i; i != 0; i = i >> 1) bit_len = bit_len + 1;
       end
    endfunction
    localparam BIT_LEN = bit_len(CYCLES);
    reg [BIT_LEN-1: 0] count [WIDTH-1:0];
    
    integer i;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i=0; i<WIDTH; i=i+1) begin
                count[i] <= 0;
            end
            pulse_o <= 0;
        end else begin
            for (i=0; i<WIDTH; i=i+1) begin
                if (signal_i[i]) begin
                    count[i] <= 0;
                    pulse_o[i] <= 1;
                end else if (count[i] == CYCLES) begin
                    pulse_o[i] <= 0;
                end else begin
                    pulse_o[i] <= 1;
                    count[i] <= count[i] + 1;
                end
            end
                
        end
    
    end

endmodule