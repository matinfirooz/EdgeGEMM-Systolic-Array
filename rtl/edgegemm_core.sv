`timescale 1ns/1ps
// Enhanced one-tile-at-a-time engine. Loading the OTHER bank may overlap work.
module edgegemm_core #(
    parameter integer N=4,K_MAX=16,DATA_W=8,ACC_W=32,OUT_W=8,ZERO_GATE=1,
    parameter integer IDX_W=(N<=1)?1:$clog2(N),
    parameter integer DIM_W=(N<2)?1:$clog2(N+1),
    parameter integer INDEX_W=(K_MAX<=1)?1:$clog2(K_MAX),
    parameter integer K_W=(K_MAX<2)?1:$clog2(K_MAX+1)
) (
    input wire clk,rst_n,run_enable,
    input wire load_valid,load_bank,load_sel,
    input wire [IDX_W-1:0] load_lane,
    input wire [INDEX_W-1:0] load_index,
    input wire signed [DATA_W-1:0] load_data,
    output wire load_ready,
    output reg load_error,
    input wire qcfg_valid,qcfg_bank,
    input wire [IDX_W-1:0] qcfg_col,
    input wire signed [ACC_W-1:0] qcfg_bias,
    input wire [15:0] qcfg_multiplier,
    input wire [5:0] qcfg_shift,
    input wire signed [OUT_W-1:0] qcfg_zero_point,
    input wire qcfg_relu,qcfg_round,
    output wire qcfg_ready,
    output reg qcfg_error,
    input wire cmd_valid,cmd_bank,
    input wire [DIM_W-1:0] cmd_rows,cmd_cols,
    input wire [K_W-1:0] cmd_depth,
    output wire cmd_ready,
    output wire cmd_error,
    output wire busy,done,
    output wire out_valid,
    input wire out_ready,
    output wire out_last,
    output wire [IDX_W-1:0] out_row,out_col,
    output wire signed [ACC_W-1:0] out_acc,
    output wire signed [OUT_W-1:0] out_quant,
    output wire [31:0] perf_compute_cycles,perf_stall_cycles,perf_valid_macs,perf_zero_macs
);
    wire compute_busy,compute_done,clear,stream_busy;
    wire [31:0] step;
    wire [DIM_W-1:0] rows,cols;
    wire [K_W-1:0] depth;
    reg active_bank;
    wire issue=cmd_valid && cmd_ready;
    assign busy=compute_busy || compute_done || stream_busy;
    assign cmd_ready=!busy;
    // A bank remains owned through the final result handshake, keeping qparams stable.
    assign load_ready=!busy || load_bank!=active_bank;
    assign qcfg_ready=!busy || qcfg_bank!=active_bank;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin active_bank<=0; load_error<=0; qcfg_error<=0; end
        else begin
            if(clear) active_bank<=cmd_bank;
            load_error<=load_valid && load_ready && (32'(load_lane)>=N || 32'(load_index)>=K_MAX);
            qcfg_error<=qcfg_valid && qcfg_ready && 32'(qcfg_col)>=N;
        end
    end
    tile_controller #(.N(N),.K_MAX(K_MAX)) u_control (
        .clk(clk),.rst_n(rst_n),.start(issue),.run_enable(run_enable),
        .cfg_rows(cmd_rows),.cfg_cols(cmd_cols),.cfg_depth(cmd_depth),
        .clear(clear),.busy(compute_busy),.done(compute_done),.error(cmd_error),
        .step(step),.rows(rows),.cols(cols),.depth(depth));
    wire [N-1:0] av,bv;
    wire [N*INDEX_W-1:0] ai,bi;
    wire [N*DATA_W-1:0] a_data,b_data;
    skew_injector #(.N(N),.K_MAX(K_MAX)) u_injector (
        .active(compute_busy),.step(step),.rows(rows),.cols(cols),.depth(depth),
        .a_valid(av),.b_valid(bv),.a_index(ai),.b_index(bi));
    operand_buffer #(.LANES(N),.DEPTH(K_MAX),.DATA_W(DATA_W)) u_a_buffer (
        .clk(clk),.rst_n(rst_n),.wr_valid(load_valid && load_ready && !load_sel),
        .wr_bank(load_bank),.wr_lane(load_lane),.wr_index(load_index),.wr_data(load_data),
        .rd_bank(active_bank),.rd_enable(av),.rd_index(ai),.rd_data(a_data));
    operand_buffer #(.LANES(N),.DEPTH(K_MAX),.DATA_W(DATA_W)) u_b_buffer (
        .clk(clk),.rst_n(rst_n),.wr_valid(load_valid && load_ready && load_sel),
        .wr_bank(load_bank),.wr_lane(load_lane),.wr_index(load_index),.wr_data(load_data),
        .rd_bank(active_bank),.rd_enable(bv),.rd_index(bi),.rd_data(b_data));
    wire [N*N*ACC_W-1:0] acc;
    wire [N*N-1:0] mac_events,zero_events;
    systolic_mesh #(.N(N),.DATA_W(DATA_W),.ACC_W(ACC_W),.ZERO_GATE(ZERO_GATE)) u_mesh (
        .clk(clk),.rst_n(rst_n),.clear(clear),.enable(compute_busy && run_enable),
        .a_left(a_data),.b_top(b_data),.a_valid(av),.b_valid(bv),
        .accumulators(acc),.mac_events(mac_events),.zero_events(zero_events));
    perf_counters #(.PE_COUNT(N*N)) u_perf (
        .clk(clk),.rst_n(rst_n),.clear(clear),.active(compute_busy),.run_enable(run_enable),
        .mac_events(mac_events),.zero_events(zero_events),
        .compute_cycles(perf_compute_cycles),.stall_cycles(perf_stall_cycles),
        .valid_macs(perf_valid_macs),.zero_macs(perf_zero_macs));
    // compute_done is observed one edge after the last MAC: capture settled state.
    result_buffer #(.N(N),.ACC_W(ACC_W)) u_results (
        .clk(clk),.rst_n(rst_n),.capture(compute_done),.accumulators(acc),
        .read_row(out_row),.read_col(out_col),.read_data(out_acc));
    result_streamer #(.N(N)) u_stream (
        .clk(clk),.rst_n(rst_n),.start(compute_done),.rows(rows),.cols(cols),
        .out_ready(out_ready),.out_valid(out_valid),.out_last(out_last),
        .out_row(out_row),.out_col(out_col),.busy(stream_busy),.done(done));
    wire signed [ACC_W-1:0] bias;
    wire [15:0] multiplier;
    wire [5:0] shift;
    wire signed [OUT_W-1:0] zero_point;
    wire relu,round_nearest;
    channel_config #(.N(N),.ACC_W(ACC_W),.OUT_W(OUT_W)) u_qconfig (
        .clk(clk),.rst_n(rst_n),.wr_valid(qcfg_valid && qcfg_ready),.wr_bank(qcfg_bank),
        .wr_col(qcfg_col),.wr_bias(qcfg_bias),.wr_multiplier(qcfg_multiplier),
        .wr_shift(qcfg_shift),.wr_zero_point(qcfg_zero_point),.wr_relu(qcfg_relu),.wr_round(qcfg_round),
        .rd_bank(active_bank),.rd_col(out_col),.bias(bias),.multiplier(multiplier),
        .shift(shift),.zero_point(zero_point),.relu(relu),.round_nearest(round_nearest));
    affine_requantize #(.ACC_W(ACC_W),.OUT_W(OUT_W)) u_quant (
        .in_data(out_acc),.bias(bias),.multiplier(multiplier),.right_shift(shift),
        .zero_point(zero_point),.relu_en(relu),.round_nearest(round_nearest),.out_data(out_quant));
`ifndef SYNTHESIS
    initial if(N<1 || K_MAX<1 || DATA_W<2 || ACC_W<2*DATA_W || OUT_W>ACC_W)
        $fatal(1,"edgegemm_core: invalid parameters");
`endif
endmodule
