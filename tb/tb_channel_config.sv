`timescale 1ns/1ps
`include "tb_util.svh"
module tb_channel_config;
    reg clk=0; always #5 clk=~clk;
    reg rst_n=0,wr_valid=0,wr_bank=0,rd_bank=0;
    reg [1:0] wr_col=0,rd_col=0;
    reg signed [31:0] wr_bias=0;
    reg [15:0] wr_multiplier=1;
    reg [5:0] wr_shift=0;
    reg signed [7:0] wr_zero_point=0;
    reg wr_relu=0,wr_round=0;
    wire signed [31:0] bias;
    wire [15:0] multiplier;
    wire [5:0] shift;
    wire signed [7:0] zero_point;
    wire relu,round_nearest;
    integer checks=0;
    channel_config #(.N(3)) dut(.*);
    `WATCHDOG
    initial begin
        @(negedge clk); rst_n=1; #1;
        `CHECK(bias==0 && multiplier==1 && shift==0 && zero_point==0 && !relu && !round_nearest,"identity defaults")
        for(integer b=0;b<2;b=b+1) for(integer c=0;c<3;c=c+1) begin
            @(negedge clk); wr_valid=1; wr_bank=1'(b); wr_col=2'(c);
            wr_bias=b*100+c-40; wr_multiplier=16'(b*3+c+1); wr_shift=6'(c);
            wr_zero_point=8'(c-2); wr_relu=1'(c%2); wr_round=1'(b);
        end
        @(negedge clk); wr_valid=0;
        for(integer b=0;b<2;b=b+1) for(integer c=0;c<3;c=c+1) begin
            rd_bank=1'(b); rd_col=2'(c); #1;
            `CHECK(bias==b*100+c-40 && multiplier==b*3+c+1 && shift==c,"banked qparams")
            `CHECK(zero_point==c-2 && relu==1'(c%2) && round_nearest==1'(b),"activation qparams")
        end
        @(negedge clk); wr_valid=1; wr_col=3; wr_multiplier=99;
        @(negedge clk); wr_valid=0; rd_col=3; #1;
        `CHECK(multiplier==1 && bias==0,"out-of-range defaults")
        rd_col=0; rd_bank=0; #1; `CHECK(bias==-40,"bad configuration write ignored")
        rst_n=0; #1; `CHECK(bias==0 && multiplier==1,"qparam reset")
        $display("PASS tb_channel_config checks=%0d",checks); $finish;
    end
endmodule
