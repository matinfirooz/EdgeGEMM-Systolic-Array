`timescale 1ns/1ps
module systolic_pe #(
    parameter integer DATA_W=8, ACC_W=32, ZERO_GATE=1
) (
    input wire clk,rst_n,clear,enable,
    input wire signed [DATA_W-1:0] a_in,b_in,
    input wire a_valid_in,b_valid_in,
    output reg signed [DATA_W-1:0] a_out,b_out,
    output reg a_valid_out,b_valid_out,
    output wire signed [ACC_W-1:0] acc_out,
    output wire mac_event,zero_event
);
    signed_mac #(.DATA_W(DATA_W),.ACC_W(ACC_W),.ZERO_GATE(ZERO_GATE)) u_mac (
        .clk(clk),.rst_n(rst_n),.clear(clear),.enable(enable),
        .valid(a_valid_in && b_valid_in),.a(a_in),.b(b_in),
        .acc(acc_out),.mac_event(mac_event),.zero_event(zero_event));
    always @(posedge clk or negedge rst_n)
        if (!rst_n) begin
            a_out<=0; b_out<=0; a_valid_out<=0; b_valid_out<=0;
        end else if (clear) begin
            a_out<=0; b_out<=0; a_valid_out<=0; b_valid_out<=0;
        end else if (enable) begin
            a_out<=a_valid_in ? a_in : {DATA_W{1'b0}};
            b_out<=b_valid_in ? b_in : {DATA_W{1'b0}};
            a_valid_out<=a_valid_in; b_valid_out<=b_valid_in;
        end
endmodule
