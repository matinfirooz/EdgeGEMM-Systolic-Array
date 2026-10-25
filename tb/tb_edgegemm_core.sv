`timescale 1ns/1ps
`include "tb_util.svh"
module tb_edgegemm_core;
    parameter integer N=4,K_MAX=9,DATA_W=8,ZERO_GATE=1;
    localparam integer ACC_W=32,OUT_W=8,IDX_W=(N<=1)?1:$clog2(N);
    localparam integer DIM_W=(N<2)?1:$clog2(N+1),INDEX_W=(K_MAX<=1)?1:$clog2(K_MAX);
    localparam integer K_W=(K_MAX<2)?1:$clog2(K_MAX+1);
    reg clk=0; always #5 clk=~clk;
    reg rst_n=0,run_enable=1;
    reg load_valid=0,load_bank=0,load_sel=0;
    reg [IDX_W-1:0] load_lane=0;
    reg [INDEX_W-1:0] load_index=0;
    reg signed [DATA_W-1:0] load_data=0;
    wire load_ready,load_error;
    reg qcfg_valid=0,qcfg_bank=0;
    reg [IDX_W-1:0] qcfg_col=0;
    reg signed [31:0] qcfg_bias=0;
    reg [15:0] qcfg_multiplier=1;
    reg [5:0] qcfg_shift=0;
    reg signed [7:0] qcfg_zero_point=0;
    reg qcfg_relu=0,qcfg_round=0;
    wire qcfg_ready,qcfg_error;
    reg cmd_valid=0,cmd_bank=0;
    reg [DIM_W-1:0] cmd_rows=0,cmd_cols=0;
    reg [K_W-1:0] cmd_depth=0;
    wire cmd_ready,cmd_error,busy,done,out_valid,out_last;
    reg out_ready=0;
    wire [IDX_W-1:0] out_row,out_col;
    wire signed [31:0] out_acc;
    wire signed [7:0] out_quant;
    wire [31:0] perf_compute_cycles,perf_stall_cycles,perf_valid_macs,perf_zero_macs;
    integer checks=0,jobs=0,overlap_writes=0,observed_stalls=0;
    reg trace_window=0;
    reg [7:0] file_a[0:35],file_b[0:35],file_q[0:15];
    reg [31:0] file_c[0:15];
    reg signed [DATA_W-1:0] ref_a [0:1][0:N-1][0:K_MAX-1];
    reg signed [DATA_W-1:0] ref_b [0:1][0:K_MAX-1][0:N-1];
    integer qb [0:1][0:N-1],qm [0:1][0:N-1],qs [0:1][0:N-1],qz [0:1][0:N-1];
    reg qr [0:1][0:N-1],qn [0:1][0:N-1];
    edgegemm_core #(.N(N),.K_MAX(K_MAX),.DATA_W(DATA_W),.ZERO_GATE(ZERO_GATE)) dut(.*);
    `WATCHDOG
    always @(posedge clk) if(rst_n) begin
        if(load_valid && load_ready && busy) overlap_writes=overlap_writes+1;
        if(dut.compute_busy && !run_enable) observed_stalls=observed_stalls+1;
    end
    function automatic integer quant_ref(input integer acc,input integer bank,input integer col);
        reg signed [63:0] p,v;
        begin
            p=(64'(acc)+64'(qb[bank][col]))*64'(qm[bank][col]);
            if(!qn[bank][col]) v=p >>> qs[bank][col];
            else if(qs[bank][col]==0) v=p;
            else if(p<0) v=-(((-p)+(64'sd1<<(qs[bank][col]-1)))>>qs[bank][col]);
            else v=(p+(64'sd1<<(qs[bank][col]-1)))>>qs[bank][col];
            v=v+qz[bank][col];
            if(qr[bank][col] && v<qz[bank][col]) v=qz[bank][col];
            if(v>127) v=127;
            if(v< -128) v=-128;
            quant_ref=32'(v);
        end
    endfunction
    task automatic program_tile(input integer bank,input integer m,input integer n,input integer k,input integer seed);
        reg [31:0] rng;
        reg signed [DATA_W-1:0] value;
        begin
            rng=32'(seed);
            for(integer r=0;r<m;r=r+1) for(integer x=0;x<k;x=x+1) begin
                rng=1664525*rng+1013904223; value=DATA_W'(rng>>16);
                if((rng & 7)==0) value=0;
                if(seed==999 && N==4 && K_MAX==9 && DATA_W==8) value=DATA_W'(file_a[r*K_MAX+x]);
                ref_a[bank][r][x]=value;
                @(negedge clk); load_valid=1; load_bank=1'(bank); load_sel=0;
                load_lane=IDX_W'(r); load_index=INDEX_W'(x); load_data=value;
                #1; `CHECK(load_ready,"A programming handshake")
                @(posedge clk); #1;
            end
            for(integer x=0;x<k;x=x+1) for(integer c=0;c<n;c=c+1) begin
                rng=1664525*rng+1013904223; value=DATA_W'(rng>>16);
                if((rng & 3)==0) value=0;
                if(seed==999 && N==4 && K_MAX==9 && DATA_W==8) value=DATA_W'(file_b[x*N+c]);
                ref_b[bank][x][c]=value;
                @(negedge clk); load_valid=1; load_bank=1'(bank); load_sel=1;
                load_lane=IDX_W'(c); load_index=INDEX_W'(x); load_data=value;
                #1; `CHECK(load_ready,"B programming handshake")
                @(posedge clk); #1;
            end
            @(negedge clk); load_valid=0;
            for(integer c=0;c<n;c=c+1) begin
                qb[bank][c]=c*11-seed%37; qm[bank][c]=c%4+1; qs[bank][c]=(c+seed)%6;
                qz[bank][c]=c*3-7; qr[bank][c]=1'(c%2); qn[bank][c]=1'((seed+c)%2);
                @(negedge clk); qcfg_valid=1; qcfg_bank=1'(bank); qcfg_col=IDX_W'(c);
                qcfg_bias=qb[bank][c]; qcfg_multiplier=16'(qm[bank][c]); qcfg_shift=6'(qs[bank][c]);
                qcfg_zero_point=8'(qz[bank][c]); qcfg_relu=qr[bank][c]; qcfg_round=qn[bank][c];
                #1; `CHECK(qcfg_ready,"quantization programming handshake")
                @(posedge clk); #1;
            end
            @(negedge clk); qcfg_valid=0;
        end
    endtask
    task automatic execute(input integer bank,input integer m,input integer n,input integer k,input integer seed);
        integer count,guard,expected,zero_count,stall_base;
        reg [31:0] rng;
        reg was_stalled;
        reg [31:0] held_acc;
        reg [7:0] held_quant;
        reg [IDX_W-1:0] held_row,held_col;
        reg held_last;
        begin
            @(negedge clk);
            `CHECK(cmd_ready,"ready before command")
            if(jobs==1) trace_window=1;
            cmd_valid=1; cmd_bank=1'(bank); cmd_rows=DIM_W'(m); cmd_cols=DIM_W'(n); cmd_depth=K_W'(k);
            run_enable=1; out_ready=0; stall_base=observed_stalls;
            @(posedge clk); #1; `CHECK(busy && !cmd_error,"accepted valid command")
            @(negedge clk); cmd_valid=0;
            count=0; guard=0; rng=32'(seed); was_stalled=0;
            zero_count=0;
            for(integer r=0;r<m;r=r+1) for(integer c=0;c<n;c=c+1) for(integer x=0;x<k;x=x+1)
                if(ref_a[bank][r][x]==0 || ref_b[bank][x][c]==0) zero_count=zero_count+1;
            while(!done && guard<4000) begin
                @(negedge clk); rng=1664525*rng+1013904223;
                run_enable=(rng[3:0]!=0) && (guard%7!=0);
                // Force a multi-cycle result stall, then randomized backpressure.
                out_ready=(guard>k+m+n+5) && (rng[7:6]!=0);
                #1;
                `CHECK(!cmd_ready,"command blocked until last result consumed")
                if(was_stalled) begin
                    `CHECK(out_valid && out_acc===held_acc && out_quant===held_quant && out_row==held_row && out_col==held_col && out_last==held_last,"full output payload stable under backpressure")
                end
                if(out_valid && out_ready) begin
                    `CHECK(count<m*n && out_row==count/n && out_col==count%n,"stream ordering/shape")
                    expected=0;
                    for(integer x=0;x<k;x=x+1) expected=expected+$signed(ref_a[bank][count/n][x])*$signed(ref_b[bank][x][count%n]);
                    if(out_acc!==expected) $display("cell %0d,%0d got %0d expected %0d",out_row,out_col,out_acc,expected);
                    `CHECK(out_acc===expected,"rectangular GEMM integer reference")
                    `CHECK($signed(out_quant)==quant_ref(expected,bank,count%n),"per-column affine reference")
                    `CHECK(out_last==(count==m*n-1),"last beat flag")
                    if(seed==999 && N==4 && K_MAX==9 && DATA_W==8) begin
                        `CHECK(out_acc===file_c[count],"external Python raw golden")
                        `CHECK(out_quant===file_q[count],"external Python quantized golden")
                    end
                    count=count+1;
                end
                was_stalled=out_valid && !out_ready;
                held_acc=out_acc; held_quant=out_quant; held_row=out_row; held_col=out_col; held_last=out_last;
                @(posedge clk); #1; guard=guard+1;
            end
            `CHECK(done && count==m*n && !busy,"job completes after exactly m*n handshakes")
            `CHECK(perf_compute_cycles==k+m+n-2,"active compute cycles")
            `CHECK(perf_stall_cycles==observed_stalls-stall_base,"measured pause cycles")
            `CHECK(perf_valid_macs==m*n*k,"valid MAC event count")
            `CHECK(perf_zero_macs==(ZERO_GATE?zero_count:0),"exact zero opportunity count")
            if(jobs==1) trace_window=0;
            jobs=jobs+1;
            @(negedge clk); out_ready=0; run_enable=1;
            @(posedge clk); #1; `CHECK(!done,"done is one cycle")
        end
    endtask
    task automatic reset_engine;
        begin
            @(negedge clk); rst_n=0; cmd_valid=0; load_valid=0; qcfg_valid=0; out_ready=0; run_enable=1;
            repeat(2) @(negedge clk);
            `CHECK(!busy && !out_valid && !done && perf_compute_cycles==0,"reset flushes in-flight work")
            rst_n=1;
            for(integer b=0;b<2;b=b+1) for(integer c=0;c<N;c=c+1) begin
                qb[b][c]=0; qm[b][c]=1; qs[b][c]=0; qz[b][c]=0; qr[b][c]=0; qn[b][c]=0;
                for(integer x=0;x<K_MAX;x=x+1) begin ref_a[b][c][x]=0; ref_b[b][x][c]=0; end
            end
        end
    endtask
    initial begin
        if($test$plusargs("vcd")) begin $dumpfile("build/core.vcd"); $dumpvars(0,tb_edgegemm_core); end
        if(N==4 && K_MAX==9 && DATA_W==8) begin
            $readmemh("vectors/core_a.hex",file_a); $readmemh("vectors/core_b.hex",file_b);
            $readmemh("vectors/core_golden.hex",file_c); $readmemh("vectors/core_quant.hex",file_q);
        end
        reset_engine();
        execute(0,1,1,1,100); // deterministic zero read from an uninitialized bank
        // Invalid commands and addresses are consumed with an explicit error pulse.
        @(negedge clk); cmd_valid=1; cmd_rows=0; cmd_cols=1; cmd_depth=1;
        @(posedge clk); #1; `CHECK(cmd_error && !busy,"bad command rejected")
        @(negedge clk); cmd_valid=0;
        if((1<<IDX_W)>N) begin
            load_valid=1; load_lane=IDX_W'(N); load_index=0;
            @(posedge clk); #1; `CHECK(load_error,"invalid load lane diagnosed")
            @(negedge clk); load_valid=0; qcfg_valid=1; qcfg_col=IDX_W'(N);
            @(posedge clk); #1; `CHECK(qcfg_error,"invalid config column diagnosed")
            @(negedge clk); qcfg_valid=0;
        end
        program_tile(0,N,N,K_MAX,42);
        // Verify ownership and command isolation while compute is deliberately paused.
        @(negedge clk); cmd_valid=1; cmd_bank=0; cmd_rows=DIM_W'(N); cmd_cols=DIM_W'(N); cmd_depth=K_W'(K_MAX); run_enable=0;
        @(negedge clk); cmd_valid=0; load_bank=0; qcfg_bank=0;
        load_valid=1; load_lane=0; load_index=0; load_data=99;
        qcfg_valid=1; qcfg_col=0; qcfg_multiplier=65535;
        #1; `CHECK(!load_ready && !qcfg_ready && !cmd_ready,"active bank is protected")
        @(negedge clk); load_valid=0; qcfg_valid=0; cmd_valid=1; cmd_rows=0;
        @(negedge clk); cmd_valid=0; #1; `CHECK(!cmd_error && busy,"busy command ignored without corruption")
        reset_engine();
        // Two real jobs: preload the alternate bank while bank 0 computes/drains.
        program_tile(0,N,N,K_MAX,42);
        fork
            execute(0,N,N,K_MAX,144);
            begin wait(busy); program_tile(1,N,(N>1)?N-1:1,K_MAX,88); end
        join
        `CHECK(overlap_writes>0,"inactive bank loading overlaps an active job")
        execute(1,N,(N>1)?N-1:1,K_MAX,145);
        for(integer t=0;t<18;t=t+1) begin
            program_tile(t%2,1+t%N,1+(t*3)%N,1+(t*5)%K_MAX,101+t);
            execute(t%2,1+t%N,1+(t*3)%N,1+(t*5)%K_MAX,200+t);
        end
        if(N==4 && K_MAX==9 && DATA_W==8) begin
            program_tile(0,3,4,7,999); execute(0,3,4,7,999);
        end
        // Abort during compute and while a valid result is stalled.
        @(negedge clk); cmd_valid=1; cmd_rows=1; cmd_cols=1; cmd_depth=1; cmd_bank=0;
        @(negedge clk); cmd_valid=0; run_enable=0;
        reset_engine();
        @(negedge clk); cmd_valid=1; cmd_rows=1; cmd_cols=1; cmd_depth=1;
        @(negedge clk); cmd_valid=0;
        wait(out_valid); #1; `CHECK(!out_ready && busy,"result waiting before abort")
        reset_engine(); execute(0,1,1,1,333);
        $display("PASS tb_edgegemm_core N=%0d K=%0d W=%0d gate=%0d jobs=%0d checks=%0d overlap_writes=%0d",N,K_MAX,DATA_W,ZERO_GATE,jobs,checks,overlap_writes);
        $finish;
    end
endmodule
