`timescale 1ns / 1ps
(* KEEP_HIERARCHY = "TRUE" *)
module top #(parameter TICK_BITS=32, parameter PROG_BITS = 8,parameter STACK_LEN = 6, parameter MEM_LEN=128) (
    input clk,
    input reset,
    
    input scan_in,
    input scan_en,
    input scan_reset,
    output scan_out,
    output db_out_0,
    output db_out_1,
    output db_out_2,
    output db_out_3,
    output db_out_4,
    output event_flush,
    output event_setup,

`ifdef XILINX_SIMULATOR
    // Debug outputs for state variables
    output [7:0] db_es_tran, 
    output [7:0] db_es_edit,
    output db_cycle,
    output [TICK_BITS-1:0] db_global_clock,
    output [STACK_LEN-1:0] db_stack_E,
    output [STACK_LEN-1:0] db_stack_T,
    output [31:0] db_inputs,
    output [31:0] db_inputs_valid,
    output [31:0] db_outputs,
    output [3:0] db_next_state,
    output [7:0] db_data_A,
    output [7:0] db_data_B,
    output db_hi,

    output [7:0] db_ra_T,
    output [7:0] db_pc_T,
    output [2:0] db_jc_T,
        
    output [7:0] db_ra_E,
    output [7:0] db_pc_E,
    output [2:0] db_jc_E,

    output [7:0] db_rd_mem0,
    output [7:0] db_rd_mem1,

    output [3:0] db_clock_0,
    output [11:0] db_clock_1,
    output [3:0] db_clock_2,
    output [11:0] db_clock_3,
    output [3:0] db_clock_4,
    output [11:0] db_clock_5,
    output [3:0] db_clock_6,
    output [11:0] db_clock_7,

    output db_event_setup,
    output db_event_flush,
`endif

    input [31:0] inputs,
    output [31:0] outputs,
    output violation

    );


`ifndef XILINX_SIMULATOR
    /*
    debug wires to make synthesis OK
    */
    wire [7:0] db_es_tran; 
    wire [7:0] db_es_edit;
    wire db_cycle;
    wire [TICK_BITS-1:0] db_global_clock;
    wire [STACK_LEN-1:0] db_stack_E;
    wire [STACK_LEN-1:0] db_stack_T;
    wire [31:0] db_inputs;
    wire [31:0] db_inputs_valid;
    wire [31:0] db_outputs;
    wire [31:0] db_wires;
    wire [3:0] db_next_state;
    wire [7:0] db_data_A;
    wire [7:0] db_data_B;
    wire db_hi;

    wire [7:0] db_ra_T;
    wire [7:0] db_pc_T;
    wire [2:0] db_jc_T;
        
    wire [7:0] db_ra_E;
    wire [7:0] db_pc_E;
    wire [2:0] db_jc_E;

    wire [7:0] db_rd_mem0;
    wire [7:0] db_rd_mem1;
    wire [3:0] db_clock_0;
    wire [11:0] db_clock_1;
    wire [3:0] db_clock_2;
    wire [11:0] db_clock_3;
    wire [3:0] db_clock_4;
    wire [11:0] db_clock_5;
    wire [3:0] db_clock_6;
    wire [11:0] db_clock_7;

    wire db_event_setup;
    wire db_event_flush;
`endif



    /*
    CONFIGURATION
    */
    // Config Variables
    wire [7:0] cfg_state_offs;
    wire [7:0] cfg_trans_offs;
    wire [PROG_BITS-1:0] cfg_prog_len;
    wire [TICK_BITS-1:0] cfg_tick_len;
    wire [31:0] cfg_clk_flags;
    wire [7:0] cfg_clk_joins;
    wire [39:0] cfg_div_limits;

    /*
    Intermediate Signals
    */
    // Main Intermediate Busses
    // A cycle (Grey)
    wire [7:0] A_mem_out_1;
    wire [7:0] A_mem_out_2;
    wire [7:0] A_data;
    wire [3:0] A_next_state;
    wire [7:0] A_flow_addr;
    wire [7:0] A_mem_addr;
    wire A_clk_constraint_val;

    // B Cycle (Black)
    wire [7:0] B_data;
    wire [STACK_LEN-1:0] B_stack;
    wire B_input_read_val;
    wire B_read_valid;

    // Cycle
    wire cycle;


    // Config Module
    
    config_module #(MEM_LEN, PROG_BITS, TICK_BITS) cfg (
        .clk(clk),
        .reset(scan_reset),
        .scan_in(scan_in),
        .scan_en(scan_en),
        .scan_out(scan_out),
        // For reading from Mem
        .addr(A_mem_addr),
        
        // Mem output
        .d_out_0(A_mem_out_1),
        .d_out_1(A_mem_out_2),
        
        // config output.
        .cfg_state_offs(cfg_state_offs),
        .cfg_trans_offs(cfg_trans_offs),
        .cfg_prog_len(cfg_prog_len),
        .cfg_tick_len(cfg_tick_len),
        .cfg_clk_flags(cfg_clk_flags),
        .cfg_clk_joins(cfg_clk_joins),
        .cfg_clk_div_imm(cfg_div_limits)
    );
    

    
    
    
    /*
    Multi-bit control Signals declaration
    */
    // A control signals
    // Program flow
    wire [1:0] mux_JC;         // A Control: JC := n+2, 2, n+2, JC
    // Parsing
    wire [1:0] mux_var;        // A Control: _var := (~addr + ~n), {nxt_state, _flag_b}, nib, 
    wire [1:0] mux_sta;        // B Control: STACK[0] <= ACC, STA, val, val


    controller #(.TICK_BITS(TICK_BITS), .PROG_BITS(PROG_BITS)) con_module (
        .clk(clk),
        .reset(reset),

        .insn(A_mem_out_1),            // Instruction from mem
        .data_hi(B_data[7:5]),        // B Opcode, taken from var.

        .cfg_tick_len(cfg_tick_len),
        .cfg_prog_len(cfg_prog_len),

        .input_invalid(~B_read_valid),               // Clock constraint interrupt

        // Debug outputs
        .db_es_tran(db_es_tran),
        .db_es_edit(db_es_edit),
        .cycle(cycle),
        .db_global_clock(db_global_clock),

        // A control signal outputs
        // Program flow
        .mux_JC(mux_JC),         // A Control: JC := n+2, 2, n+2, JC
        .mux_mem(mux_mem),              // A Control: Write to MEM @ VAR, addr
        // Parsing
        .flag_b(flag_b),               // A Control: _flag_b := 1, 0
        .mux_var(mux_var),        // A Control: _var := (~addr + ~n), {nxt_state, _flag_b}, nib, 
        .en_d4(en_d4),                // A Control: Write to VAR[4]
        .en_var3(en_var3),              // A Control: Write to VAR[3:0]
        .en_op(en_op),                // A Control: Write to OP
        // Clock Module
        .en_clk_reset(en_clk_reset),         // A Control: Reset the clock
        .en_wr_input(en_wr_input),          // A Control: Write clock constraint to inputs module
        // B control signals
        // Prgogram flow 
        .en_pc(en_pc),                // B Control: Whether to write PC
        .en_ra(en_ra),                // B Control: Whether to write PC
        .en_addr_hi(en_addr_hi),           // B Control: _data[7:4] := DATA[7:4], 0;
        .en_addr_lo(en_addr_lo),           // B Control: _data[3:0] := DATA[3:0], 0;
        .mux_RA(mux_RA),               // B Control: RA := offs + ~VAR, PC+1;
        .mux_pc_a1(mux_pc_a1),            // B Control: PC_1 := stack[len-1:0], _data;
        .mux_pc_a2(mux_pc_a2),            // B Control: PC_2 := _offs, PC+1;
        .mux_offs(mux_offs),             // B Control: _offs := STA_OFFSET, TRA_OFFSET 
        // Parsing
        .mux_hi(mux_hi),               // B Control: HI <= stack0, VAR[0];
        .en_hi(en_hi),              // B Control: Write to HI
        .en_next_state(en_next_state),        // B Control: Enable writing to next state
        // Output Module
        .en_edit(en_edit),              // B Control: Edit outputs
        .mux_data(mux_data),             // B Control: OUTPUTS[VAR] <= inputs, val
        // Stack Module
        .en_push_force(en_push_force),        // B Control: Force a push
        .en_pop(en_pop),               // B Control: Whether a pop command should trigger a pop
        .en_push(en_push),              // B Control: Whether a ~pop command should trigger a push
        .en_pop_force(en_pop_force),        // B Control: Force a pop
        .en_stack_wr(en_stack_wr),          // B Control: Whether to write to stack
        .mux_sta(mux_sta),        // B Control: STACK[0] <= ACC, STA, val, val

        // Unknown control
        // Inputs/Outputs module

        .event_flush(event_flush),          // Anytime Control: Induce flush of output buffer. 
        .event_setup(event_setup)           // Anytime Control: Induce setup.
    );


    /*
    Input data routing
    */
    wire [31:0] edit_result; // Output buffer
    wire [31:0] current_inputs; // input buffer
    
    wire violation_result = | ((edit_result ^ current_inputs) & ~cfg_clk_flags);
    
    buf_reg #(.N(32)) out_reg(clk, reset, event_flush, edit_result, outputs);
    buf_reg vio_reg(clk, reset, event_flush, violation_result, violation);
    
    
    /*
    
    Program Flow
    */
    program_flow pf_module (
        .clk(clk),              // Clock signal
        .reset(reset),            // Asynchronous reset signal
        .cycle(cycle),

        .n(A_mem_out_1[5:4]),              // Input: n signal
        .in_data(B_data),        // Input: inVar signal
        .in_stack(B_stack),       // Input: from Stack
      
        .cfg_state_offs(cfg_state_offs),   // Config: State Offset config
        .cfg_trans_offs(cfg_trans_offs),   // Config: Transition Offset config
        
        .en_pc(en_pc),                // B Control: Whether to write PC
        .en_ra(en_ra),                // B Control: Whether to write PC
        .en_addr_hi(en_addr_hi),           // B Control: _data[7:4] := DATA[7:4], 0;
        .en_addr_lo(en_addr_lo),           // B Control: _data[3:0] := DATA[3:0], 0;
        .mux_RA(mux_RA),               // B Control: RA := offs + ~VAR, PC+1;
        .mux_pc_a1(mux_pc_a1),            // B Control: PC_1 := stack[len-1:0], _data;
        .mux_pc_a2(mux_pc_a2),            // B Control: PC_2 := _offs, PC+1;
        .mux_offs(mux_offs),             // B Control: _offs := STA_OFFSET, TRA_OFFSET 

        .mux_JC(mux_JC),         // A Control: JC := n+2, 2, n+2, JC
        .mux_mem(mux_mem),              // A Control: Write to MEM @ VAR, addr

        // Debug    
        .db_ra_T(db_ra_T),
        .db_pc_T(db_pc_T),
        .db_jc_T(db_jc_T),
        
        .db_ra_E(db_ra_E),
        .db_pc_E(db_pc_E),
        .db_jc_E(db_jc_E),
        
        .out_mem(A_flow_addr)    // Output to memory
    );
    
    /*
    Parsing
    */
    buf_reg #(.N(4)) reg_nxt_state(clk, reset, en_next_state, B_data[3:0], A_next_state);
    
    parsing p_module (
        .clk(clk),             // Clock signal
        .reset(reset),           // Asynchronous reset signal
        .cycle(cycle),
        
        .in_mem(A_mem_out_1),        // 8-bit input from memory
        .nxt_state(A_next_state),     // 4-bit next state
        .stack0(B_stack[0]),              // lsb of stack.
        
        .mux_var(mux_var),       // Control: 
        .en_d4(en_d4),               // Control: Enable signal for DATA[4]
        .en_var3(en_var3),
        .en_op(en_op),
        .mux_hi(mux_hi),              // Control: 
        .en_hi(en_hi),
        .flag_b(flag_b),              // Control: 
        
        // debug
        .db_hi(db_hi),

        // outputs
        .out_data_A(A_data),     // 8-bit output data
        .out_data_B(B_data)     // 8-bit output data
    );
    wire _clk_lng = A_mem_out_1[7];
    wire _clk_op = A_mem_out_1[6];
    wire [1:0] _clk_addr = A_mem_out_1[5:4];
    clocks_module clk_module (
        .clk(clk),                       // Clock signal
        .reset(reset),                     // Asynchronous reset signal
        .en(event_flush),

        // Clock constraint calculation
        .lng(_clk_lng ),                     // Whether we are selecting from 4-bit or 12-bit clocks
        .op(_clk_op),                       // Which operation to perform to produce out_val. op=1 is equals, op=0 is less than
        .addr(_clk_addr),               // Which clock to use
        .imm_lo(A_mem_out_1[3:0]),             // lower bits of comparison value for 4-bit clocks
        .imm_hi(A_mem_out_2),             // higher bits of comparison value for 12-bit clocks
        
        // Clock reset
        .en_clk_reset(en_clk_reset),        // Control: Whether to perform a clock reset 
        .clk_reset(B_data),            // which clocks to reset
        
        // Config
        .cfg_clk_joins(cfg_clk_joins),         // Whether particular clocks are joined to each other.
        .cfg_div_limits(cfg_div_limits),       // 10-bit clock divider values
        
        .db_clock_0(db_clock_0),
        .db_clock_1(db_clock_1),
        .db_clock_2(db_clock_2),
        .db_clock_3(db_clock_3),
        .db_clock_4(db_clock_4),
        .db_clock_5(db_clock_5),
        .db_clock_6(db_clock_6),
        .db_clock_7(db_clock_7),
        // Output
        .out_val(A_clk_constraint_val)                  // result of clock constraint
    );


    /*
    Input loading
    */
//    input_capture i_buf (
//        .clk(clk),
//        .r(event_setup),
//        .s(),
//        .
    
    inputs_module i_module (
        .clk(clk),                 // Clock signal
        .reset(reset),               // Asynchronous reset signal


        .cfg_clk_flags(cfg_clk_flags),    // Config for which addresses are clocks
        
        // Input write clock constraint
        .wr_addr(A_data[4:0]),                   // 5-bit address
        .en_wr_input(en_wr_input),               // Control: signal    
        .val(A_clk_constraint_val),              // value to write, produced by clock module
        
        // Load next set of inputs
        .en_load_input(event_setup),          // Control: signal indicating whether to load input data at this time.
        .in_data(inputs),                       // Input data at interception
        
        // Combinatorial read 
        .rd_addr(B_data[4:0]),       // 5-bit address
        
        // Debug outputs
        .db_inputs_valid(db_inputs_valid),

        // outputs
        .out_data(current_inputs),     // data read from address
        .out_valid(B_read_valid),    // Whether requested data has been computed
        .out_val(B_input_read_val)    // data value

    );

    outputs_module o_module(
        .clk(clk),                 // Clock signal
        .reset(reset),               // Asynchronous reset signal
        
        .addr(B_data[4:0]),              // 5-bit address
        .do_write(B_stack[0]),           // Condition flag deciding whether to perform write at addr.
        .val(B_data[6]),                 // value to write in 

        .in_data(inputs),                // Setup: Input data at interception.
            
        .en_edit(en_edit),               // Control: Enable writing to addr conditional on do_write_flag
        .en_load_input(event_setup),   // Control: Global output enable
        .mux_data(mux_data),             // Control: Get input data source
        
        .out_buf(edit_result)  // 32-bit output buffer register
    );

    wire [1:0] _c_op = B_data[7:6];
    wire _c_do_pop = B_data[4];
    
    calculation_module c_module (
        .clk(clk),                      // Clock signal
        .reset(reset | event_setup),    // Asynchronous reset signal
        .cycle(cycle),
        
        .lut(B_data[3:0]),              // Look-Up Table input
        .op(_c_op),               // Operation code
        .do_pop(_c_do_pop),             // Pop control signal
        .val(B_input_read_val),         // Input value for stack operations
        
        .en_pop(en_pop),                // Control: Pop enable signal
        .en_push(en_push),              // Control: Push enable signal
        .en_push_force(en_push_force),  // Control: Force push signal
        .en_pop_force(en_pop_force),    // Control: Force pop signal
        .en_stack_wr(en_stack_wr),      // Control: Stack write enable signal
        .mux_sta(mux_sta),              // Control: signal for STA mux
            //debug outputs
        .db_stack_E(db_stack_E),     // Stack output data
        .db_stack_T(db_stack_T),     // Stack output data
    
        .out_stack(B_stack)             // Stack output data
    );


    // MEM mux
    assign A_mem_addr = mux_mem ? {3'b0, A_data[4:0]} : A_flow_addr;

    /*
    Additional dbug outputs
    */
    
    assign db_inputs=current_inputs;
    assign db_outputs=edit_result;

    assign db_next_state=A_next_state;
    assign db_data_B=B_data;
    assign db_data_A=A_data;

    assign db_rd_mem0=A_mem_out_1;
    assign db_rd_mem1=A_mem_out_2;
    assign db_cycle=cycle;
    assign db_event_flush=event_flush;
    assign db_event_setup=event_setup;
    
    // debug thingo
    localparam STATE_SIZE = 2;
    reg [31:0] _db_counter = 0;
    reg [STATE_SIZE - 1:0] _db_state = 0;
    reg [4:0] _db_vec = 0;
    always @(posedge clk) begin
        if (db_event_setup) begin
            _db_counter <= 0;
            _db_state <= 0;
        end else if (cycle) begin
            if (_db_counter == cfg_tick_len[TICK_BITS - 1: STATE_SIZE]) begin
                _db_counter <= 0;
                _db_state <= _db_state + 1;
            end else begin
                _db_counter <= _db_counter + 1;
            end
        end 
    end
    always @(*) begin
        case(_db_state)
            0: _db_vec = 5'b10000;
            1: _db_vec = {1'b0, db_clock_0}; // 10 hz
            2: _db_vec = {1'b0, db_clock_4}; // 
            3: _db_vec = {1'b0, db_next_state};
        endcase
    end
    assign db_out_0 = _db_vec[0];
    assign db_out_1 = _db_vec[1];
    assign db_out_2 = _db_vec[2];
    assign db_out_3 = _db_vec[3];
    assign db_out_4 = _db_vec[4];
endmodule
