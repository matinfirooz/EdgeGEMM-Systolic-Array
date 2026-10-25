`timescale 1ns/1ps
`include "tb_util.svh"
module tb_skew_injector;
    localparam N=3,K_MAX=5,DIM_W=2,K_W=3,INDEX_W=3;
    reg active=0;
    reg [31:0] step=0;
    reg [DIM_W-1:0] rows=0,cols=0;
    reg [K_W-1:0] depth=0;
    wire [N-1:0] a_valid,b_valid;
    wire [N*INDEX_W-1:0] a_index,b_index;
    integer checks=0;
    reg ea,eb;
    skew_injector #(.N(N),.K_MAX(K_MAX)) dut(.*);
    initial begin
        for(integer m=1;m<=N;m=m+1) for(integer n=1;n<=N;n=n+1)
            for(integer k=1;k<=K_MAX;k=k+1) for(integer t=0;t<k+2*N+2;t=t+1) begin
                rows=DIM_W'(m); cols=DIM_W'(n); depth=K_W'(k); step=32'(t); active=1; #1;
                for(integer l=0;l<N;l=l+1) begin
                    ea=l<m && t>=l && t<l+k; eb=l<n && t>=l && t<l+k;
                    `CHECK(a_valid[l]===ea && b_valid[l]===eb,"skew valid window")
                    if(ea) `CHECK(a_index[l*INDEX_W+:INDEX_W]==t-l,"A skew index")
                    if(eb) `CHECK(b_index[l*INDEX_W+:INDEX_W]==t-l,"B skew index")
                end
            end
        active=0; #1; `CHECK(a_valid==0 && b_valid==0,"idle injects no tokens")
        $display("PASS tb_skew_injector checks=%0d",checks); $finish;
    end
endmodule
