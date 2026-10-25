`timescale 1ns/1ps
`include "tb_util.svh"
module tb_perf_counters;
    reg clk=0; always #5 clk=~clk;
    reg rst_n=0,clear=0,active=0,run_enable=1;
    reg [3:0] mac_events=0,zero_events=0;
    wire [31:0] compute_cycles,stall_cycles,valid_macs,zero_macs;
    integer checks=0;
    perf_counters #(.PE_COUNT(4)) dut(.*);
    `WATCHDOG
    initial begin
        @(negedge clk); rst_n=1; active=1; mac_events=4'b1111; zero_events=4'b0101;
        repeat(5) @(posedge clk);
        #1; `CHECK(compute_cycles==5 && valid_macs==20 && zero_macs==10,"event popcounts")
        @(negedge clk); run_enable=0;
        repeat(3) @(posedge clk);
        #1; `CHECK(stall_cycles==3 && compute_cycles==5 && valid_macs==20,"paused counter qualification")
        @(negedge clk); active=0;
        repeat(2) @(posedge clk);
        #1; `CHECK(stall_cycles==3 && valid_macs==20,"idle holds counters")
        @(negedge clk); clear=1;
        @(posedge clk); #1; `CHECK((compute_cycles|stall_cycles|valid_macs|zero_macs)==0,"clear priority")
        $display("PASS tb_perf_counters checks=%0d",checks); $finish;
    end
endmodule
