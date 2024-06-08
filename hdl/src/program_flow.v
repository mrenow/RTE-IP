module program_flow #(parameter STACK_LEN=6) (
    input clk,              // Clock signal
    input reset,            // Asynchronous reset signal
    input cycle,            // Cycle signal

    input [1:0] n,          // Input: n signal
    input [7:0] in_data,    // Input: inVar signal
    input [STACK_LEN-1:0] in_stack,   // Input: from Stack
    
    input [7:0] cfg_state_offs,   // Config: State Offset config
    input [7:0] cfg_trans_offs,  // Config: Transition Offset config
    
    input [1:0] mux_JC,         // A Control: JC := n+2, 2, n+2, JC
    input mux_mem,              // A Control: Write to MEM @ VAR, addr

    input en_pc,                // B Control: Whether to write PC
    input en_ra,                // B Control: Whether to write PC
    input en_addr_hi,           // B Control: _data[7:4] := DATA[7:4], 0;
    input en_addr_lo,           // B Control: _data[3:0] := DATA[3:0], 0;
    input mux_RA,               // B Control: RA := offs + ~VAR, PC+1;
    input mux_pc_a1,            // B Control: PC_1 := stack[len-1:0], _data;
    input mux_pc_a2,            // B Control: PC_2 := _offs, PC+1;
    input mux_offs,             // B Control: _offs := STA_OFFSET, TRA_OFFSET 

    output [7:0] db_ra_T,
    output [7:0] db_pc_T,
    output [2:0] db_jc_T,
    
    output [7:0] db_ra_E,
    output [7:0] db_pc_E,
    output [2:0] db_jc_E,

    output [7:0] out_mem    // Output to memory
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
// Internal signals
reg [7:0] PC [1:0];
reg [7:0] RA [1:0];
reg [2:0] JC [1:0];

// Intermediate signals
wire [2:0] jc_minus_one [1:0];
wire jc_carry [1:0];
wire [STACK_LEN-2:0] trunc_out;

// Assuming trunc and 1-hot are predefined modules
trunc #(.N(STACK_LEN-1)) trunc_module (
    .truncator(in_data[STACK_LEN-2:0]),
    .signal(in_stack[STACK_LEN-1:1]),
    .truncated(trunc_out)
);

assign {jc_carry[T], jc_minus_one[T]} = JC[T] + 7; // minus 1
assign {jc_carry[E], jc_minus_one[E]} = JC[E] + 7; // minus 1

// Calculate next values
wire [7:0] pc_plus_one = PC[B] + 1;
// Multiplexers
wire [7:0] offs_mux_out = mux_offs ? cfg_state_offs : cfg_trans_offs;
wire [7:0] pc_a2_mux_out = mux_pc_a2 ? offs_mux_out : pc_plus_one;
wire [7:0] pc_a1_mux_out = mux_pc_a1 ? {3'b0, trunc_out} : ({{3{en_addr_hi}}, {5{en_addr_lo}}} & in_data);

wire [7:0] pc_a_out = pc_a2_mux_out + pc_a1_mux_out;


wire [7:0] ra_sum =  offs_mux_out + {4'hf, ~in_data[4:1]};


wire [2:0] jc_o_mux_out [1:0];
assign jc_o_mux_out[T] = jc_carry[T] ? jc_minus_one[T] : JC[T];
assign jc_o_mux_out[E] = jc_carry[E] ? jc_minus_one[E] : JC[E];


// Multiplexers
wire [7:0] pc_mux_out = (jc_minus_one[B] == 0) ? RA[B] : pc_a_out;
wire [7:0] ra_mux_out = mux_RA ? ra_sum : pc_plus_one;
wire [2:0] jc_mux_out [1:0];

assign jc_mux_out[T] = mux_JC[1] ? (
        mux_JC[0] ? n+2  : 3'd2
    ) : (
        mux_JC[0] ? JC[T] : jc_o_mux_out[T]
    );


assign jc_mux_out[E] = mux_JC[1] ? (
        mux_JC[0] ? n+2  : 3'd2
    ) : (
        mux_JC[0] ? JC[E] : jc_o_mux_out[E]
    );
    
wire en_ra_T = T_is_B & en_ra;
wire en_ra_E = E_is_B & en_ra;
wire en_jc_T = T_is_A;
wire en_jc_E = E_is_A;
wire en_pc_T = T_is_B & en_pc;
wire en_pc_E = E_is_B & en_pc;


// Program Counter logic
always @(posedge clk or posedge reset) begin: pc_proc
    if (reset) begin
        PC[0] <= 0;
        PC[1] <= 0;
        RA[0] <= 0;
        RA[1] <= 0;
        JC[0] <= 0;
        JC[1] <= 0;
    end else begin
        // Load next values into registers
        if (en_pc_T) PC[T] <= pc_mux_out;
        if (en_pc_E) PC[E] <= pc_mux_out;

        if (en_ra_T) RA[T] <= ra_mux_out;
        if (en_ra_E) RA[E] <= pc_plus_one;

        if (en_jc_T) JC[T] <= jc_mux_out[T];
        if (en_jc_E) JC[E] <= jc_mux_out[E];
    end
end

// Output to memory is the PC unless specified otherwise
assign out_mem = PC[A];

/*
Debug
*/
assign db_pc_T = PC[T];
assign db_ra_T = RA[T];
assign db_jc_T = JC[T];

assign db_pc_E = PC[E];
assign db_ra_E = RA[E];
assign db_jc_E = JC[E];

endmodule

module decrementer(
    input [2:0] in,
    output [2:0] out,
    output c
);

    // Decrement the input value by 1
    assign {c, out} = in - 1'b1;
endmodule
