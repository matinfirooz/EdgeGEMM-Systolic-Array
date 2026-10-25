`timescale 1ns/1ps
module edgegemm_top #(
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
    output wire signed [ACC_W-1:0] result_acc,
    input wire [5:0] quant_shift,
    input wire relu_en,
    output wire signed [7:0] result_q8
);
    systolic_array #(.N(N),.DATA_W(DATA_W),.ACC_W(ACC_W),.IDX_W(IDX_W)) u_array (
        .clk(clk),.rst_n(rst_n),.load_we(load_we),.load_sel(load_sel),
        .load_row(load_row),.load_col(load_col),.load_data(load_data),
        .start(start),.busy(busy),.done(done),.perf_cycles(perf_cycles),
        .result_row(result_row),.result_col(result_col),.result_data(result_acc));
    requantize #(.ACC_W(ACC_W),.OUT_W(8)) u_requant (
        .in_data(result_acc),.right_shift(quant_shift),.relu_en(relu_en),.out_data(result_q8));
endmodule
