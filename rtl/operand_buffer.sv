`timescale 1ns/1ps
// Two banks, one independently addressed asynchronous read per lane.
// Register/distributed storage reference, not a synchronous block-SRAM macro.
module operand_buffer #(
    parameter integer LANES=4, DEPTH=16, DATA_W=8,
    parameter integer LANE_W=(LANES<=1)?1:$clog2(LANES),
    parameter integer INDEX_W=(DEPTH<=1)?1:$clog2(DEPTH)
) (
    input wire clk,rst_n,wr_valid,wr_bank,
    input wire [LANE_W-1:0] wr_lane,
    input wire [INDEX_W-1:0] wr_index,
    input wire signed [DATA_W-1:0] wr_data,
    input wire rd_bank,
    input wire [LANES-1:0] rd_enable,
    input wire [LANES*INDEX_W-1:0] rd_index,
    output reg [LANES*DATA_W-1:0] rd_data
);
    localparam integer CELLS=2*LANES*DEPTH;
    reg signed [DATA_W-1:0] mem [0:CELLS-1];
    reg [CELLS-1:0] initialized;
    always @(posedge clk or negedge rst_n)
        if(!rst_n) initialized<=0;
        else if(wr_valid && 32'(wr_lane)<LANES && 32'(wr_index)<DEPTH) begin
            mem[32'(wr_bank)*LANES*DEPTH+32'(wr_lane)*DEPTH+32'(wr_index)]<=wr_data;
            initialized[32'(wr_bank)*LANES*DEPTH+32'(wr_lane)*DEPTH+32'(wr_index)]<=1;
        end
    always @* begin
        rd_data=0;
        for(integer l=0;l<LANES;l=l+1)
            if(rd_enable[l] && 32'(rd_index[l*INDEX_W+:INDEX_W])<DEPTH)
                if(initialized[32'(rd_bank)*LANES*DEPTH+l*DEPTH+32'(rd_index[l*INDEX_W+:INDEX_W])])
                    rd_data[l*DATA_W+:DATA_W]=mem[32'(rd_bank)*LANES*DEPTH+l*DEPTH+32'(rd_index[l*INDEX_W+:INDEX_W])];
    end
endmodule
