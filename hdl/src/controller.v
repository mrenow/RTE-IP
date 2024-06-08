
`include "register.v"


module controller #(parameter TICK_BITS=16, parameter PROG_BITS = 8)(
    input clk,
    input reset,

    input [7:0] insn,           // A Instruction from mem
    input [2:0] data_hi,        // B Opcode, taken from var.

    input [TICK_BITS-1: 0] cfg_tick_len,
    input [PROG_BITS-1: 0] cfg_prog_len,

    input input_invalid,               // Clock constraint interrupt

    // Debug outputs
    output [7:0] db_es_tran,
    output [7:0] db_es_edit,
    output cycle,
    output [TICK_BITS-1:0] db_global_clock,

    // A control signals
    // Program flow
    output reg [1:0] mux_JC,         // A Control: JC := n+2, 2, n+2, JC
    output reg mux_mem,              // A Control: Write to MEM @ VAR, addr
    // Parsing
    output flag_b,               // A Control: _flag_b := 1, 0
    output reg [1:0] mux_var,        // A Control: _var := (~addr + ~n), {nxt_state, _flag_b}, nib, 
    output reg en_d4,                // A Control: Write to VAR[4]
    output reg en_var3,              // A Control: Write to VAR[3:0]
    output reg en_op,                // A Control: Write to OP
    // Clock Module
    output reg en_clk_reset,         // A Control: Reset the clock
    // inputs
    output reg en_wr_input,          // A Control: Write clock constraint to inputs module
    // B control signals
    // Prgogram flow 
    output reg en_pc,                // B Control: Whether to write PC
    output reg en_ra,                // B Control: Whether to write PC
    output reg en_addr_hi,           // B Control: _data[7:4] := DATA[7:4], 0;
    output reg en_addr_lo,           // B Control: _data[3:0] := DATA[3:0], 0;
    output reg mux_RA,               // B Control: RA := offs + ~VAR, PC+1;
    output reg mux_pc_a1,            // B Control: PC_1 := stack[len-1:0], _data;
    output reg mux_pc_a2,            // B Control: PC_2 := _offs, PC+1;
    output reg mux_offs,             // B Control: _offs := STA_OFFSET, TRA_OFFSET 
    // Parsing
    output reg mux_hi,               // B Control: HI = stack0, VAR[0];
    output reg en_hi,                // B Control: Write to HI
    output reg en_next_state,        // B Control: Enable writing to next state
    // Output Module
    output reg en_edit,              // B Control: Edit outputs
    output reg mux_data,             // B Control: OUTPUTS[VAR] = inputs, val
    // Stack Module
    output reg en_push_force,        // B Control: Force a push
    output reg en_pop,               // B Control: Whether a pop command should trigger a pop
    output reg en_push,              // B Control: Whether a ~pop command should trigger a push
    output reg en_stack_wr,          // B Control: Whether to write to stack
    output reg [1:0] mux_sta,        // B Control: STACK[0] = ACC, STA, val, val

    // Unknown control

    output event_flush,          // Anytime Control: Induce flush of output buffer. 
    output event_setup           // Anytime Control: Induce setup.
    );
    /*
    # Transition Machine States
    INIT
    STD
    ACC
    NXT
    TRA
    RST

    # Edit Machine States
    INIT
    STD
    ACC
    EACC
    EDIT
    */
    // Unpack VAR inputs
    wire ex = data_hi[0];
    wire finish = data_hi[2];
    wire [2:0] B_op_code = data_hi;

    localparam FINISH = 8'b0000_0000;
    localparam SETUP =   8'b0000_0001;
    localparam INIT =   8'b0000_0010;
    
    localparam STD =    8'b1000_0001;
    localparam ACC =    8'b1000_0010;
    localparam E_ACC =  8'b0100_0010;
    
    localparam PSH_CLK = 8'b1000_0101;
    localparam ACC_CLK = 8'b1000_0110;
    localparam E_ACC_CLK = 8'b0100_0110;
        
    localparam T_NXT =  8'b1100_0000;
    localparam T_TRA =  8'b1100_0001;
    localparam T_RST =  8'b1100_0010;
    localparam E_EDIT = 8'b0100_0001;




    reg CYCLE;
    reg [7:0] ES [1:0];

    wire [2:0] A_op_code = insn[7:5];

    localparam E = 1;
    localparam T = 0;
    localparam EVEN = 0; 
    localparam ODD = 1;
    // Aliases
    wire A = CYCLE;
    wire B = ~CYCLE;

    wire T_is_A = CYCLE == EVEN;
    wire T_is_B = CYCLE == ODD;
    wire E_is_A = CYCLE == ODD;
    wire E_is_B = CYCLE == EVEN;

    /*
    C: 0 1 0 1 0 1 ...
    T: A B A B A B ...
    E: B A B A B A ...

    To get the state of the machine in cycle A:
    ES[A]
    For B:
    ES[B]
    */


    /*
    If cycle is EVEN:
        Trans machine: Cycle A
        Edit machine: Cycle B
    If cycle is ODD:
        Trans machine: Cycle B
        Edit machine: Cycle A
    */

    // Ticks occur every two clock cycles, so
    // this needs to be one more than the actual clock length
    reg [TICK_BITS: 0] global_clock;



    wire do_cycle;
    

    // output [1:0] mux_JC,         // A Control: JC := n+2, 2, JC, DEC JC
    // output reg mux_mem,              // A Control: Write to MEM @ addr, VAR
    // // Parsing
    // output flag_b,               // A Control: _flag_b := 1, 0
    // output [1:0] mux_var,        // A Control: _var := (~addr + ~n), {nxt_state, _flag_b}, nib, 
    // output en_d4,                // A Control: Write to VAR[4]
    // output en_var3,              // A Control: Write to VAR[3:0]
    // output en_op,                // A Control: Write to OP
    // // Clock Module
    // output en_wr_input,          // A Control: Write clock constraint to inputs module

    // Combinatorial block to determine A control signals.
    assign flag_b = E_is_A;
    always @(*) begin: A_Signals
            
        // B section
        {mux_JC, mux_var, mux_mem} = 0;
        {en_d4, en_var3, en_op} = 3'b111;
        {en_wr_input} = 0;
        case (ES[A])
            SETUP: begin
                mux_var = 2; // {nxt_state, _flag_b}
            end
            INIT: begin
                // addr:=MEM[VAR]
                // {OP,EX,VAR}=addr
            end
            STD: begin
                case (A_op_code[2:1])
                    2'b00: begin
                        if (T_is_A) begin
                            if (~A_op_code[0]) begin
                                // NXT1
                                mux_JC = 2'b11; // n+2
                            end
                        end 
                    end
                    2'b01: begin
                    end
                    2'b10: begin
                    end
                    2'b11: begin
                        mux_JC = 2'b10; // 2
                        mux_var = 2'b11;
                    end

                endcase
            end

            // ACC:    begin end
            // E_ACC:  begin end
            PSH_CLK:    begin
                // {_,op,clk,imm}:=MEM[VAR]
                mux_mem = 1; // Write to MEM @ VAR
                // val:=CLKS[{clk,0}]
                en_wr_input = 1; // Enable write to IN
                // if op:
                // -> IN[VAR]=(val==imm)
                // else:
                // -> IN[VAR]=(val<imm)
                // IN_INVALID[VAR] = 0
                // Ensure that no data is written over the old VAR, D4, OP
                {en_var3, en_op, en_d4}  = 0;
                // JC = JC
                mux_JC = 2'b01; // JC = JC
            end
            ACC_CLK:  begin
                // Identical to above
                mux_mem = 1; // Write to MEM @ VAR
                en_wr_input = 1;
                {en_var3, en_op, en_d4} = 0;
                mux_JC = 2'b01; // JC = JC
            end
            E_ACC_CLK:  begin
                // Identical to above
                mux_mem = 1; // Write to MEM @ VAR
                en_wr_input = 1;
                {en_var3, en_op, en_d4} = 0;
                mux_JC = 2'b01; // JC = JC
            end

            T_NXT: begin
                en_d4 = 0;
                mux_var = 1; // nib
                mux_JC = 2; // 2
            end

            T_TRA: begin
                mux_var = 1; // nib
            end

            // T_RST: begin end
            // E_EDIT: begin end
            FINISH: begin
                en_var3 = 0;
                en_d4 = 0;
            end
        endcase

    end
    
    // output reg en_pc,                // B Control: Whether to write PC
    // output reg en_ra,                // B Control: Whether to write PC
    // output reg en_addr_hi,           // B Control: _data[7:4] := DATA[7:4], 0;
    // output reg en_addr_lo,           // B Control: _data[3:0] := DATA[3:0], 0;
    // output reg mux_RA,               // B Control: RA := offs + ~VAR, PC+1;
    // output reg mux_pc_a1,            // B Control: PC_1 := stack[len-1:0], _data;
    // output reg mux_pc_a2,            // B Control: PC_2 := _offs, PC+1;
    // output reg mux_offs,             // B Control: _offs := STA_OFFSET, TRA_OFFSET 
    // // Parsing
    // output reg mux_hi,               // B Control: HI = stack0, VAR[0];
    // output reg en_next_state,        // B Control: Enable writing to next state
    // // Output Module
    // output reg en_edit,              // B Control: Edit outputs
    // output reg mux_data,             // B Control: OUTPUTS[VAR] = inputs, val
    // // Stack Module
    // output reg en_push_force,        // B Control: Force a push
    // output reg en_pop,               // B Control: Whether a pop command should trigger a pop
    // output reg en_push,              // B Control: Whether a ~pop command should trigger a push
    // output reg en_stack_wr,          // B Control: Whether to write to stack
    // output reg [1:0] mux_sta,        // B Control: STACK[0] = ACC, STA, val, val
    // State machine

    reg [7:0] next_es_B;
    always @(*) begin: B_Transitions
        // next_es_B = ES[B];
        case (ES[B])
            SETUP: next_es_B = INIT;
            INIT: next_es_B = STD;
            STD: begin
                case (B_op_code[2:1])
                2'b00: next_es_B = T_is_B ? (B_op_code[0] ? T_NXT : T_TRA) : (ex ? E_ACC: E_EDIT);
                2'b01: next_es_B = ex ? ACC : STD;
                2'b10: next_es_B = input_invalid? PSH_CLK : (ex ? ACC : STD);
                2'b11: next_es_B = STD;
                endcase
            end
            
            PSH_CLK: next_es_B = input_invalid? PSH_CLK : (ex ? ACC : STD);
            
            ACC: next_es_B = input_invalid ? ACC_CLK : (ex ? ACC : STD);
            ACC_CLK: next_es_B = input_invalid ? ACC_CLK : (ex ? ACC : STD);

            E_ACC: next_es_B = input_invalid ? E_ACC_CLK: (ex ? E_ACC : E_EDIT);
            E_ACC_CLK: next_es_B = input_invalid ? E_ACC_CLK: (ex ? E_ACC : E_EDIT);

            T_NXT: next_es_B = T_RST;
            T_RST: next_es_B = T_TRA;
            T_TRA: next_es_B = FINISH;
            FINISH: next_es_B = do_setup ? SETUP : FINISH;
            E_EDIT: next_es_B = finish ? FINISH : (ex ? E_EDIT : STD);
        endcase
    end

    always @(posedge clk or posedge reset) begin: B_States
        if (reset) begin
            ES[T] = FINISH;
            ES[E] = FINISH; // Work On edit machine later
            CYCLE = EVEN;
        end else begin
            if (T_is_B) ES[T] = next_es_B;
            else ES[E] = next_es_B;
            CYCLE = ~CYCLE;
        end
    end

    always @(*) begin: B_Signals
        // Default values
        en_pc = 1; // Update PC
        en_ra = 0; // Dont update RA
        en_addr_hi = 0; // _data[7:4] := 0;
        en_addr_lo = 0; // _data[3:0] := 0;
        mux_RA = 0; // RA := PC+1
        mux_pc_a1 = 0; // PC_1 := _data
        mux_pc_a2 = 0; // PC_2 := PC+1
        mux_offs = 0; // _offs := TRA_OFFSET
        // Parsing
        mux_hi = 0; // Hi = Var[0]
        en_next_state = 0;
        // Module
        en_edit = 0; // Dont edit outputs
        mux_data = 0; // OUTPUTS[VAR] = 0
        // Stack Module
        en_push_force = 0; // Dont force a push
        en_pop = 0; // Dont pop
        en_push = 0; // Dont push
        en_stack_wr = 0; // Dont write to stack
        mux_sta = 0; // STACK[0] = val
        en_hi = 0; // Dont write to HI
        en_clk_reset = 0;
        // B section 
        case (ES[B])
            SETUP: begin
                // PC = DATA[5:0] + STA_OFFSET
                en_addr_lo = 1; // VAR = DATA[5:0]
                mux_pc_a1 = 0; // _data
                mux_pc_a2 = 1; // _offs
                mux_offs = 1; // STA_OFFSET
            end
            INIT: begin
                // addr:={OP,EX,VAR}
                // PC=addr + TRAN_OFFS
                // ES=STD
                en_addr_hi = 1;
                en_addr_lo = 1;
                mux_pc_a1 = 0; // _data
                mux_pc_a2 = 1; // _offs
                mux_offs = 0; // TRA_OFFSET
            end
            STD: begin
                case (B_op_code[2:1])
                2'b00: begin
                    if (T_is_B) begin
                        //NXT
                        if (B_op_code[0]) begin
                            // NXT 0
                            // {_,len}:=VAR
                            // val:=stack[len-1:1]
                            // RA=PC + 1 + val
                            // ES=NXT
                            // HI=$0
                            mux_hi = 1; // $0
                            en_hi = 1;
                            mux_offs = 0; // TRA_OFFSET
                            mux_pc_a1 = 1; // stack[len-1:1]
                            mux_pc_a2 = 0; // PC+1
                        end else begin
                            // NXT1
                            // HI=VAR[0]
                            // RA=TRA_OFFSET + ~(VAR>>1)
                            // PC=TRA_OFFSET + VAR
                            // ES=TRA
                            mux_hi = 0;
                            en_hi = 1;
                            en_ra = 1;
                            mux_RA = 1; // offs + ~VAR
                            mux_offs = 0; // TRA_OFFSET
                            mux_pc_a1 = 0; // _data
                            mux_pc_a2 = 1; // _offs
                            en_addr_lo = 1;
                        end
                    end else begin
                        // VIO
                        // {pop,lut}:=VAR
                        // If pop:
                        // -> POP()
                        en_pop = 1;
                        // $0=lut[{$1,$0}]
                        // If EX:
                        // -> ES=EACC
                    end
                end
                2'b10: begin
                    // PSH
                    // If IN_INVALID[VAR]:
                    // -> PC_EN = 0
                    // -> ES = CLK
                    // else:
                    // -> PUSH()
                    // -> $0=IN[VAR]
                    // -> If EX:
                    // ---> ES=ACC
                    if (input_invalid) begin
                        en_pc = 0;
                    end else begin
                        en_push = 1;
                        en_push_force = 1;
                        en_stack_wr = 1;
                        mux_sta = 0;
                        mux_data = 1;
                    end
                end
                2'b01: begin
                    // OP
                    // {pop,lut}:=VAR
                    // If pop:
                    // -> POP()
                    en_pop = 1;
                    // else:
                    // -> PUSH()
                    en_push = 1;
                    // $0=lut[{$1, $0}]
                    // If EX:
                    // -> ES=ACC
                    en_stack_wr = 1;
                    mux_sta = 2; // STA
                end
                2'b11: begin
                    // DO
                    // RA=PC+1
                    // PC=PC+1+VAR
                    mux_RA = 0; // PC+1
                    en_ra = 1;
                    mux_pc_a1 = 0; // _data
                    mux_pc_a2 = 0; // PC+1
                end
            endcase
            end
            
            PSH_CLK:    begin
                // Copied from psh signals
                if (input_invalid) begin
                    // this should never happen
                    en_pc = 0;
                end else begin
                    en_push = 1;
                    en_push_force = 1;
                    en_stack_wr = 1;
                    mux_sta = 0;
                    mux_data = 1;
                end
            end

            ACC:    begin
                // If IN_INVALID[VAR]:
                // -> PC_EN = 0
                // -> ES = CLK_ACC
                // else:
                // -> $0=(OP[0]^$0)&(OP[1]^IN[VAR])
                // -> If !EX:
                // ---> ES=STD    
                if (input_invalid) en_pc = 0;
                else begin
                    en_stack_wr = 1;
                    mux_sta = 2'b11; // ACC
                end
            end

            ACC_CLK:    begin
                if (input_invalid) en_pc = 0;
                else begin
                    en_stack_wr = 1;
                    mux_sta = 2'b11; // ACC
                end
            end


            E_ACC:  begin
                if (input_invalid) en_pc = 0;
                else begin
                    en_stack_wr = 1;
                    mux_sta = 2'b11; // ACC
                end
            end
            E_ACC_CLK:  begin
                if (input_invalid) en_pc = 0;
                else begin
                    en_stack_wr = 1;
                    mux_sta = 2'b11; // ACC
                end
            end

            T_NXT: begin
                // HI=VAR[0]
                // RA=TRA_OFFSET + ~(VAR>>1)
                // PC=TRA_OFFSET + VAR
                // ES=TRA
                en_hi = 1;
                mux_hi = 0; // VAR[0]
                mux_RA = 1; // offs + ~VAR
                en_ra = 1;
                mux_offs = 0; // TRA_OFFSET
                mux_pc_a1 = 0; // _data
                mux_pc_a2 = 1; // _offs
                en_addr_lo = 1;
            end

            T_TRA: begin
                // NEXT_STATE=VAR[3:0]
                // ES=RST
                en_next_state = 1;
            end

            T_RST: begin
                // rst:=VAR
                // apply rst
                // ES=FINISH
                en_clk_reset = 1;
            end

            E_EDIT: begin
                // Done
                en_edit = 1;
                en_pop = ~(finish| ex);
            end
            FINISH: begin
                // TODO: Check timing
                en_pc = 0;
                en_ra = 0;
            end
        endcase
    end


    wire final_tick = global_clock == {cfg_tick_len, 1'b1};
    // Global clock counter
    always @(posedge clk or posedge reset) begin: global_clock_proc
        if (reset) begin
            global_clock <= 0;
        end else if (final_tick) begin
            global_clock <= 0;
        end else begin
            global_clock <= global_clock + 1;
        end
    end

    parameter BIT_DIFF = TICK_BITS - PROG_BITS;
    assign event_flush = global_clock == {{BIT_DIFF{1'b0}}, cfg_prog_len, 1'b1};
    wire _do_setup_0 = global_clock == 0;
    wire _do_setup_1;
    register do_setup_reg (clk, reset, 1'b1, _do_setup_0, _do_setup_1);
    wire do_setup = _do_setup_0 | _do_setup_1;  // assert signal for two cycles.
    assign event_setup = _do_setup_0;
    

    /*
    Debug outputs
    */
    assign db_es_tran = ES[T]; // Edit ES
    assign db_es_edit = ES[E]; // Trans ES
    assign cycle = CYCLE;
    assign db_global_clock = global_clock[TICK_BITS: 1];

endmodule
