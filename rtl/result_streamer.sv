`timescale 1ns/1ps
// Address sequencer. The result buffer remains stable until the last handshake.
module result_streamer #(
    parameter integer N=4,
    parameter integer DIM_W=(N<2)?1:$clog2(N+1),
    parameter integer IDX_W=(N<=1)?1:$clog2(N)
) (
    input wire clk,rst_n,start,
    input wire [DIM_W-1:0] rows,cols,
    input wire out_ready,
    output wire out_valid,out_last,
    output reg [IDX_W-1:0] out_row,out_col,
    output reg busy,done
);
    reg [DIM_W-1:0] held_rows,held_cols;
    assign out_valid=busy;
    assign out_last=busy && (32'(out_row)==32'(held_rows)-1) && (32'(out_col)==32'(held_cols)-1);
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin busy<=0; done<=0; out_row<=0; out_col<=0; held_rows<=0; held_cols<=0; end
        else begin
            done<=0;
            if(start && !busy && rows!=0 && cols!=0 && 32'(rows)<=N && 32'(cols)<=N) begin
                held_rows<=rows; held_cols<=cols; out_row<=0; out_col<=0; busy<=1;
            end else if(busy && out_ready) begin
                if(out_last) begin busy<=0; done<=1; end
                else if(32'(out_col)==32'(held_cols)-1) begin out_col<=0; out_row<=out_row+1'b1; end
                else out_col<=out_col+1'b1;
            end
        end
    end
endmodule
