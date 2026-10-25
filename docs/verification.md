# Verification plan and reproducibility

## Complete commands

```bash
make test
make lint
make synth
make demo
make wave
```

The regression runner executes a dedicated self-checking bench for every synthesizable module in `rtl/files.f`. It then sweeps additional parameter combinations. Failures exit nonzero; a simulator missing from PATH is a failure. Each run has a simulator watchdog and a subprocess timeout. Testbenches drive synchronous inputs on falling edges and check results after nonblocking updates.

## Layers of evidence

| Layer | Checks |
|---|---|
| Arithmetic leaves | Signed multiply/extrema, enable/valid/clear priority, zero event qualification, wraparound |
| Operand movement | Independent valid propagation, held hops during pause, partial physical rows/columns |
| Storage | Parallel lane reads, two-bank isolation, reset invalidation, read masks, invalid addresses |
| Controller | Exhaustive small legal shapes, invalid shapes/depths, pause, clear and completion pulse |
| Output | Snapshot retention, row-major order, last flag, shape latching, stalled payload stability |
| Quantization | Negative floor, positive/negative half-way rounding, extreme bias/scale, shifts 0..63, saturation, zero point and ReLU |
| Core | Randomized signed tiles, alternate banks, overlap, ownership, counters, reset during compute and stalled drain |
| Independent cross-language | Python-generated 3×7 by 7×4 fixture compared at raw and quantized hardware outputs |
| Legacy integration | Original fixed 4×4 hex vectors plus repeat square-tile tests |
| Python | Separate dot-product, registered-wavefront and host K-split/tail-tiling checks |
| C | Original signed known-answer matrix and legacy quantizer checks |
| Static checks | Strict Verilator lint of both public tops; generic Yosys synthesis and structural check |

## Parameter regression

The 53 runs contain 16 default unit runs, four INT4 MAC runs (ACC_W 8/32 and gate 0/1), one extra INT4 compatibility PE run, twelve additional mesh/legacy-array runs (N 1/2/4 and DATA_W 4/8), and twenty enhanced-core runs:

| N | K_MAX | DATA_W | ZERO_GATE |
|---:|---:|---|---|
| 1 | 1 | 4, 8 | 0, 1 |
| 2 | 5 | 4, 8 | 0, 1 |
| 3 | 7 | 4, 8 | 0, 1 |
| 4 | 9 | 4, 8 | 0, 1 |
| 8 | 11 | 4, 8 | 0, 1 |

Each enhanced run includes at least 22 completed jobs, plus aborted/invalid requests. The external Python fixture adds a completed job to matching N=4/K_MAX=9/INT8 runs. The mesh/default legacy bench also exercises non-power-of-two N=3.

`build/verification.json` stores the full regression status, versions, per-run parameters and counted assertions. `--unit` and `--module` use different report filenames so they do not overwrite the full report. These counts are assertion executions, not branch/code coverage or exhaustive proof.

## Software vectors

The retained C generator emits the legacy A/B/C hex files. `tools/generate_vectors.py` imports the Python integer model and emits `core_a.hex`, `core_b.hex`, `core_golden.hex`, `core_quant.hex` and a readable JSON fixture. The core bench programs those values through the same load/config interface used by all jobs. It does not directly modify internal DUT memories.

The Python and SV references use independent accumulation and quantization implementations. Randomized SV checks use reproducible LCG sequences, including structured zero operands. An actual workload's sparsity/energy behavior is not inferred from this synthetic test distribution.

## Waveforms

`make wave` records the default enhanced-core bench. `tools/draw_figures.py --waveform build/core.vcd --png` renders a marked, real 4×4/K=9 job from that trace. The compressed trace in `docs/waveforms/` matches this default run; it is not a drawn timing sketch. The separate schedule figure is a derived explanatory diagram.

## Limits

Simulation checks deterministic and seeded corner/random cases, not all possible input histories. There is no formal equivalence result, gate-level simulation, CDC signoff or physical PPA signoff. GitHub Actions is included for future runs; local captured evidence is in `reports/`. Generic synthesis uses no technology cell library and cannot establish routed area/frequency/power.
