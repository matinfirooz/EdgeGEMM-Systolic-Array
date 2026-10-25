`timescale 1ns/1ps
`include "tb_util.svh"
module tb_systolic_pe;
    reg clk=0; always #5 clk=~clk;
    reg rst_n=0,clear=0,enable=0;
    reg signed [7:0] a_in=0,b_in=0;
    reg a_valid_in=0,b_valid_in=0;
    wire signed [7:0] a_out,b_out;
    wire a_valid_out,b_valid_out,mac_event,zero_event;
    wire signed [31:0] acc_out;
    integer checks=0,expected=0;
    reg [7:0] ea=0,eb=0;
    reg eav=0,ebv=0;
    systolic_pe dut(.*);
    `WATCHDOG
    initial begin
        @(negedge clk); rst_n=1;
        for(integer i=0;i<400;i=i+1) begin
            @(negedge clk); a_in=8'(i-199); b_in=8'(i*7);
            a_valid_in=(i%3!=0); b_valid_in=(i%5!=0);
            clear=(i%89==0); enable=(i%7!=0);
            if(clear) begin expected=0; ea=0; eb=0; eav=0; ebv=0; end
            else if(enable) begin
                if(a_valid_in && b_valid_in) expected=expected+$signed(a_in)*$signed(b_in);
                ea=a_valid_in?a_in:0; eb=b_valid_in?b_in:0; eav=a_valid_in; ebv=b_valid_in;
            end
            @(posedge clk); #1;
            `CHECK(acc_out===expected,"valid token MAC")
            `CHECK(a_out===ea && b_out===eb && a_valid_out===eav && b_valid_out===ebv,"token forwarding")
        end
        $display("PASS tb_systolic_pe checks=%0d",checks); $finish;
    end
endmodule
