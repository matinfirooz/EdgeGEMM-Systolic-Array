`timescale 1ns/1ps
`include "tb_util.svh"
module tb_systolic_mesh;
    parameter integer N=3,DATA_W=8;
    reg clk=0; always #5 clk=~clk;
    reg rst_n=0,clear=0,enable=0;
    reg [N*DATA_W-1:0] a_left=0,b_top=0;
    reg [N-1:0] a_valid=0,b_valid=0;
    wire [N*N*32-1:0] accumulators;
    wire [N*N-1:0] mac_events,zero_events;
    integer checks=0;
    reg signed [DATA_W-1:0] a [0:N-1][0:4], b [0:4][0:N-1];
    integer ref_c [0:N-1][0:N-1];
    systolic_mesh #(.N(N),.DATA_W(DATA_W)) dut(.*);
    `WATCHDOG
    initial begin
        @(negedge clk); rst_n=1;
        for(integer m=1;m<=N;m=m+1) for(integer n=1;n<=N;n=n+1) for(integer k=1;k<=5;k=k+1) begin
            for(integer r=0;r<N;r=r+1) for(integer x=0;x<5;x=x+1) a[r][x]=DATA_W'(r*7+x*3-8);
            for(integer x=0;x<5;x=x+1) for(integer c=0;c<N;c=c+1) b[x][c]=DATA_W'(x*5-c*7+3);
            for(integer r=0;r<N;r=r+1) for(integer c=0;c<N;c=c+1) begin
                ref_c[r][c]=0;
                if(r<m && c<n) for(integer x=0;x<k;x=x+1) ref_c[r][c]=ref_c[r][c]+$signed(a[r][x])*$signed(b[x][c]);
            end
            @(negedge clk); clear=1; enable=0;
            @(negedge clk); clear=0;
            for(integer t=0;t<k+m+n-2;t=t+1) begin
                a_left=0; b_top=0; a_valid=0; b_valid=0;
                for(integer l=0;l<N;l=l+1) if(t>=l && t<l+k) begin
                    if(l<m) begin a_valid[l]=1; a_left[l*DATA_W+:DATA_W]=a[l][t-l]; end
                    if(l<n) begin b_valid[l]=1; b_top[l*DATA_W+:DATA_W]=b[t-l][l]; end
                end
                enable=0;
                repeat(2) @(negedge clk);
                enable=1; @(negedge clk);
            end
            enable=0;
            for(integer r=0;r<N;r=r+1) for(integer c=0;c<N;c=c+1)
                `CHECK($signed(accumulators[(r*N+c)*32+:32])===ref_c[r][c],"mesh partial tile and paused wavefront")
        end
        $display("PASS tb_systolic_mesh N=%0d W=%0d checks=%0d",N,DATA_W,checks); $finish;
    end
endmodule
