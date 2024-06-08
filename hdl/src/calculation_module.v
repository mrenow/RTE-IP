module calculation_module #(
    parameter DEPTH = 6  // Depth of the stack
) (
    input clk,             // Clock signal
    input reset,           // Asynchronous reset signal
    input cycle,
    
    input [3:0] lut,       // Look-Up Table input
    input [1:0] op,        // Operation code
    input do_pop,          // Pop control signal
    input val,             // Input value for stack operations
    
    input en_push_force,        // B Control: Force a push
    input en_pop,               // B Control: Whether a pop command should trigger a pop
    input en_push,              // B Control: Whether a ~pop command should trigger a push
    input en_stack_wr,          // B Control: Whether to write to stack
    input [1:0] mux_sta,        // B Control: STACK[0] <= ACC, STA, val, val
    
    //debug outputs
    output [DEPTH-1:0] db_stack_E,     // Stack output data
    output [DEPTH-1:0] db_stack_T,     // Stack output data
    

    output [DEPTH-1:0] out_stack  // Stack output data
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
    
    
    wire [DEPTH-1:0] stack_data_out [0:1];     // Data to be pushed onto the stack
    
    // Stack data input selection

    wire stack0 = stack_data_out[B][0];
    wire [1:0] intm2 = {val, stack0};
    wire [1:0] intm = {op[1] ^ intm2[1], op[0] ^ intm2[0]};
    
    wire lu_acc_out = |(intm);
    wire lu_op_out = lut[op];
    wire stack_data_in = mux_sta[1]?
        (mux_sta[0]? lu_acc_out : lu_op_out):
        val;

        
    shift_register #(.N(DEPTH)) SH_REG_T  (
        .clk(clk), .reset(reset),   
        .wr_en(en_stack_wr & T_is_B),  
        .wr_data(stack_data_in),
        .pop(en_pop & do_pop & T_is_B),    
        .push(((en_push & ~do_pop) | en_push_force) & T_is_B),
        .out_stack(stack_data_out[T])
    );

    shift_register #(.N(DEPTH)) SH_REG_E  (
        .clk(clk), .reset(reset),   
        .wr_en(en_stack_wr & E_is_B),  
        .wr_data(stack_data_in),
        .pop(en_pop & do_pop & E_is_B),    
        .push(((en_push & ~do_pop) | en_push_force) & E_is_B),
        .out_stack(stack_data_out[E])
    );

    assign out_stack = stack_data_out[B][DEPTH-1:0];

    assign db_stack_E = stack_data_out[E];
    assign db_stack_T = stack_data_out[T];
    
endmodule
