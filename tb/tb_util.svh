`ifndef EDGEGEMM_TB_UTIL
`define EDGEGEMM_TB_UTIL
`define CHECK(COND,MSG) begin checks=checks+1; if((COND)!==1'b1) $fatal(1,"%s (check %0d)",MSG,checks); end
`define WATCHDOG initial begin #2000000; $fatal(1,"global testbench watchdog"); end
`endif
