`timescale 1ns/1ps
`include "tb_util.svh"
module tb_requantize;
    reg signed [31:0] in_data=0;
    reg [5:0] right_shift=0;
    reg relu_en=0;
    wire signed [7:0] out_data;
    integer checks=0;
    reg signed [63:0] expected;
    reg [31:0] rng=32'h12345678;
    requantize dut(.*);
    initial begin
        for(integer i=0;i<4096;i=i+1) begin
            rng=1664525*rng+1013904223; in_data=$signed(rng);
            case(i%16)
                0: in_data=32'sh80000000;
                1: in_data=32'sh7fffffff;
                2: in_data=-129;
                3: in_data=128;
                4: in_data=-1;
                default: begin end
            endcase
            right_shift=6'(i%64); relu_en=1'((i/64)%2);
            expected=$signed(in_data); expected=expected >>> right_shift;
            if(relu_en && expected<0) expected=0;
            if(expected>127) expected=127;
            if(expected< -128) expected=-128;
            #1; `CHECK($signed(out_data)===expected,"legacy quantization boundary")
        end
        $display("PASS tb_requantize checks=%0d",checks); $finish;
    end
endmodule
