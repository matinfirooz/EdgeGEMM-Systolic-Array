#!/usr/bin/env python3
"""Reproducible generic Yosys synthesis. Counts are not technology-mapped PPA."""
import argparse
import json
import os
from pathlib import Path
import shlex
import subprocess

ROOT=Path(__file__).resolve().parents[1]


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--n',type=int,default=4)
    ap.add_argument('--k-max',type=int,default=8)
    ap.add_argument('--bits',type=int,choices=(4,8),default=8)
    ap.add_argument('--zero-gate',type=int,choices=(0,1),default=1)
    args=ap.parse_args()
    if args.n<1 or args.k_max<1: ap.error('dimensions must be positive')
    yosys=shlex.split(os.environ.get('YOSYS','yosys'))
    build=ROOT/'build'; build.mkdir(exist_ok=True)
    name=f'core_N{args.n}_K{args.k_max}_W{args.bits}_G{args.zero_gate}'
    files=' '.join((ROOT/'rtl/files.f').read_text().splitlines())
    script=(f'read_verilog -sv -DSYNTHESIS {files}; '
            f'chparam -set N {args.n} -set K_MAX {args.k_max} -set DATA_W {args.bits} -set ZERO_GATE {args.zero_gate} edgegemm_core; '
            'synth -top edgegemm_core -noabc; check -assert; '
            f'tee -o build/{name}.stat.json stat -json; '
            f'write_verilog -noattr build/{name}.netlist.v')
    result=subprocess.run(yosys+['-Q','-T','-p',script],cwd=ROOT,text=True,capture_output=True)
    (build/f'{name}.log').write_text(result.stdout+result.stderr)
    if result.returncode:
        print((result.stdout+result.stderr)[-6000:]); return result.returncode
    stats=json.loads((build/f'{name}.stat.json').read_text())
    design=stats['design']
    print(f'{name}: {design["num_cells"]} generic cells; structural check passed')
    print('No liberty, timing, placement, routing, or activity-based power in this count.')
    return 0


if __name__=='__main__': raise SystemExit(main())
