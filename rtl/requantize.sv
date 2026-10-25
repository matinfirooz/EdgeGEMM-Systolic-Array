`timescale 1ns/1ps
// Original arithmetic-shift/ReLU/saturation interface.
module requantize #(parameter integer ACC_W=32,OUT_W=8) (
    input wire signed [ACC_W-1:0] in_data,
    input wire [5:0] right_shift,
    input wire relu_en,
    output reg signed [OUT_W-1:0] out_data
);
    localparam signed [ACC_W-1:0] MAX_OUT={{(ACC_W-OUT_W){1'b0}},1'b0,{(OUT_W-1){1'b1}}};
    localparam signed [ACC_W-1:0] MIN_OUT={{(ACC_W-OUT_W){1'b1}},1'b1,{(OUT_W-1){1'b0}}};
    reg signed [ACC_W-1:0] shifted;
    always @* begin
        shifted=in_data >>> right_shift;
        if(relu_en && shifted<0) shifted=0;
        if(shifted>MAX_OUT) out_data=MAX_OUT[OUT_W-1:0];
        else if(shifted<MIN_OUT) out_data=MIN_OUT[OUT_W-1:0];
        else out_data=shifted[OUT_W-1:0];
    end
endmodule
