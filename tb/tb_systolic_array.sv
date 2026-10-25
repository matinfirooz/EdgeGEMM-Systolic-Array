`timescale 1ns/1ps
`include "tb_util.svh"
module tb_systolic_array;
    parameter integer N=3,DATA_W=8;
    localparam integer IDX_W=(N<=1)?1:$clog2(N);
    reg clk=0; always #5 clk=~clk;
    reg rst_n=0,load_we=0,load_sel=0,start=0;
    reg [IDX_W-1:0] load_row=0,load_col=0,result_row=0,result_col=0;
    reg signed [DATA_W-1:0] load_data=0;
    wire busy,done;
    wire [31:0] perf_cycles;
    wire signed [31:0] result_data;
    reg signed [DATA_W-1:0] a [0:N-1][0:N-1],b [0:N-1][0:N-1];
    integer expected,checks=0;
    systolic_array #(.N(N),.DATA_W(DATA_W)) dut(.*);
    `WATCHDOG
    initial begin
        @(negedge clk); rst_n=1;
        for(integer test=0;test<12;test=test+1) begin
            for(integer r=0;r<N;r=r+1) for(integer c=0;c<N;c=c+1) begin
                a[r][c]=DATA_W'(r*17+c*5+test*11-53);
                b[r][c]=DATA_W'(r*13-c*7-test*3+61);
                @(negedge clk); load_we=1; load_sel=0; load_row=IDX_W'(r); load_col=IDX_W'(c); load_data=a[r][c];
                @(negedge clk); load_sel=1; load_data=b[r][c];
            end
            @(negedge clk); load_we=0; start=1;
            @(negedge clk); start=0;
            while(!done) @(negedge clk);
            `CHECK(perf_cycles==3*N-2,"legacy latency")
            for(integer r=0;r<N;r=r+1) for(integer c=0;c<N;c=c+1) begin
                expected=0;
                for(integer k=0;k<N;k=k+1) expected=expected+$signed(a[r][k])*$signed(b[k][c]);
                result_row=IDX_W'(r); result_col=IDX_W'(c); #1;
                `CHECK(result_data===expected,"legacy random signed GEMM")
            end
        end
        $display("PASS tb_systolic_array N=%0d W=%0d checks=%0d",N,DATA_W,checks); $finish;
    end
endmodule
