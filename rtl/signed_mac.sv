`timescale 1ns/1ps
// Exact two's-complement MAC. Overflow wraps modulo 2**ACC_W.
module signed_mac #(
    parameter integer DATA_W=8, ACC_W=32, ZERO_GATE=1
) (
    input wire clk, rst_n, clear, enable, valid,
    input wire signed [DATA_W-1:0] a, b,
    output reg signed [ACC_W-1:0] acc,
    output wire mac_event, zero_event
);
    wire is_zero = (a == 0) || (b == 0);
    wire issue = enable && valid && !clear;
    wire execute_mac = issue && !((ZERO_GATE != 0) && is_zero);
    // Operand isolation is functional RTL; an energy advantage needs physical data.
    wire signed [DATA_W-1:0] iso_a = execute_mac ? a : {DATA_W{1'b0}};
    wire signed [DATA_W-1:0] iso_b = execute_mac ? b : {DATA_W{1'b0}};
    wire signed [2*DATA_W-1:0] product = iso_a * iso_b;
    wire signed [ACC_W-1:0] extended_product =
        {{(ACC_W-2*DATA_W){product[2*DATA_W-1]}},product};
    assign mac_event = issue;
    assign zero_event = issue && (ZERO_GATE != 0) && is_zero;
    always @(posedge clk or negedge rst_n)
        if (!rst_n) acc <= 0;
        else if (clear) acc <= 0;
        else if (execute_mac) acc <= acc + extended_product;
`ifndef SYNTHESIS
    initial if (DATA_W < 2 || ACC_W < 2*DATA_W)
        $fatal(1,"signed_mac: DATA_W>=2 and ACC_W>=2*DATA_W required");
`endif
endmodule
