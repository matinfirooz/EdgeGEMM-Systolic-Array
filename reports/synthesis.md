# Generic synthesis results

These results are from Yosys 0.33 using the supplied `tools/synthesize.py`: `read_verilog -sv -DSYNTHESIS`, parameter changes, `synth -top edgegemm_core -noabc`, and `check -assert`. All cases use the **complete enhanced core**, physical N=4, K_MAX=8, ACC_W=32 and OUT_W=8. Operand/result/configuration storage and performance counters are included.

| Input width | ZERO_GATE | Generic cells | Wire bits | Structural check |
|---:|---:|---:|---:|---|
| 4 | 0 | 26,313 | 54,858 | PASS |
| 4 | 1 | 26,505 | 55,018 | PASS |
| 8 | 0 | 33,868 | 71,813 | PASS |
| 8 | 1 | 34,193 | 72,106 | PASS |

The zero-hold option adds 192 generic cells in the INT4 case and 325 in INT8, about 0.73% and 0.96% respectively. Those counts expose its logic overhead. They do not establish whether workload switching suppression outweighs that overhead in energy, timing or physical area.

The counts are Yosys generic bit-level logic/register counts before ABC and without a cell library. Wire bits include internal/intermediate signals. There is no liberty mapping, floorplan, placement, clock tree, routing, parasitic extraction or activity-based power analysis. A generic cell is not a standard-cell area unit. No MHz, mm², mW or pJ result should be inferred from this table.

Per-case `.stat.json` files include the complete cell-type breakdown. Corresponding logs are in `synthesis_logs/`; synthesis netlists can be regenerated rather than committed. Asynchronous operand reads are implemented as register/multiplexer structures in this reference architecture.

Reproduce:

```bash
python3 tools/synthesize.py --n 4 --k-max 8 --bits 4 --zero-gate 0
python3 tools/synthesize.py --n 4 --k-max 8 --bits 4 --zero-gate 1
python3 tools/synthesize.py --n 4 --k-max 8 --bits 8 --zero-gate 0
python3 tools/synthesize.py --n 4 --k-max 8 --bits 8 --zero-gate 1
```
