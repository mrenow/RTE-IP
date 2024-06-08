module parsing(
    input clk,             // Clock signal
    input reset,           // Asynchronous reset signal
    input cycle,
    
    input [7:0] in_mem,        // 8-bit input from memory
    input [3:0] nxt_state,     // 4-bit next state
    input stack0,              // lsb of stack.
    
    input flag_b,               // A Control: _flag_b := 1, 0
    input [1:0] mux_var,        // A Control: _var := (~addr + ~n), {nxt_state, _flag_b}, nib, 
    input en_d4,                // A Control: Write to VAR[4]
    input en_var3,              // A Control: Write to VAR[3:0]
    input en_op,                // A Control: Write to OP
    input mux_hi,               // B Control: HI <= stack0, VAR[0];
    input en_hi,                // B Control: Write to HI  
    // debug
    output db_hi,
    //output
    output [7:0] out_data_A,     // 8-bit output data
    output [7:0] out_data_B     // 8-bit output data
);

// Cycle concepts
localparam E = 1;
localparam T = 0;
localparam EVEN = 0; 
localparam ODD = 1;
// Aliases
wire A = cycle;
wire B = ~cycle;
wire T_is_A = cycle == EVEN;
wire T_is_B = cycle == ODD;
wire E_is_A = cycle == ODD;
wire E_is_B = cycle == EVEN;

reg HI; // Transition Only
reg [7:0] VAR [1:0];

// Internal signals
wire [3:0] function_out;     // Output of the function block (fx, b)
wire [7:0] data_segments;    // Concatenated DATA segments


wire[3:0] addr = in_mem[3:0];   // 4-bit address input          
wire[1:0] n = in_mem[6:5];      // 2-bit n input                

// Adder operation
wire[4:0] adder_out = {1'b1, ~addr} + {3'h7, ~n};  // sign-extended 5-bit addition

wire[3:0] nib_mux_out = HI ? in_mem[7:4] : in_mem[3:0];

wire hi_mux_out = mux_hi ? stack0 : VAR[T][0];
// Multiplexers and Data Segmentation
wire[4:0] var_mux_out = mux_var[1] ?
    (mux_var[0]? adder_out : {nxt_state, flag_b}) :
    (mux_var[0]? {1'b0, nib_mux_out} : in_mem[4:0]);
    
wire _en_hi = T_is_B & en_hi;
always @(posedge clk or posedge reset) begin: var_proc
    if(reset) begin
        VAR[0] <= 0;
        VAR[1] <= 0;
        HI <= 0;
    end else begin
        if (en_op)  VAR[A][7:5] <= in_mem[7:5];
        if (en_var3) VAR[A][3:0] <= var_mux_out[3:0];
        if (en_d4) VAR[A][4] <= var_mux_out[4];
        if (_en_hi) HI <= hi_mux_out;
    end
end 

assign out_data_B = VAR[B];
assign out_data_A = VAR[A];

assign db_hi = HI;

endmodule

