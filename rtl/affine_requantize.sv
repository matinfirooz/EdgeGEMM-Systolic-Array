`timescale 1ns/1ps
// q=clip(round_or_floor(((acc+bias)*unsigned_multiplier)/2**shift)+zp).
// Rounding is nearest with half-way values away from zero. No hidden floats.
module affine_requantize #(parameter integer ACC_W=32,OUT_W=8) (
    input wire signed [ACC_W-1:0] in_data,bias,
    input wire [15:0] multiplier,
    input wire [5:0] right_shift,
    input wire signed [OUT_W-1:0] zero_point,
    input wire relu_en,round_nearest,
    output reg signed [OUT_W-1:0] out_data
);
    localparam integer W=ACC_W+18;
    localparam signed [W:0] MAX_OUT={{(W+1-OUT_W){1'b0}},1'b0,{(OUT_W-1){1'b1}}};
    localparam signed [W:0] MIN_OUT={{(W+1-OUT_W){1'b1}},1'b1,{(OUT_W-1){1'b0}}};
    wire signed [ACC_W:0] biased=$signed({in_data[ACC_W-1],in_data})+$signed({bias[ACC_W-1],bias});
    wire signed [16:0] scale=$signed({1'b0,multiplier});
    wire signed [W-1:0] product=biased*scale;
    reg [W:0] magnitude,rounded_magnitude;
    reg signed [W:0] scaled,shifted_zp;
    wire signed [W:0] zp_ext={{(W+1-OUT_W){zero_point[OUT_W-1]}},zero_point};
    always @* begin
        magnitude=product[W-1] ? -$signed({product[W-1],product}) : {1'b0,product};
        rounded_magnitude=magnitude >> right_shift;
        if(round_nearest && right_shift!=0 && 32'(right_shift)<=W)
            if(magnitude[right_shift-1'b1]) rounded_magnitude=rounded_magnitude+1'b1;
        if(round_nearest) scaled=product[W-1] ? -$signed(rounded_magnitude) : $signed(rounded_magnitude);
        else scaled=$signed({product[W-1],product}) >>> right_shift;
        shifted_zp=scaled+zp_ext;
        if(relu_en && shifted_zp<zp_ext) shifted_zp=zp_ext;
        if(shifted_zp>MAX_OUT) out_data=MAX_OUT[OUT_W-1:0];
        else if(shifted_zp<MIN_OUT) out_data=MIN_OUT[OUT_W-1:0];
        else out_data=shifted_zp[OUT_W-1:0];
    end
`ifndef SYNTHESIS
    initial if(OUT_W<2 || OUT_W>ACC_W) $fatal(1,"invalid quantization widths");
`endif
endmodule
