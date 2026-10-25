`timescale 1ns/1ps
module skew_injector #(
    parameter integer N=4, K_MAX=16,
    parameter integer DIM_W=(N<2)?1:$clog2(N+1),
    parameter integer K_W=(K_MAX<2)?1:$clog2(K_MAX+1),
    parameter integer INDEX_W=(K_MAX<=1)?1:$clog2(K_MAX)
) (
    input wire active,
    input wire [31:0] step,
    input wire [DIM_W-1:0] rows,cols,
    input wire [K_W-1:0] depth,
    output reg [N-1:0] a_valid,b_valid,
    output reg [N*INDEX_W-1:0] a_index,b_index
);
    always @* begin
        a_valid=0; b_valid=0; a_index=0; b_index=0;
        for(integer l=0;l<N;l=l+1) begin
            if(active && step>=l && step<l+32'(depth)) begin
                if(l<32'(rows)) begin
                    a_valid[l]=1; a_index[l*INDEX_W+:INDEX_W]=INDEX_W'(step-l);
                end
                if(l<32'(cols)) begin
                    b_valid[l]=1; b_index[l*INDEX_W+:INDEX_W]=INDEX_W'(step-l);
                end
            end
        end
    end
endmodule
