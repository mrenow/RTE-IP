`define TICK_LENGTH 50
`define TICK_LENGTH_NS 1000
`define PROGRAM_LENGTH 13
function string get_input_symbol(input [4:0] bits);
    case(bits)
        5'd28: get_input_symbol = "AS";
        5'd29: get_input_symbol = "VS";
        5'd30: get_input_symbol = "AP";
        5'd31: get_input_symbol = "VP";
        5'd0: get_input_symbol = "CLK(v<aeiTicks)";
        5'd2: get_input_symbol = "CLK(v<aviTicks)";
        5'd4: get_input_symbol = "CLK(vevent<lriTicks)";
        5'd5: get_input_symbol = "CLK(vevent<uriTicks)";
        default: get_input_symbol = $sformatf("<UNRECOGNIZED %d>", bits);
    endcase
endfunction
function string get_clock_symbol(input [2:0] bits);
    case(bits)
        3'd0: get_clock_symbol = "vevent";
        3'd5: get_clock_symbol = "v";
        default: get_clock_symbol = $sformatf("<UNRECOGNIZED %d>", bits);
    endcase
endfunction
function string get_imm_symbol(input [11:0] bits);
    case(bits)
        12'd8: get_imm_symbol = "aviTicks";
        12'd20: get_imm_symbol = "aeiTicks";
        12'd5: get_imm_symbol = "uriTicks";
        12'd14: get_imm_symbol = "lriTicks";
        default: get_imm_symbol = $sformatf("<UNRECOGNIZED %d>", bits);
    endcase
endfunction
function string get_trans_symbol(input [4:0] bits);
    case(bits)
        5'd0: get_trans_symbol = "TRN(init,[])";
        5'd1: get_trans_symbol = "TRN(pre_VSVP,[v,vevent])";
        5'd2: get_trans_symbol = "TRN(pre_ASAP,[v,vevent])";
        5'd3: get_trans_symbol = "TRN(pre_ASAP,[])";
        5'd4: get_trans_symbol = "TRN(pre_VSVP_pre_URI,[v])";
        5'd5: get_trans_symbol = "TRN(pre_VSVP,[])";
        5'd6: get_trans_symbol = "TRN(pre_VSVP_pre_URI,[])";
        default: get_trans_symbol = $sformatf("<UNRECOGNIZED %d>", bits);
    endcase
endfunction
function string get_state_symbol(input [3:0] bits);
    case(bits)
        4'd0: get_state_symbol = "pre_ASAP";
        4'd1: get_state_symbol = "init";
        4'd2: get_state_symbol = "pre_VSVP";
        4'd3: get_state_symbol = "pre_VSVP_pre_URI";
        default: get_state_symbol = $sformatf("<UNRECOGNIZED %d>", bits);
    endcase
endfunction
function [4:0] get_input_id(input string symbol);
    case(symbol)
        "AS": get_input_id = 5'd28;
        "VS": get_input_id = 5'd29;
        "AP": get_input_id = 5'd30;
        "VP": get_input_id = 5'd31;
        "CLK(v<aeiTicks)": get_input_id = 5'd0;
        "CLK(v<aviTicks)": get_input_id = 5'd2;
        "CLK(vevent<lriTicks)": get_input_id = 5'd4;
        "CLK(vevent<uriTicks)": get_input_id = 5'd5;
        default: get_input_id = {5{1'bx}};
    endcase
endfunction
