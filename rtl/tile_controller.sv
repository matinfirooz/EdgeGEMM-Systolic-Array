`timescale 1ns/1ps
module tile_controller #(
    parameter integer N=4,K_MAX=16,
    parameter integer DIM_W=(N<2)?1:$clog2(N+1),
    parameter integer K_W=(K_MAX<2)?1:$clog2(K_MAX+1)
) (
    input wire clk,rst_n,start,run_enable,
    input wire [DIM_W-1:0] cfg_rows,cfg_cols,
    input wire [K_W-1:0] cfg_depth,
    output wire clear,
    output reg busy,done,error,
    output reg [31:0] step,
    output reg [DIM_W-1:0] rows,cols,
    output reg [K_W-1:0] depth
);
    wire valid_dims=(cfg_rows!=0)&&(32'(cfg_rows)<=N)&&
        (cfg_cols!=0)&&(32'(cfg_cols)<=N)&&(cfg_depth!=0)&&(32'(cfg_depth)<=K_MAX);
    assign clear=start && !busy && valid_dims;
    reg [31:0] last_step;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            busy<=0; done<=0; error<=0; step<=0; rows<=0; cols<=0; depth<=0; last_step<=0;
        end else begin
            done<=0; error<=0;
            if(start && !busy) begin
                if(valid_dims) begin
                    busy<=1; step<=0; rows<=cfg_rows; cols<=cfg_cols; depth<=cfg_depth;
                    last_step<=32'(cfg_depth)+32'(cfg_rows)+32'(cfg_cols)-3;
                end else error<=1;
            end else if(busy && run_enable) begin
                if(step==last_step) begin busy<=0; done<=1; end
                else step<=step+1;
            end
        end
    end
endmodule
