`timescale 1ns/1ps
`include "tb_util.svh"
module tb_signed_mac;
    parameter integer DATA_W=8,ACC_W=32,ZERO_GATE=1;
    reg clk=0; always #5 clk=~clk;
    reg rst_n=0,clear=0,enable=0,valid=0;
    reg signed [DATA_W-1:0] a=0,b=0;
    wire signed [ACC_W-1:0] acc;
    wire mac_event,zero_event;
    reg signed [ACC_W-1:0] expected=0;
    integer checks=0;
    reg [31:0] rng=32'h927abc;
    signed_mac #(.DATA_W(DATA_W),.ACC_W(ACC_W),.ZERO_GATE(ZERO_GATE)) dut(.*);
    `WATCHDOG
    initial begin
        #1; @(negedge clk); rst_n=1;
        for(integer i=0;i<1200;i=i+1) begin
            @(negedge clk);
            rng=1664525*rng+1013904223;
            a=DATA_W'(rng>>8); b=DATA_W'(rng>>20);
            if(i%7==0) a=0;
            if(i%11==0) b=0;
            if(i<4) begin a={1'b1,{(DATA_W-1){1'b0}}}; b=a; end
            enable=(i%5!=0); valid=(i%3!=0); clear=(i%101==0);
            #1;
            `CHECK(mac_event==(enable && valid && !clear),"MAC event qualification")
            `CHECK(zero_event==(enable && valid && !clear && ZERO_GATE && (a==0 || b==0)),"zero qualification")
            if(clear) expected=0;
            else if(enable && valid) expected=expected+$signed(a)*$signed(b);
            @(posedge clk); #1;
            `CHECK(acc===expected,"signed MAC/reference mismatch")
        end
        @(negedge clk); rst_n=0; #1; `CHECK(acc==0,"async reset")
        $display("PASS tb_signed_mac W=%0d A=%0d gate=%0d checks=%0d",DATA_W,ACC_W,ZERO_GATE,checks); $finish;
    end
endmodule
