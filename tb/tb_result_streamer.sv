`timescale 1ns/1ps
`include "tb_util.svh"
module tb_result_streamer;
    reg clk=0; always #5 clk=~clk;
    reg rst_n=0,start=0,out_ready=0;
    reg [1:0] rows=0,cols=0;
    wire out_valid,out_last,busy,done;
    wire [1:0] out_row,out_col;
    integer checks=0,count;
    reg [1:0] held_row,held_col;
    result_streamer #(.N(3)) dut(.*);
    `WATCHDOG
    initial begin
        @(negedge clk); rst_n=1;
        for(integer m=1;m<=3;m=m+1) for(integer n=1;n<=3;n=n+1) begin
            @(negedge clk); rows=2'(m); cols=2'(n); start=1;
            @(negedge clk); start=0; rows=0; cols=0; count=0;
            while(busy) begin
                held_row=out_row; held_col=out_col; out_ready=0;
                repeat(3) begin
                    @(posedge clk); #1;
                    `CHECK(out_valid && out_row==held_row && out_col==held_col,"stalled stream holds address")
                end
                @(negedge clk); out_ready=1; #1;
                `CHECK(out_row==count/n && out_col==count%n,"row-major stream")
                `CHECK(out_last==(count==m*n-1),"last flag")
                @(posedge clk); #1; count=count+1;
                @(negedge clk);
            end
            `CHECK(count==m*n,"one beat per valid output")
        end
        $display("PASS tb_result_streamer checks=%0d",checks); $finish;
    end
endmodule
