`timescale 1ns/1ps
// Original square-tile API, now assembled from reusable submodules.
module systolic_array #(
    parameter integer N=4,DATA_W=8,ACC_W=32,
    parameter integer IDX_W=(N<=1)?1:$clog2(N)
) (
    input wire clk,rst_n,load_we,load_sel,
    input wire [IDX_W-1:0] load_row,load_col,
    input wire signed [DATA_W-1:0] load_data,
    input wire start,
    output wire busy,done,
    output wire [31:0] perf_cycles,
    input wire [IDX_W-1:0] result_row,result_col,
    output reg signed [ACC_W-1:0] result_data
);
    localparam integer DIM_W=(N<2)?1:$clog2(N+1);
    wire clear,unused_error;
    wire [31:0] step;
    wire [DIM_W-1:0] rows,cols,depth;
    tile_controller #(.N(N),.K_MAX(N)) u_control (
        .clk(clk),.rst_n(rst_n),.start(start),.run_enable(1'b1),
        .cfg_rows(DIM_W'(N)),.cfg_cols(DIM_W'(N)),.cfg_depth(DIM_W'(N)),
        .clear(clear),.busy(busy),.done(done),.error(unused_error),
        .step(step),.rows(rows),.cols(cols),.depth(depth));
    wire [N-1:0] av,bv;
    wire [N*IDX_W-1:0] ai,bi;
    wire [N*DATA_W-1:0] a,b;
    skew_injector #(.N(N),.K_MAX(N)) u_injector (
        .active(busy),.step(step),.rows(rows),.cols(cols),.depth(depth),
        .a_valid(av),.b_valid(bv),.a_index(ai),.b_index(bi));
    operand_buffer #(.LANES(N),.DEPTH(N),.DATA_W(DATA_W)) u_a_buffer (
        .clk(clk),.rst_n(rst_n),.wr_valid(load_we && !busy && !load_sel),.wr_bank(1'b0),
        .wr_lane(load_row),.wr_index(load_col),.wr_data(load_data),
        .rd_bank(1'b0),.rd_enable(av),.rd_index(ai),.rd_data(a));
    operand_buffer #(.LANES(N),.DEPTH(N),.DATA_W(DATA_W)) u_b_buffer (
        .clk(clk),.rst_n(rst_n),.wr_valid(load_we && !busy && load_sel),.wr_bank(1'b0),
        .wr_lane(load_col),.wr_index(load_row),.wr_data(load_data),
        .rd_bank(1'b0),.rd_enable(bv),.rd_index(bi),.rd_data(b));
    wire [N*N*ACC_W-1:0] acc;
    wire [N*N-1:0] events,zeros;
    wire [31:0] unused_stalls,unused_macs,unused_zeros;
    systolic_mesh #(.N(N),.DATA_W(DATA_W),.ACC_W(ACC_W)) u_mesh (
        .clk(clk),.rst_n(rst_n),.clear(clear),.enable(busy),.a_left(a),.b_top(b),
        .a_valid(av),.b_valid(bv),.accumulators(acc),.mac_events(events),.zero_events(zeros));
    perf_counters #(.PE_COUNT(N*N)) u_perf (
        .clk(clk),.rst_n(rst_n),.clear(clear),.active(busy),.run_enable(1'b1),
        .mac_events(events),.zero_events(zeros),.compute_cycles(perf_cycles),
        .stall_cycles(unused_stalls),.valid_macs(unused_macs),.zero_macs(unused_zeros));
    always @* begin
        result_data=0;
        if(32'(result_row)<N && 32'(result_col)<N)
            result_data=acc[(32'(result_row)*N+32'(result_col))*ACC_W+:ACC_W];
    end
endmodule
