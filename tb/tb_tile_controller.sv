`timescale 1ns/1ps
`include "tb_util.svh"
module tb_tile_controller;
    localparam N=3,K_MAX=5,DIM_W=2,K_W=3;
    reg clk=0; always #5 clk=~clk;
    reg rst_n=0,start=0,run_enable=1;
    reg [DIM_W-1:0] cfg_rows=0,cfg_cols=0;
    reg [K_W-1:0] cfg_depth=0;
    wire clear,busy,done,error;
    wire [31:0] step;
    wire [DIM_W-1:0] rows,cols;
    wire [K_W-1:0] depth;
    integer checks=0,cycles,pauses;
    tile_controller #(.N(N),.K_MAX(K_MAX)) dut(.*);
    `WATCHDOG
    initial begin
        @(negedge clk); rst_n=1; start=1;
        @(posedge clk); #1; `CHECK(error && !busy,"zero dimensions rejected")
        @(negedge clk); start=0;
        for(integer m=1;m<=N;m=m+1) for(integer n=1;n<=N;n=n+1) for(integer k=1;k<=K_MAX;k=k+1) begin
            @(negedge clk); start=1; cfg_rows=DIM_W'(m); cfg_cols=DIM_W'(n); cfg_depth=K_W'(k); #1;
            `CHECK(clear,"clear on accepted launch")
            @(posedge clk); #1; `CHECK(busy && step==0 && !done,"launch state")
            @(negedge clk); start=0; run_enable=0;
            repeat(3) begin @(posedge clk); #1; `CHECK(step==0 && busy && !done,"pause holds step") end
            @(negedge clk); run_enable=1; cycles=0;
            while(!done) begin @(posedge clk); #1; cycles=cycles+1; end
            `CHECK(cycles==k+m+n-2 && !busy,"rectangular wavefront latency")
            @(posedge clk); #1; `CHECK(!done,"completion pulse")
        end
        @(negedge clk); cfg_depth=7; start=1;
        @(posedge clk); #1; `CHECK(error && !busy,"too-large depth rejected")
        $display("PASS tb_tile_controller checks=%0d",checks); $finish;
    end
endmodule
