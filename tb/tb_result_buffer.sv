`timescale 1ns/1ps
`include "tb_util.svh"
module tb_result_buffer;
    reg clk=0; always #5 clk=~clk;
    reg rst_n=0,capture=0;
    reg [3*3*32-1:0] accumulators=0;
    reg [1:0] read_row=0,read_col=0;
    wire signed [31:0] read_data;
    integer checks=0;
    result_buffer #(.N(3)) dut(.*);
    `WATCHDOG
    initial begin
        @(negedge clk); rst_n=1;
        for(integer i=0;i<9;i=i+1) accumulators[i*32+:32]=32'(i*17-51);
        capture=1; @(negedge clk); capture=0; accumulators=0;
        for(integer r=0;r<3;r=r+1) for(integer c=0;c<3;c=c+1) begin
            read_row=2'(r); read_col=2'(c); #1;
            `CHECK(read_data==(r*3+c)*17-51,"snapshot read remains stable after mesh changes")
        end
        read_row=3; #1; `CHECK(read_data==0,"out-of-range snapshot selector")
        rst_n=0; read_row=0; #1; `CHECK(read_data==0,"snapshot reset")
        $display("PASS tb_result_buffer checks=%0d",checks); $finish;
    end
endmodule
