module clocks_module(
    input clk,                       // Clock signal
    input reset,                     // Asynchronous reset signal
    input en,                       // Clock counter enable
    
    input lng,                     // Whether we are selecting from 4-bit or 12-bit clocks
    input op,                       // Which operation to perform to produce out_val. op=1 is equals, op=0 is less than
    input [1:0] addr,               // Which clock to use
    input [3:0] imm_lo,             // lower bits of comparison value for 4-bit clocks
    
    input [7:0] imm_hi,             // higher bits of comparison value for 12-bit clocks
    
    input en_clk_reset,              // Control: Whether to perform a clock reset 
    input [7:0] clk_reset,              // Which clocks to reset
    input [7:0] cfg_clk_joins,           // Whether particular clocks are joined to each other.
    input [39:0] cfg_div_limits,       // 10-bit clock divider values

    output [3:0] db_clock_0,
    output [11:0] db_clock_1,
    output [3:0] db_clock_2,
    output [11:0] db_clock_3,
    output [3:0] db_clock_4,
    output [11:0] db_clock_5,
    output [3:0] db_clock_6,
    output [11:0] db_clock_7,

    output out_val                  // result of clock constraint
);



// Clock and divider counters
wire [11:0] counters [7:0];


wire [7:0] carry_ins; // whether to increment each register
wire [7:0] carry_outs; // whether to increment each register
wire [7:0] clock_array_transpose[11:0];

wire [11:0] clock_val;
wire [11:0] compare_val;

wire [9:0] clk_div_arr [3:0];

 
genvar j;
genvar k;

generate
    for (j=0; j<8; j=j+1) begin
        if (j == 0 | j == 1 | j == 4 | j == 5) begin
            divided_clock #(j % 2 == 1 ? 12 : 4) div_clock (
                .clk(clk),
                .reset(reset),
                .reset_sync(en_clk_reset & clk_reset[j]),
                .en(en),
                .carry_in(carry_ins[j]),
                .carry_out(carry_outs[j]),
                .join_previous(cfg_clk_joins[j]),
                .divider_max(clk_div_arr[j > 3? j-2 : j]),
                .counter(counters[j])
            );
        end else begin
            basic_clock #(j % 2 == 1 ? 12 : 4) clock (
                .clk(clk),
                .reset(reset),
                .reset_sync(en_clk_reset & clk_reset[j]),
                .en(en),
                .carry_in(carry_ins[j]),
                .carry_out(carry_outs[j]),
                .join_previous(cfg_clk_joins[j]),
                .counter(counters[j])
            );
        end
    end
endgenerate 
generate
    // organize clock divider limits
    for (j=0; j<4; j=j+1) begin
        assign clk_div_arr[j] = cfg_div_limits[10*j+9:10*j];
    end
    
    // Transpose clocks array
    for (j=0; j<8; j=j+1) begin
        for (k=0; k<12; k=k+1) begin 
            assign clock_array_transpose[k][j] = counters[j][k];
        end
        // if (j!=7) assign carry_ins[j+1] = carry_outs[j];
        assign carry_ins[(j+1)%8] = carry_outs[j];        
    end
    
    // clock select
    for (j=0; j<12; j=j+1) begin
        assign clock_val[j] = clock_array_transpose[j] >> {addr, lng};
    end
        
endgenerate

assign db_clock_0 = counters[0][3:0];
assign db_clock_1 = counters[1];
assign db_clock_2 = counters[2][3:0];
assign db_clock_3 = counters[3];
assign db_clock_4 = counters[4][3:0];
assign db_clock_5 = counters[5];
assign db_clock_6 = counters[6][3:0];
assign db_clock_7 = counters[7];

assign compare_val = {imm_hi & {8{lng}}, imm_lo};
assign out_val = op ? (compare_val == clock_val): (clock_val < compare_val);
endmodule

module divided_clock #(parameter N = 4, parameter P = 12, parameter D = 10)(

    input clk,                       // Clock signal
    input reset,                     // Asynchronous reset signal
    input reset_sync,
    input en,

    input carry_in,
    input join_previous,
    input [D-1:0] divider_max,
    output carry_out,
    output [P-1:0] counter
);

reg [D-1:0] divider;
reg [N-1:0] counter_internal;

wire do_increment;
wire divider_is_zero = divider==0;
assign do_increment = join_previous? carry_in: divider_is_zero;
assign carry_out = & counter_internal & do_increment;


assign counter = {{(P-N){1'b0}}, counter_internal};
// Clock increment logic
always @(posedge clk or posedge reset) begin: clock_process
    if (reset) begin
        counter_internal <= 0;
        divider <= 0;
    end else if (reset_sync) begin
        counter_internal <= 0;
        divider <= 0;
    end else if(en) begin
        // Clock divider updates. The divider will have a cycle time of CLK_DIV_CONF + 1
        if (do_increment) counter_internal <= counter_internal + 1;
        
        if (divider_is_zero) divider <= divider_max;
        else divider <= divider - 1;
    end
end
endmodule

module basic_clock #(parameter N = 4, parameter P = 12)(

    input clk,                       // Clock signal
    input reset,                     // Asynchronous reset signal
    input reset_sync,
    input en,
    
    input carry_in,
    input join_previous,
    output carry_out,
    output [P-1:0] counter
);
reg [N-1:0] counter_internal;

wire do_increment = join_previous? carry_in : 1;
assign carry_out = & counter_internal & do_increment;
assign counter = {{(P-N){1'b0}}, counter_internal};
wire inc = en & do_increment;
// Clock increment logic
always @(posedge clk or posedge reset) begin: basic_clock_process
    if (reset) begin
        counter_internal <= 0;
    end else if (reset_sync) begin
        counter_internal <= 0;
    end else if (inc) begin                
        counter_internal <= counter_internal + 1;
    end
end
endmodule