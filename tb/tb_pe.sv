`timescale 1ns/1ps
`include "tb_util.svh"
module tb_pe;
    parameter integer DATA_W=8;
    reg clk=0; always #5 clk=~clk;
    reg rst_n=0,clear=0,enable=0;
    reg signed [DATA_W-1:0] a_in=0,b_in=0;
    wire signed [DATA_W-1:0] a_out,b_out;
    wire signed [31:0] acc_out;
    integer checks=0,expected=0;
    reg signed [DATA_W-1:0] ea=0,eb=0;
    pe #(.DATA_W(DATA_W)) dut(.*);
    `WATCHDOG
    initial begin
        @(negedge clk); rst_n=1;
        for(integer i=0;i<200;i=i+1) begin
            @(negedge clk); a_in=DATA_W'(i-97); b_in=DATA_W'(65-i);
            clear=(i%47==0); enable=(i%4!=0);
            if(clear) begin expected=0; ea=0; eb=0; end
            else if(enable) begin expected=expected+$signed(a_in)*$signed(b_in); ea=a_in; eb=b_in; end
            @(posedge clk); #1;
            `CHECK(acc_out===expected,"PE accumulation")
            `CHECK(a_out===ea && b_out===eb,"PE forwarding/hold/clear")
        end
        $display("PASS tb_pe W=%0d checks=%0d",DATA_W,checks); $finish;
    end
endmodule
