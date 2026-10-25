`timescale 1ns/1ps
// Packed lane 0 / PE(0,0) occupies the least significant slice.
module systolic_mesh #(
    parameter integer N=4, DATA_W=8, ACC_W=32, ZERO_GATE=1
) (
    input wire clk,rst_n,clear,enable,
    input wire [N*DATA_W-1:0] a_left,b_top,
    input wire [N-1:0] a_valid,b_valid,
    output wire [N*N*ACC_W-1:0] accumulators,
    output wire [N*N-1:0] mac_events,zero_events
);
    wire [DATA_W-1:0] a [0:N*N-1],b [0:N*N-1];
    wire av [0:N*N-1],bv [0:N*N-1];
    genvar r,c;
    generate for(r=0;r<N;r=r+1) begin: ROW
        for(c=0;c<N;c=c+1) begin: COL
            wire [DATA_W-1:0] ai,bi;
            wire avi,bvi;
            if(c==0) begin: WEST
                assign ai=a_left[r*DATA_W+:DATA_W]; assign avi=a_valid[r];
            end else begin: HOP_A
                assign ai=a[r*N+c-1]; assign avi=av[r*N+c-1];
            end
            if(r==0) begin: NORTH
                assign bi=b_top[c*DATA_W+:DATA_W]; assign bvi=b_valid[c];
            end else begin: HOP_B
                assign bi=b[(r-1)*N+c]; assign bvi=bv[(r-1)*N+c];
            end
            systolic_pe #(.DATA_W(DATA_W),.ACC_W(ACC_W),.ZERO_GATE(ZERO_GATE)) u_pe (
                .clk(clk),.rst_n(rst_n),.clear(clear),.enable(enable),
                .a_in(ai),.b_in(bi),.a_valid_in(avi),.b_valid_in(bvi),
                .a_out(a[r*N+c]),.b_out(b[r*N+c]),
                .a_valid_out(av[r*N+c]),.b_valid_out(bv[r*N+c]),
                .acc_out(accumulators[(r*N+c)*ACC_W+:ACC_W]),
                .mac_event(mac_events[r*N+c]),.zero_event(zero_events[r*N+c]));
        end
    end endgenerate
endmodule
