`timescale 1ns/1ps
`include "tb_util.svh"
module tb_affine_requantize;
    reg signed [31:0] in_data=0,bias=0;
    reg [15:0] multiplier=1;
    reg [5:0] right_shift=0;
    reg signed [7:0] zero_point=0;
    reg relu_en=0,round_nearest=0;
    wire signed [7:0] out_data;
    integer checks=0;
    reg [31:0] rng=32'h9f4242;
    reg signed [63:0] p,expected;
    affine_requantize dut(.*);
    task automatic check_output;
        begin
            p=($signed(64'(in_data))+$signed(64'(bias)))*$signed({1'b0,multiplier});
            if(!round_nearest) expected=p >>> right_shift;
            else if(right_shift==0) expected=p;
            else if(p<0) expected=-(((-p)+(64'sd1<<(right_shift-1)))>>right_shift);
            else expected=(p+(64'sd1<<(right_shift-1)))>>right_shift;
            expected=expected+$signed(zero_point);
            if(relu_en && expected<$signed(zero_point)) expected=$signed(zero_point);
            if(expected>127) expected=127;
            if(expected< -128) expected=-128;
            #1;
            if($signed(out_data)!==expected)
                $display("acc=%0d bias=%0d mul=%0d sh=%0d zp=%0d round=%0d relu=%0d got=%0d expected=%0d",in_data,bias,multiplier,right_shift,zero_point,round_nearest,relu_en,out_data,expected);
            `CHECK($signed(out_data)===expected,"affine quantization integer reference")
        end
    endtask
    initial begin
        // Small values preserve half-way cases instead of saturating them away.
        for(integer x=-259;x<=259;x=x+1) for(integer r=0;r<2;r=r+1) begin
            in_data=x; bias=0; multiplier=1; right_shift=1; zero_point=0; round_nearest=1'(r); relu_en=0;
            check_output();
        end
        for(integer i=0;i<8192;i=i+1) begin
            rng=1664525*rng+1013904223; in_data=$signed(rng);
            rng=1664525*rng+1013904223; bias=$signed(rng);
            multiplier=16'(rng>>8); right_shift=6'(i%64); zero_point=8'(rng>>24);
            relu_en=1'((i/64)%2); round_nearest=1'((i/128)%2);
            case(i%32)
                0: begin in_data=32'sh80000000; bias=in_data; multiplier=65535; end
                1: begin in_data=32'sh7fffffff; bias=in_data; multiplier=65535; end
                2: multiplier=0;
                3: begin in_data=-1; bias=0; multiplier=1; end
                default: begin end
            endcase
            check_output();
        end
        $display("PASS tb_affine_requantize checks=%0d",checks); $finish;
    end
endmodule
