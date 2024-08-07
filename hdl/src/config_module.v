(* KEEP_HIERARCHY = "TRUE", KEEP = "TRUE" *) module main_memory #(parameter MEM_LEN = 128) (
    input clk,
    input reset,

    input scan_in,
    input scan_en,
    output scan_out,
    
    input [7:0] addr,
    output [7:0] d_out_0,
    output [7:0] d_out_1
);
    function integer bit_len;
       input integer i;
//       integer 	i = value;
       begin
          bit_len = -1;
          for(i=i; i != 0; i = i >> 1) bit_len = bit_len + 1;
       end
    endfunction
    localparam ADDR_BITS = bit_len(MEM_LEN);
    localparam NEXT_MEM_BITS = 5;
    localparam NEXT_MEM_SIZE = 1 << NEXT_MEM_BITS;
    // Memory is filled in from the lowest index
    reg [7:0] memory[MEM_LEN-1:0];
    wire [7:0] next_memory[NEXT_MEM_SIZE-1:0];

    assign d_out_0 = memory[addr[ADDR_BITS-1:0]];
    assign d_out_1 = next_memory[addr[NEXT_MEM_BITS-1:0]];

    genvar gi;
    generate
        for (gi = 0; gi < NEXT_MEM_SIZE; gi = gi+1) begin
            assign next_memory[gi] = memory[gi+1];
        end
    endgenerate
    
    assign scan_out = memory[MEM_LEN-1][7];
    
    always @(posedge clk or posedge reset) begin: mem
        integer i;
        if(reset) begin
            for(i=0; i<MEM_LEN; i=i+1) begin
                memory[i] <= 0;
            end
        end else if(scan_en) begin
            for(i=0; i<MEM_LEN; i=i+1) begin
                memory[i][7:0] <= {memory[i][6:0], i == 0 ? scan_in : memory[i-1][7]};
            end
        end
    end 
endmodule

(* KEEP_HIERARCHY = "TRUE", KEEP = "TRUE" *) module config_module #(
    parameter MEM_LEN=128,
    parameter PROG_LEN_SIZE=8,
    parameter TICK_LEN_SIZE=16
    ) (
    input clk,
    input reset,
    
    input scan_in,
    input scan_en,
    output scan_out,
    
    input [7:0] addr,

    output [7:0] cfg_state_offs,
    output [7:0] cfg_trans_offs,
    output [PROG_LEN_SIZE-1:0] cfg_prog_len,
    output [TICK_LEN_SIZE-1:0] cfg_tick_len,
    output [31:0] cfg_clk_flags,
    output [7:0] cfg_clk_joins,
    output [39:0] cfg_clk_div_imm,
        
    output [7:0] d_out_0,
    output [7:0] d_out_1
);
    /*
    Memory structure:
    0: State Offsets #4
    1: Transition Offsets #4
    2: Program Length #8
    3: Tick Length #16
    4: Clock Flags #32 
    5: Clock Joins #8
    6: Clock Divider Immediate Values #10
    7: Clock Divider Immediate Values #10
    8: Clock Divider Immediate Values #10 
    9: Clock Divider Immediate Values #10
    10: Main Memory #8x256
    */
    wire scan_intermediates[11:0];
    assign scan_intermediates[0] = scan_in;

    // The address at which the state location information is stored
    scan_rom cfg_state_offs_reg (
        .clk(clk),
        .reset(reset),
        .scan_in(scan_intermediates[0]),
        .scan_out(scan_intermediates[1]),
        .scan_en(scan_en),
        .d_out(cfg_state_offs)
    );
    
    // The address at which the transition information is stored.
    scan_rom cfg_trans_offs_reg (
        .clk(clk),
        .reset(reset),
        .scan_in(scan_intermediates[1]),
        .scan_out(scan_intermediates[2]),
        .scan_en(scan_en),
        .d_out(cfg_trans_offs)
    );

    // Number of ticks after which we guarantee program has ended
    scan_rom #(PROG_LEN_SIZE) cfg_prog_len_reg (
        .clk(clk),
        .reset(reset),
        .scan_in(scan_intermediates[2]),
        .scan_out(scan_intermediates[3]),
        .scan_en(scan_en),
        .d_out(cfg_prog_len)
    );
    

    // Number of clock cycles per tick
    scan_rom #(TICK_LEN_SIZE) cfg_tick_len_reg (
        .clk(clk),
        .reset(reset),
        .scan_in(scan_intermediates[3]),
        .scan_out(scan_intermediates[4]),
        .scan_en(scan_en),
        .d_out(cfg_tick_len)
    );
    
    // Which elements of the address space are to refer to clock constraints. 
    scan_rom #(32) cfg_clk_flags_reg (
        .clk(clk),
        .reset(reset),
        .scan_in(scan_intermediates[4]),
        .scan_out(scan_intermediates[5]),
        .scan_en(scan_en),
        .d_out(cfg_clk_flags)
    );

    // which clocks are to be joined to the previous.
    scan_rom cfg_clk_joins_reg (
        .clk(clk),
        .reset(reset),
        .scan_in(scan_intermediates[5]),
        .scan_out(scan_intermediates[6]),
        .scan_en(scan_en),
        .d_out(cfg_clk_joins)
    );
    
    // Clock Divider Comparision Values
    genvar i;
    generate
        for(i=0; i<4; i=i+1) begin
            scan_rom #(10) cfg_clk_div_imm_reg (
                .clk(clk),
                .reset(reset),
                .scan_in(scan_intermediates[6+i]), // 6, 7, 8, 9
                .scan_out(scan_intermediates[7+i]), // 7, 8, 9, 10
                .scan_en(scan_en),
                .d_out(cfg_clk_div_imm[i*10+9:i*10])
            );
        end
    endgenerate

    // Main Memory
    main_memory #(MEM_LEN) cfg_main_memory (
        .clk(clk),
        .reset(reset),

        .scan_in(scan_intermediates[10]),
        .scan_out(scan_intermediates[11]),
        .scan_en(scan_en),
        
        .addr(addr),
        .d_out_0(d_out_0),
        .d_out_1(d_out_1)
    );
    assign scan_out = scan_intermediates[11];
    


    

    
    
endmodule