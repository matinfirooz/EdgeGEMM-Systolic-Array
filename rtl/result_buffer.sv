`timescale 1ns/1ps
module result_buffer #(
    parameter integer N=4,ACC_W=32,
    parameter integer IDX_W=(N<=1)?1:$clog2(N)
) (
    input wire clk,rst_n,capture,
    input wire [N*N*ACC_W-1:0] accumulators,
    input wire [IDX_W-1:0] read_row,read_col,
    output reg signed [ACC_W-1:0] read_data
);
    reg [N*N*ACC_W-1:0] snapshot;
    always @(posedge clk or negedge rst_n)
        if(!rst_n) snapshot<=0;
        else if(capture) snapshot<=accumulators;
    always @* begin
        read_data=0;
        if(32'(read_row)<N && 32'(read_col)<N)
            read_data=snapshot[(32'(read_row)*N+32'(read_col))*ACC_W+:ACC_W];
    end
endmodule
