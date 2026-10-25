# Hardware interface reference

All ports are synchronous to `clk` except active-low asynchronous reset `rst_n`. Drive input controls before rising edges; the testbenches drive on falling edges to avoid races. Deassert reset in accordance with the integrating system's reset strategy. There are no clock-domain crossings.

## Enhanced top: `edgegemm_core`

| Parameter | Default | Meaning |
|---|---:|---|
| `N` | 4 | Physical mesh rows and columns; positive integer |
| `K_MAX` | 16 | Operand depth per bank/lane; positive integer |
| `DATA_W` | 8 | Signed operand width; INT4/INT8 tested |
| `ACC_W` | 32 | Signed wrapping accumulator width; at least `2*DATA_W` |
| `OUT_W` | 8 | Signed quantized output width; `2..ACC_W` |
| `ZERO_GATE` | 1 | Nonzero enables zero-product isolation/accumulator hold |

Derived address widths are implementation parameters; normally leave them at their defaults:

| Width | Expression | Purpose |
|---|---|---|
| `IDX_W` | `max(1,clog2(N))` | A physical lane or result index |
| `DIM_W` | `max(1,clog2(N+1))` | A runtime row/column count, including N |
| `INDEX_W` | `max(1,clog2(K_MAX))` | A zero-based operand k address |
| `K_W` | `max(1,clog2(K_MAX+1))` | A runtime depth count, including K_MAX |

This distinction matters at powers of two: a 4-lane address takes 2 bits, but the count 4 takes 3 bits. N=1/K_MAX=1 retain one-bit ports.

### Global and status ports

| Port | Dir. | Width | Contract |
|---|---|---:|---|
| `clk` | in | 1 | Rising-edge clock |
| `rst_n` | in | 1 | Asynchronous reset; aborts work, invalidates operands, resets configurations/results/counters |
| `run_enable` | in | 1 | Freeze/advance all compute state; does not pause result draining |
| `busy` | out | 1 | Compute, capture or result drain active |
| `done` | out | 1 | One-cycle pulse after the final result handshake |

### Operand writes

| Port | Dir. | Width | Contract |
|---|---|---:|---|
| `load_valid` | in | 1 | Write request; keep payload until ready |
| `load_ready` | out | 1 | High if idle or this write targets the inactive bank |
| `load_bank` | in | 1 | Target bank 0/1 |
| `load_sel` | in | 1 | 0=A, 1=B |
| `load_lane` | in | IDX_W | A row or B column |
| `load_index` | in | INDEX_W | k coordinate |
| `load_data` | in | DATA_W, signed | Stored operand |
| `load_error` | out | 1 | Accepted invalid lane/index; write ignored |

On a handshake, `load_sel=0` writes `A[load_lane,load_index]`; `load_sel=1` writes `B[load_index,load_lane]`. Ready reflects bank ownership, not address legality. Error reporting consumes an invalid request while preventing the memory write. There is one shared scalar write port for A/B; the two buffers read N lanes in parallel during compute.

Reset invalidates all entries through initialized bits. Operand payload registers are not individually reset. Uninitialized reads return zero. There is no per-command memory clear; all written data persists until overwritten or reset.

### Per-column quantization configuration

| Port | Dir. | Width | Contract |
|---|---|---:|---|
| `qcfg_valid`, `qcfg_ready` | in/out | 1 each | Independent configuration handshake |
| `qcfg_bank` | in | 1 | Target bank |
| `qcfg_col` | in | IDX_W | Output column |
| `qcfg_bias` | in | ACC_W, signed | Bias added before scaling |
| `qcfg_multiplier` | in | 16, unsigned | Fixed-point scale numerator |
| `qcfg_shift` | in | 6 | Scale denominator exponent, 0..63 |
| `qcfg_zero_point` | in | OUT_W, signed | Output representation of real zero |
| `qcfg_relu` | in | 1 | Clamp scaled output at output zero point |
| `qcfg_round` | in | 1 | Nearest ties away from zero when 1; arithmetic floor when 0 |
| `qcfg_error` | out | 1 | Accepted invalid column; configuration write ignored |

Each handshake writes the full parameter tuple. The current bank is protected until its final output handshake. These are output-channel settings: they do not implement affine input zero-point subtraction.

### Tile commands

| Port | Dir. | Width | Contract |
|---|---|---:|---|
| `cmd_valid`, `cmd_ready` | in/out | 1 each | Native command handshake |
| `cmd_bank` | in | 1 | Bank to own for this command |
| `cmd_rows`, `cmd_cols` | in | DIM_W each | Counts in 1..N |
| `cmd_depth` | in | K_W | Count in 1..K_MAX |
| `cmd_error` | out | 1 | Accepted invalid dimension tuple; no job launched |

An accepted valid command latches shape and bank, clears the mesh/counters, and begins at active step zero. No subsequent live command-field changes affect that job. A command held valid until ready follows standard handshake semantics: if held through a later ready cycle, it can be accepted again. The producer must retire a transferred command.

Operand/config writes and a command may handshake on the same idle edge. Such writes are visible to the following compute edge. There is no command FIFO. During reset, keep host valid signals low; ready signals need not be low.

### Result stream

| Port | Dir. | Width | Contract |
|---|---|---:|---|
| `out_valid` | out | 1 | Payload valid |
| `out_ready` | in | 1 | Downstream can consume a payload |
| `out_row`, `out_col` | out | IDX_W each | Zero-based tile-local coordinates |
| `out_acc` | out | ACC_W, signed | Exact wrapping dot-product accumulator |
| `out_quant` | out | OUT_W, signed | Affine converted accumulator, current column's parameters |
| `out_last` | out | 1 | Final row/final column; only meaningful when valid |

Exactly `cmd_rows*cmd_cols` handshakes occur in row-major order. While valid and not ready, every payload field and valid itself remain stable. Values while invalid are unspecified to the consumer. `out_ready` does not stop the mesh; result capture decouples the phases. Completion refers to consuming results, so a consumer holding ready low indefinitely also holds the job busy indefinitely.

### Performance counters

| Port | Width | Definition |
|---|---:|---|
| `perf_compute_cycles` | 32 | Advancing compute edges; excludes clear, snapshot, load and drain |
| `perf_stall_cycles` | 32 | Busy compute edges with `run_enable=0` |
| `perf_valid_macs` | 32 | Valid operand-pair events, including zero products |
| `perf_zero_macs` | 32 | Valid zero-product events held by ZERO_GATE; zero if the option is disabled |

Counters reset on a valid accepted command and wrap modulo 2^32. They remain available after completion. Invalid commands do not clear them. For a valid tile without counter overflow, expected values are `K+M+N-2` active cycles and `M*N*K` valid MACs. The pause counter excludes downstream backpressure.

## Original top: `edgegemm_top`

Parameters `N`, `DATA_W`, `ACC_W` and `IDX_W` remain available. A and B are both N×N, and K=N.

| Port group | Meaning |
|---|---|
| `clk`, `rst_n` | Same clock/reset convention |
| `load_we`, `load_sel`, `load_row`, `load_col`, `load_data` | Conventional matrix row/column write; sel 0=A, 1=B; idle only |
| `start`, `busy`, `done` | Pulse start when idle; done follows final MAC; busy includes compute only |
| `perf_cycles` | Live active-cycle count; final value `3*N-2` |
| `result_row`, `result_col`, `result_acc` | Combinational accumulator selector; read completed results until next launch |
| `quant_shift`, `relu_en`, `result_q8` | Live legacy arithmetic shift, clamp negative to zero, signed INT8 saturation |

Idle writes to invalid encoded row/column addresses are ignored. Invalid result selectors return zero. Writes while busy are ignored. `start` is level sampled while idle; use a pulse to avoid unwanted relaunches. The legacy wrapper has no ready/error output and no result snapshot/stream.
