`timescale 1ns/1ps
`include "tb_util.svh"
module tb_operand_buffer;
    localparam LANES=3,DEPTH=5,DATA_W=8,LANE_W=2,INDEX_W=3;
    reg clk=0; always #5 clk=~clk;
    reg rst_n=0,wr_valid=0,wr_bank=0,rd_bank=0;
    reg [LANE_W-1:0] wr_lane=0;
    reg [INDEX_W-1:0] wr_index=0;
    reg signed [DATA_W-1:0] wr_data=0;
    reg [LANES-1:0] rd_enable=0;
    reg [LANES*INDEX_W-1:0] rd_index=0;
    wire [LANES*DATA_W-1:0] rd_data;
    integer checks=0;
    operand_buffer #(.LANES(LANES),.DEPTH(DEPTH)) dut(.*);
    `WATCHDOG
    initial begin
        @(negedge clk); rst_n=1; rd_enable='1; #1;
        `CHECK(rd_data==0,"uninitialized reads return zero")
        for(integer bank=0;bank<2;bank=bank+1)
            for(integer l=0;l<LANES;l=l+1)
                for(integer k=0;k<DEPTH;k=k+1) begin
                    @(negedge clk); wr_valid=1; wr_bank=1'(bank); wr_lane=LANE_W'(l);
                    wr_index=INDEX_W'(k); wr_data=8'(bank*50+l*10+k-30);
                end
        @(negedge clk); wr_valid=0;
        for(integer bank=0;bank<2;bank=bank+1) begin
            rd_bank=1'(bank);
            for(integer k=0;k<DEPTH;k=k+1) begin
                for(integer l=0;l<LANES;l=l+1) rd_index[l*INDEX_W+:INDEX_W]=INDEX_W'(k);
                #1;
                for(integer l=0;l<LANES;l=l+1)
                    `CHECK($signed(rd_data[l*DATA_W+:DATA_W])==bank*50+l*10+k-30,"parallel lane/bank read")
            end
        end
        rd_index='1; #1; `CHECK(rd_data==0,"out of range read")
        @(negedge clk); wr_valid=1; wr_lane=3; wr_index=7; wr_data=99;
        @(negedge clk); wr_valid=0; rd_bank=0; rd_index=0; #1;
        `CHECK($signed(rd_data[7:0])==-30,"bad write cannot corrupt valid storage")
        rd_enable=0; #1; `CHECK(rd_data==0,"read mask")
        rst_n=0; rd_enable='1; #1; `CHECK(rd_data==0,"reset invalidates both banks")
        $display("PASS tb_operand_buffer checks=%0d",checks); $finish;
    end
endmodule
