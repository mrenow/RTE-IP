`timescale 1ns / 1ps
`ifndef XILINX_SIMULATOR
`define XILINX_SIMULATOR
`endif
`include "symbol_translation.sv"
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/23/2024 03:00:06 AM
// Design Name: 
// Module Name: instruction_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


`define ASSERT(name, got, expected) \
    if ((got) !== (expected)) begin \
        $display("%d Test failed: %s: Expected %b, got %b", $time, (name), (expected), (got)); \
    end else begin \
        $display("%d Test passed: %s", $time, (name)); \
    end


module instruction_tb();

parameter TICK_BITS = 32;
parameter PROG_BITS = 8;
parameter STACK_LEN = 6;

reg clk = 0;
reg reset = 1;

reg scan_in = 0;
reg scan_en = 0;
reg scan_reset = 0;
wire scan_out;

// Debug outputs for state variables
wire [7:0] db_es_T; 
wire [7:0] db_es_E;
wire db_cycle;
wire [TICK_BITS-1:0] db_global_clock;
wire [STACK_LEN-1:0] db_stack_T;
wire [STACK_LEN-1:0] db_stack_E; 
wire [31:0] db_inputs;
wire [31:0] db_inputs_valid;
wire [31:0] db_outputs;
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
wire db_event_flush;
wire db_event_setup;

wire [11:0] db_clocks [7:0];

assign db_clocks[0] = {8'b0, db_clock_0};
assign db_clocks[1] = db_clock_1;
assign db_clocks[2] = {8'b0, db_clock_2};
assign db_clocks[3] = db_clock_3;
assign db_clocks[4] = {8'b0, db_clock_4};
assign db_clocks[5] = db_clock_5;
assign db_clocks[6] = {8'b0, db_clock_6};
assign db_clocks[7] = db_clock_7;


reg [31:0] inputs = 0;
wire [31:0] outputs;
wire violation;


    
top #(TICK_BITS, PROG_BITS, STACK_LEN) machine (
    .clk(clk),
    .reset(reset),
    .scan_in(scan_in),
    .scan_en(scan_en),
    .scan_out(scan_out),
    .scan_reset(scan_reset),
    .db_es_tran(db_es_T),
    .db_es_edit(db_es_E),
    .db_cycle(db_cycle),
    .db_global_clock(db_global_clock),
    .db_stack_T(db_stack_T),
    .db_stack_E(db_stack_E),
    .db_inputs(db_inputs),
    .db_inputs_valid(db_inputs_valid),
    .db_outputs(db_outputs),
    .db_next_state(db_next_state),
    .db_data_A(db_data_A),
    .db_data_B(db_data_B),
    .db_hi(db_hi),
    .db_ra_T(db_ra_T),
    .db_pc_T(db_pc_T),
    .db_jc_T(db_jc_T),
    .db_ra_E(db_ra_E),
    .db_pc_E(db_pc_E),
    .db_jc_E(db_jc_E),
    .db_rd_mem0(db_rd_mem0),
    .db_rd_mem1(db_rd_mem1),

    .db_clock_0(db_clock_0),
    .db_clock_1(db_clock_1),
    .db_clock_2(db_clock_2),
    .db_clock_3(db_clock_3),
    .db_clock_4(db_clock_4),
    .db_clock_5(db_clock_5),
    .db_clock_6(db_clock_6),
    .db_clock_7(db_clock_7),
    .db_event_flush(db_event_flush),
    .db_event_setup(db_event_setup),
    .inputs(inputs),
    .outputs(outputs),
    .violation(violation)
);


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

localparam STATE_OFFS = 18;
localparam TRANS_OFFS = 14;
localparam PROG_OFFS = 26;
localparam CLOCK_FLAGS = 26; 


// Clock generation
always #5 clk = ~clk;



// declare data 

// Stream in arbitaray length data from a file backwards
parameter CONF_LEN = 16;
parameter MEM_LEN = 128;
reg [0:7] data [CONF_LEN + MEM_LEN - 1 : 0];
integer curr_byte;
integer i;
integer cyclenum = 0;
integer ticknum = 0;

function string get_reset_flags(input [7:0] bits);
    begin
        integer idx;
        get_reset_flags = "[";
        for (idx=0; idx < 8; idx=idx+1) begin
            if (bits[idx]) begin
                get_reset_flags = {get_reset_flags, ",", get_clock_symbol(idx[2:0])};
            end
        end 
        get_reset_flags = {get_reset_flags, "]"};
    end
endfunction
function string get_clock_string;
    get_clock_string = {
        $sformatf("v=%d,", db_clocks[3'd4]),
        $sformatf("vevent=%d", db_clocks[3'd0])
    };
endfunction

function string decode_trans_instruction(input [7:0] es, input [7:0] bits, input [7:0] upper_bits);
    begin
        automatic string ex, pop, _histar, _lostar, _op = "|", imm = $sformatf("%b", bits[3:0]);
        if (bits[5]) ex = "(ex) "; else ex = "";
        if (bits[4]) pop = "pop "; else pop = "";
        if (bits[6]) _op = {"!", _op};
        if (bits[7]) _op = {_op , "!"};
        if (db_hi) begin _histar = "*"; _lostar = ""; end
        else begin _histar = ""; _lostar = "*"; end
        if (bits[7]) imm = {upper_bits, imm};
        case(es)
            FINISH: decode_trans_instruction = "FINISH";
            SETUP: decode_trans_instruction = $sformatf("SETUP %s @ %d", get_state_symbol(db_next_state), {db_next_state, 1'b0});
            INIT: decode_trans_instruction = $sformatf("INIT %d", bits[7:0]);
            STD: casex(bits[7:5])
                3'b11?: decode_trans_instruction = "DO";
                3'b10?: decode_trans_instruction = {"PSH ", ex, get_input_symbol(bits[4:0])};
                3'b01?: decode_trans_instruction = {"OP2 ", ex,  pop, $sformatf(" %b", bits[3:0])};
                3'b000: decode_trans_instruction = $sformatf("NXT1 %s", get_trans_symbol(bits[4:0]));
                3'b001: decode_trans_instruction = $sformatf("NXT2 %d %d", bits[4], bits[3:0]);
            endcase 
            ACC: decode_trans_instruction = {"ACC ", _op , " ", ex, get_input_symbol(bits[4:0])};
            E_ACC: decode_trans_instruction = "E_ACC: Instruction Invalid";
            PSH_CLK: decode_trans_instruction = $sformatf("PSH_CLK %s %s %s %d",
                bits[7] ? "hi": "lo",
                get_clock_symbol({bits[5:4], bits[7]}),
                bits[6] ? "=": "<",
                imm
            );
            ACC_CLK: decode_trans_instruction = $sformatf("ACC_CLK %s %s %s %d",
                bits[7] ? "hi": "lo",
                get_clock_symbol({bits[5:4], bits[7]}),
                bits[6] ? "=": "<",
                imm
            );
            E_ACC_CLK: decode_trans_instruction = "E_ACC_CLK: Instruction Invalid";

            T_NXT: decode_trans_instruction =  $sformatf("T_NXT %s%s %s%s", _histar, get_trans_symbol({db_data_A[4], bits[7:4]}), _lostar, get_trans_symbol({db_data_A[4], bits[3:0]}));
            T_TRA: decode_trans_instruction =  $sformatf("T_TRA %s%s %s%s", _histar, get_state_symbol(bits[7:4]), _lostar, get_state_symbol(bits[3:0]));
            T_RST: decode_trans_instruction =  $sformatf("T_RST %s", get_reset_flags(bits));
            E_EDIT: decode_trans_instruction = "E_EDIT: Instruction Invalid";
        endcase 
    end
endfunction


function string decode_edit_instruction(input [7:0] es, input [7:0] bits, input [7:0] upper_bits);
    begin
        automatic string ex, pop, _op = "|", _histar, _lostar, imm = $sformatf("%b", bits[3:0]);
        if (bits[5]) ex = "(ex) "; else ex = "";
        if (bits[4]) pop = "pop "; else pop = "";
        if (bits[6]) _op = {"!", _op};
        if (bits[7]) _op = {_op , "!"};
        if (db_hi) begin _histar = ""; _lostar = "*"; end
        else begin _histar = "*"; _lostar = ""; end
        if (bits[7]) imm = {upper_bits, imm};
        case(es)
            FINISH: decode_edit_instruction = "FINISH";
            SETUP: decode_edit_instruction = $sformatf("SETUP %s @ %d", get_state_symbol(db_next_state), {db_next_state, 1'b1});
            INIT: decode_edit_instruction = $sformatf("INIT %d", bits[7:0]);
            STD: casex(bits[7:6])
                2'b11: decode_edit_instruction = "DO";
                2'b10: decode_edit_instruction = {"PSH ", ex, get_input_symbol(bits[4:0])};
                2'b01: decode_edit_instruction = {"OP2 ", ex, pop, $sformatf(" %b", bits[3:0])};
                2'b00: decode_edit_instruction = {"VIO ", ex, pop, $sformatf(" %b", bits[3:0])};
            endcase 
            ACC: decode_edit_instruction = {"ACC ", _op, " ", ex, get_input_symbol(bits[4:0])};
            E_ACC: decode_edit_instruction = {"E_ACC ", _op, " ", ex, get_input_symbol(bits[4:0])};
            PSH_CLK: decode_edit_instruction = $sformatf("PSH_CLK %s %s %s %d",
                bits[7] ? "hi": "lo",
                get_clock_symbol({bits[5:4], bits[7]}),
                bits[6] ? "=": "<",
                imm
            );
            ACC_CLK: decode_edit_instruction = $sformatf("ACC_CLK %s %s %s %d",
                bits[7] ? "hi": "lo",
                get_clock_symbol({bits[5:4], bits[7]}),
                bits[6] ? "=": "<",
                imm
            );
            E_ACC_CLK: decode_edit_instruction = $sformatf("E_ACC_CLK %s %s %s %d",
                bits[7] ? "hi": "lo",
                get_clock_symbol({bits[5:4], bits[7]}),
                bits[6] ? "=": "<",
                imm
            );

            T_NXT: decode_edit_instruction = "T_NXT: Instruction Invalid";
            T_TRA: decode_edit_instruction = "T_TRA: Instruction Invalid";
            T_RST: decode_edit_instruction = "T_RST: Instruction Invalid";
            E_EDIT: begin 
                decode_edit_instruction = {"E_EDIT ", get_input_symbol(bits[4:0]), "=", bits[6]? "1": "0"};
                if (bits[7]) decode_edit_instruction = {decode_edit_instruction, " END"};
                if (bits[5]) decode_edit_instruction = {decode_edit_instruction, ","};
            end 
        endcase
    end
endfunction

function check_inputs(input string name);
    check_inputs = inputs[get_input_id(name)];
endfunction


function check_outputs(input string name);
    check_outputs = outputs[get_input_id(name)];
endfunction

function void set_inputs(input string name, input value);
    inputs[get_input_id(name)] = value;
endfunction

// Task for streaming scanchain
task monitor_trans;
/*
- instruction being executed
- Execution state (Mapped to a word)
- Var, stack
- PC, RA, JC
- input buffer
*/
    begin
        static reg [31:0] inputs_buf = db_inputs ~^ ({32{1'bx}} | db_inputs_valid);
        static string spacer_T;
        static string spacer_E;
        string instruction_string;
        integer i;
        if (~reset) begin
            if (db_event_setup) begin
                ticknum = ticknum + 1;
                $display("EVENT SETUP");
            end
            if (db_event_flush) $display("EVENT FLUSH");
             
            if (db_cycle == 0) begin
                cyclenum = cyclenum + 1;
                // A
                // $display("Transition Machine State A:");
                
                $display("┏━━━━━━━━━━━━━━━━━━Edit B: PC[E]=%d RA[E]=%d JC[E]=%d VAR[E]=%b STK[E]=%b",
                    db_pc_E,
                    db_ra_E,
                    db_jc_E,
                    db_data_B,
                    db_stack_E);
                $display("┃ TICK %0d GBL %0d(#%0d) CYCLE %d %s", ticknum, cyclenum, $time, db_global_clock, get_clock_string()); 
                
                instruction_string = $sformatf("TRAN[%s](%b)", decode_trans_instruction(db_es_T, db_rd_mem0, db_rd_mem1), db_rd_mem0);
                spacer_T = {instruction_string.len(){" "}};
                $display("┗━Tran A: PC[T]=%d RA[T]=%d JC[T]=%d VAR[T]=%b HI=%b IN=%b-%b-%b-%b %s",
                db_pc_T,
                db_ra_T,
                db_jc_T,
                db_data_A,
                db_hi,
                inputs_buf[31:24],
                inputs_buf[23:16],
                inputs_buf[15:8],
                inputs_buf[7:0],
                instruction_string);
                // $display("PC: %b RA: %b JC: %b", db_pc_T, db_ra_T, db_jc_T);
                // $display("VAR: %b STK: %b", db_data_A, db_stack_T);
            end else begin
                $display("┏━Tran B: PC[T]=%d RA[T]=%d JC[T]=%d VAR[T]=%b STK[T]=%b",
                    db_pc_T,
                    db_ra_T,
                    db_jc_T,
                    db_data_B,
                    db_stack_T);
                $display("┃ TICK %0d GBL %0d(#%0d) CYCLE %d %s", ticknum, cyclenum, $time, db_global_clock, get_clock_string()); 
                
                
                instruction_string = $sformatf("EDIT[%s](%b)", decode_edit_instruction(db_es_E, db_rd_mem0, db_rd_mem1),db_rd_mem0);
                spacer_E = {instruction_string.len(){" "}};
                
                
                $display("┗━━━━━━━━━━━━━━━━━━Edit A: PC[E]=%d RA[E]=%d JC[E]=%d VAR[E]=%b IN=%b-%b-%b-%b %s",
                db_pc_E,
                db_ra_E,
                db_jc_E,
                db_data_A,
                inputs_buf[31:24],
                inputs_buf[23:16],
                inputs_buf[15:8],
                inputs_buf[7:0],
                instruction_string);                  
                // B
                // $display("Transition Machine State B:");
                // $display("PC: %b RA: %b JC: %b", db_pc_T, db_ra_T, db_jc_T);
                // $display("VAR: %b STK: %b", db_data_A, db_stack_T);
            end
        end else begin
            cyclenum = 0;
            ticknum = 0;
        end
    end
endtask

always #10 monitor_trans;

// Task for streaming scanchain
task stream_data;
    begin
        for (curr_byte = CONF_LEN + MEM_LEN-1; curr_byte >=0; curr_byte = curr_byte - 1) begin
            for (i = 7; i >= 0; i = i - 1) begin 
                scan_in = data[curr_byte][i] === 1'bx ? 0 : data[curr_byte][i];
                scan_en = 1;
                #10;
            end
        end
        // Deactivate scanchain
        scan_in = 0;
        scan_en = 0;
    end
endtask

// task assert(input string name, got, expected);
//     begin 
//         if (got !== expected) begin
//             $display("Test failed: %s: Expected %b, got %b", name, expected, got);
//         end else begin
//             $display(name);
//         end
//     end
// endtask

initial begin
    reset=1;
    scan_reset=1;
    #10;
    scan_reset = 0;
    // Open the file
    $readmemh("pacemaker.txt", data);
    stream_data();

    /*
    TEST INITIALIZE
    */
    `ASSERT("mem[0]", db_rd_mem0, 8'h09);
    `ASSERT("ES[E]", db_es_E, FINISH);
    `ASSERT("ES[T]", db_es_T, FINISH);
    // begin operation
    reset = 0;
    #10;
    // ODD B=T, A=E
    `ASSERT("ES[E]", db_es_E, SETUP); // A
    `ASSERT("ES[T]", db_es_T, FINISH); // B
    #10;
    `ASSERT("DB[E]", db_es_E, SETUP);
    `ASSERT("VAR[E]", db_data_B, 1); // VAR <= {next_state, 1}
    
    `ASSERT("ES[T]", db_es_T, SETUP);
    #10;
    // ODD B=T, A=E
    `ASSERT("ES[E]", db_es_E, INIT);
    `ASSERT("PC[E]", db_pc_E, STATE_OFFS + 1); // PC <= VAR + STA_OFFSET
    
    `ASSERT("VAR[T]", db_data_B, 0); // VAR <= {next_state, 0}
    `ASSERT("ES[T]", db_es_T, SETUP);
    #10;
    `ASSERT("ES[E]", db_es_E, INIT);
    `ASSERT("VAR[E]", db_data_B, PROG_OFFS-TRANS_OFFS); // VAR <= MEM[PC]
        
    `ASSERT("ES[T]", db_es_T, INIT);
    `ASSERT("PC[T]", db_pc_T, STATE_OFFS); // PC <= VAR + STA_OFFSET
    #10;
    // ODD B=T, A=E
    $display("E start");
    `ASSERT("ES[E]", db_es_E, STD);
    `ASSERT("PC[E]", db_pc_E, PROG_OFFS);

    `ASSERT("ES[T]", db_es_T, INIT);
    #10;
    $display("T start");
    `ASSERT("ES[E]", db_es_E, STD);
    
    `ASSERT("PC[T]", db_pc_T, PROG_OFFS);
    `ASSERT("ES[T]", db_es_T, STD);
    #10;

end


initial begin
    while (reset) #10;
    set_inputs("AS", 1);  // 0
    #(`TICK_LENGTH_NS);
    set_inputs("AS", 0); // 1
    #(3*`TICK_LENGTH_NS); 

    set_inputs("VS", 1); // 4
    #(`TICK_LENGTH_NS); 
    set_inputs("VS", 0); // 5
    #(13*`TICK_LENGTH_NS);
    
    // AP & VP pulsed at the same time: suppress VP
    set_inputs("AP", 1);  // 0
    set_inputs("VP", 1);  // 0
    #`TICK_LENGTH_NS;
    set_inputs("AP", 0); // 1
    set_inputs("VP", 0); // 1
    #(3*`TICK_LENGTH_NS); 

    set_inputs("VS", 1); // 4
    #(`TICK_LENGTH_NS); 
    set_inputs("VS", 0); // 5
    #(13*`TICK_LENGTH_NS);

    // Failure to pulse A.
    // set_inputs("AS", 1);  // 0
    #`TICK_LENGTH_NS;
    // set_inputs("AS", 0); // 1
    #(6*`TICK_LENGTH_NS); 

    set_inputs("VS", 1); // 4
    #(`TICK_LENGTH_NS); 
    set_inputs("VS", 0); // 5
    #(13*`TICK_LENGTH_NS);

    set_inputs("AS", 1);  // 0
    #`TICK_LENGTH_NS;
    set_inputs("AS", 0); // 1
    #(3*`TICK_LENGTH_NS); 

    // Failure to pulse V
    // set_inputs("VS", 1); // 4
    #(`TICK_LENGTH_NS); 
    // set_inputs("VS", 0); // 5
    #(16*`TICK_LENGTH_NS);

    set_inputs("AS", 1);  // 0
    #`TICK_LENGTH_NS;
    set_inputs("AS", 0); // 1
    #(3*`TICK_LENGTH_NS); 

    set_inputs("VP", 1); // 4
    #(`TICK_LENGTH_NS); 
    set_inputs("VP", 0); // 5
    #(13*`TICK_LENGTH_NS);

    set_inputs("AP", 1);  // 0
    #`TICK_LENGTH_NS;
    set_inputs("AP", 0); // 1
    #(3*`TICK_LENGTH_NS); 

    set_inputs("VS", 1); // 4
    #(`TICK_LENGTH_NS); 
    set_inputs("VS", 0); // 5
    #(13*`TICK_LENGTH_NS);
    
    set_inputs("VP", 1); // 4
    #(13*`TICK_LENGTH_NS);
    set_inputs("VP", 0); // 4
    set_inputs("AP", 1); // 4
    #(13*`TICK_LENGTH_NS);
    set_inputs("VP", 1); // 4
    #(13*`TICK_LENGTH_NS);
    set_inputs("AP", 0); // 4
    set_inputs("VP", 0); // 
    
    
    
    

end
// Rest of your code...
    



    
endmodule
