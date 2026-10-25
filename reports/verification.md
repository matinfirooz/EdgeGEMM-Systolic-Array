# Captured verification results

This package was checked locally with the supplied RTL, vectors, benches and models. The included CI workflow is ready to run after repository upload; no remote GitHub Actions run is claimed.

| Check | Captured result |
|---|---|
| Complete RTL regression | **53 / 53 simulations passed** |
| Dedicated module coverage | **16 / 16 modules have their own passing bench** |
| Counted CHECK executions | **83,614**; excludes the legacy top's original checks |
| Python model checks | **9 / 9 test methods passed**, including 200 randomized wavefront cases |
| C golden test | Original 16 outputs and quantization checks passed |
| Independent cross-language fixture | Raw and affine INT8 outputs matched Python for 3×7 @ 7×4 |
| Strict Verilator lint | Both public tops passed `-Wall` without suppression |
| Generic Yosys implementation | All four INT4/INT8 × ZERO_GATE settings passed synthesis and structural check |
| Host tiling example | 13×37 @ 37×11 INT4, 36 tile commands, matches full GEMM |

Tools used: Icarus Verilog 12.0, Verilator 5.020, Yosys 0.33, GCC and Python 3. The raw per-run parameters, tool strings, wall times and statuses are in [`verification.json`](verification.json), with logs under [`rtl_logs/`](rtl_logs/). The wall times are environment measurements, not accelerator latency.

[`test_run.log`](test_run.log) captures `make test`; [`lint.txt`](lint.txt) records the lint commands and successful status. [`rtl_sha256.json`](rtl_sha256.json) identifies the RTL bytes used for the release. Tests do not claim formal equivalence, code coverage closure or physical implementation signoff.

Reproduce from the repository root with `make test`, `make lint`, `make demo` and `make synth`. See [`docs/verification.md`](../docs/verification.md) for the scope and parameter matrix.
