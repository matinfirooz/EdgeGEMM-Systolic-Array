`timescale 1ns/1ps

module tb_edgegemm_top;
    localparam int N      = 4;
    localparam int DATA_W = 8;
    localparam int ACC_W  = 32;
    localparam int IDX_W  = $clog2(N);

    logic clk;
    logic rst_n;

    logic                     load_we;
    logic                     load_sel;
    logic [IDX_W-1:0]         load_row;
    logic [IDX_W-1:0]         load_col;
    logic signed [DATA_W-1:0] load_data;
    logic                     start;
    logic                     busy;
    logic                     done;
    logic [31:0]              perf_cycles;
    logic [IDX_W-1:0]         result_row;
    logic [IDX_W-1:0]         result_col;
    logic signed [ACC_W-1:0]  result_acc;
    logic [5:0]               quant_shift;
    logic                     relu_en;
    logic signed [7:0]        result_q8;

    logic [7:0]  a_vec [0:N*N-1];
    logic [7:0]  b_vec [0:N*N-1];
    logic [31:0] g_vec [0:N*N-1];

    integer r;
    integer c;
    integer idx;
    integer errors;
    integer watchdog;

    edgegemm_top #(
        .N(N),
        .DATA_W(DATA_W),
        .ACC_W(ACC_W),
        .IDX_W(IDX_W)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .load_we(load_we),
        .load_sel(load_sel),
        .load_row(load_row),
        .load_col(load_col),
        .load_data(load_data),
        .start(start),
        .busy(busy),
        .done(done),
        .perf_cycles(perf_cycles),
        .result_row(result_row),
        .result_col(result_col),
        .result_acc(result_acc),
        .quant_shift(quant_shift),
        .relu_en(relu_en),
        .result_q8(result_q8)
    );

    always #5 clk = ~clk;

    task automatic write_elem(
        input logic sel,
        input integer rr,
        input integer cc,
        input logic [7:0] value
    );
        begin
            @(negedge clk);
            load_we   = 1'b1;
            load_sel  = sel;
            load_row  = rr[IDX_W-1:0];
            load_col  = cc[IDX_W-1:0];
            load_data = value;
            @(negedge clk);
            load_we   = 1'b0;
        end
    endtask

    initial begin
        $dumpfile("build/legacy.vcd");
        $dumpvars(0, tb_edgegemm_top);

        clk         = 1'b0;
        rst_n       = 1'b0;
        load_we     = 1'b0;
        load_sel    = 1'b0;
        load_row    = '0;
        load_col    = '0;
        load_data   = '0;
        start       = 1'b0;
        result_row  = '0;
        result_col  = '0;
        quant_shift = 6'd0;
        relu_en     = 1'b0;
        errors      = 0;

        $readmemh("vectors/a.hex", a_vec);
        $readmemh("vectors/b.hex", b_vec);
        $readmemh("vectors/golden.hex", g_vec);

        repeat (4) @(posedge clk);
        @(negedge clk); rst_n = 1'b1;

        // Load A and B through the accelerator programming interface.
        for (r = 0; r < N; r = r + 1) begin
            for (c = 0; c < N; c = c + 1) begin
                idx = r*N + c;
                write_elem(1'b0, r, c, a_vec[idx]);
                write_elem(1'b1, r, c, b_vec[idx]);
            end
        end

        @(negedge clk);
        start = 1'b1;
        @(negedge clk);
        start = 1'b0;

        watchdog = 0;
        while (!done && watchdog < 100) begin
            @(negedge clk);
            watchdog = watchdog + 1;
        end

        if (!done) begin
            $fatal(1, "TIMEOUT: accelerator never asserted done");
        end

        // For N=4, a wavefront GEMM completes in 3N-2 = 10 compute cycles.
        if (perf_cycles !== ((3*N)-2)) begin
            $display("ERROR: perf_cycles=%0d expected=%0d", perf_cycles, (3*N)-2);
            errors = errors + 1;
        end

        for (r = 0; r < N; r = r + 1) begin
            for (c = 0; c < N; c = c + 1) begin
                idx = r*N + c;
                result_row = r[IDX_W-1:0];
                result_col = c[IDX_W-1:0];
                #1;

                if ($signed(result_acc) !== $signed(g_vec[idx])) begin
                    $display("ERROR C[%0d][%0d] got=%0d expected=%0d",
                             r, c, $signed(result_acc), $signed(g_vec[idx]));
                    errors = errors + 1;
                end else begin
                    $display("PASS  C[%0d][%0d] = %0d", r, c, $signed(result_acc));
                end
            end
        end

        // Small post-processing checks.
        result_row  = 0;
        result_col  = 0;
        quant_shift = 0;
        relu_en     = 0;
        #1;
        if ($signed(result_q8) !== 13) begin
            $display("ERROR requant expected 13 got %0d", $signed(result_q8));
            errors = errors + 1;
        end

        result_row = 2;
        result_col = 0;
        relu_en    = 1;
        #1;
        if ($signed(result_q8) !== 0) begin
            $display("ERROR ReLU expected 0 got %0d", $signed(result_q8));
            errors = errors + 1;
        end

        if (errors == 0) begin
            $display("\n========================================");
            $display(" EdgeGEMM RTL TEST: PASS");
            $display(" Matrix size : %0dx%0d", N, N);
            $display(" Compute cyc : %0d", perf_cycles);
            $display(" MACs        : %0d", N*N*N);
            $display("========================================\n");
            $finish;
        end else begin
            $fatal(1, "EdgeGEMM RTL TEST: FAIL (%0d errors)", errors);
        end
    end
endmodule
