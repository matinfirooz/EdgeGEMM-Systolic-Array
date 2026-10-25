`timescale 1ns/1ps
// Two banks of per-output-column affine quantization parameters.
module channel_config #(
    parameter integer N=4,ACC_W=32,OUT_W=8,
    parameter integer IDX_W=(N<=1)?1:$clog2(N)
) (
    input wire clk,rst_n,wr_valid,wr_bank,
    input wire [IDX_W-1:0] wr_col,
    input wire signed [ACC_W-1:0] wr_bias,
    input wire [15:0] wr_multiplier,
    input wire [5:0] wr_shift,
    input wire signed [OUT_W-1:0] wr_zero_point,
    input wire wr_relu,wr_round,
    input wire rd_bank,
    input wire [IDX_W-1:0] rd_col,
    output reg signed [ACC_W-1:0] bias,
    output reg [15:0] multiplier,
    output reg [5:0] shift,
    output reg signed [OUT_W-1:0] zero_point,
    output reg relu,round_nearest
);
    localparam integer W=ACC_W+16+6+OUT_W+2;
    reg [W-1:0] config_mem [0:2*N-1];
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            for(integer i=0;i<2*N;i=i+1)
                config_mem[i]<={{ACC_W{1'b0}},16'd1,6'd0,{OUT_W{1'b0}},1'b0,1'b0};
        end else if(wr_valid && 32'(wr_col)<N)
            config_mem[32'(wr_bank)*N+32'(wr_col)]<={wr_bias,wr_multiplier,wr_shift,wr_zero_point,wr_relu,wr_round};
    end
    always @* begin
        {bias,multiplier,shift,zero_point,relu,round_nearest}=
            {{ACC_W{1'b0}},16'd1,6'd0,{OUT_W{1'b0}},1'b0,1'b0};
        if(32'(rd_col)<N)
            {bias,multiplier,shift,zero_point,relu,round_nearest}=config_mem[32'(rd_bank)*N+32'(rd_col)];
    end
endmodule
