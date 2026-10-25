`timescale 1ns/1ps
module perf_counters #(parameter integer PE_COUNT=16) (
    input wire clk,rst_n,clear,active,run_enable,
    input wire [PE_COUNT-1:0] mac_events,zero_events,
    output reg [31:0] compute_cycles,stall_cycles,valid_macs,zero_macs
);
    reg [31:0] mac_sum,zero_sum;
    always @* begin
        mac_sum=0; zero_sum=0;
        for(integer i=0;i<PE_COUNT;i=i+1) begin
            mac_sum=mac_sum+{31'd0,mac_events[i]};
            zero_sum=zero_sum+{31'd0,zero_events[i]};
        end
    end
    always @(posedge clk or negedge rst_n)
        if(!rst_n) begin compute_cycles<=0; stall_cycles<=0; valid_macs<=0; zero_macs<=0; end
        else if(clear) begin compute_cycles<=0; stall_cycles<=0; valid_macs<=0; zero_macs<=0; end
        else if(active) begin
            if(run_enable) begin
                compute_cycles<=compute_cycles+1; valid_macs<=valid_macs+mac_sum; zero_macs<=zero_macs+zero_sum;
            end else stall_cycles<=stall_cycles+1;
        end
endmodule
