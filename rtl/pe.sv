`timescale 1ns/1ps
// Original EdgeGEMM PE interface, retained for existing users.
module pe #(parameter integer DATA_W=8, ACC_W=32) (
    input wire clk, rst_n, clear, enable,
    input wire signed [DATA_W-1:0] a_in,b_in,
    output reg signed [DATA_W-1:0] a_out,b_out,
    output wire signed [ACC_W-1:0] acc_out
);
    wire unused_mac, unused_zero;
    signed_mac #(.DATA_W(DATA_W),.ACC_W(ACC_W)) u_mac (
        .clk(clk),.rst_n(rst_n),.clear(clear),.enable(enable),.valid(1'b1),
        .a(a_in),.b(b_in),.acc(acc_out),.mac_event(unused_mac),.zero_event(unused_zero));
    always @(posedge clk or negedge rst_n)
        if (!rst_n) begin a_out<=0; b_out<=0; end
        else if (clear) begin a_out<=0; b_out<=0; end
        else if (enable) begin a_out<=a_in; b_out<=b_in; end
endmodule
