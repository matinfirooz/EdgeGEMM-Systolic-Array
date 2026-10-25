# Migrating from the original package

The original four public module names remain: `pe`, `systolic_array`, `requantize`, `edgegemm_top`. Compile all required dependencies from `rtl/files.f` instead of the old four-file source list. Existing named-port connections to those modules remain valid.

| Original behavior | Updated behavior |
|---|---|
| Square N×N GEMM at `edgegemm_top` | Same shape, ports and final `3*N-2` compute count |
| PE multiply/forward/local accumulator | Same behavior, factored through `signed_mac` |
| Matrices cleared on reset | Initialized flags guarantee zero reads after reset |
| Undefined invalid selectors | Invalid writes ignored; invalid result read returns zero |
| Cycle count set at end | Count updates live and has the same final value |
| One integration test | Original example retained plus dedicated benches/regression |
| `make all` builds only C/vector helpers | `make all` runs the complete test suite |
| `make sim` runs one test | Runs complete RTL regression; `make test-unit` is the smaller set |
| Root VCD | `make wave` produces `build/core.vcd`; legacy test produces `build/legacy.vcd` |

To use extended features, instantiate `edgegemm_core`. Its dimensions are counts, its B load lane denotes a column, and its done indicates result consumption. It is an explicit alternative interface; it does not silently change the meaning of the old wrapper's done.

The new root-level architecture/PE PNGs live under `docs/figures/` with editable SVG sources and a deterministic generation script. The original license is retained. The old raster figures were replaced with drawings of the implemented design.
