#!/usr/bin/env python3
"""Dependency-free, integer-exact EdgeGEMM model and host tiling example."""
from __future__ import annotations

import argparse
from dataclasses import asdict, dataclass
import json
from pathlib import Path
import random


def wrap_signed(value: int, bits: int = 32) -> int:
    if bits < 2:
        raise ValueError("bits must be at least 2")
    return (int(value) + (1 << (bits - 1))) % (1 << bits) - (1 << (bits - 1))


def requantize(acc: int, *, bias: int = 0, multiplier: int = 1, shift: int = 0,
               zero_point: int = 0, relu: bool = False, rounding: bool = False,
               out_bits: int = 8, acc_bits: int = 32) -> int:
    """Widen bias/scale arithmetic, round ties away from zero or floor, then clip."""
    if not 0 <= multiplier <= 65535 or not 0 <= shift <= 63:
        raise ValueError("multiplier must fit uint16; shift must fit uint6")
    if not 2 <= out_bits <= acc_bits:
        raise ValueError("2 <= out_bits <= acc_bits required")
    low, high = -(1 << (out_bits - 1)), (1 << (out_bits - 1)) - 1
    if not low <= zero_point <= high:
        raise ValueError("zero_point must fit the output width")
    for v in (acc, bias):
        if not -(1 << (acc_bits - 1)) <= v < (1 << (acc_bits - 1)):
            raise ValueError("acc and bias must fit the accumulator width")
    p = (acc + bias) * multiplier
    if rounding and shift:
        magnitude = (abs(p) + (1 << (shift - 1))) >> shift
        v = -magnitude if p < 0 else magnitude
    else:
        v = p >> shift
    v += zero_point
    if relu:
        v = max(zero_point, v)
    return min(high, max(low, v))


def _shape(a: list[list[int]], b: list[list[int]]) -> tuple[int, int, int]:
    if not a or not b or not a[0] or not b[0]:
        raise ValueError("matrices must be nonempty")
    m, k, n = len(a), len(a[0]), len(b[0])
    if any(len(row) != k for row in a) or len(b) != k or any(len(row) != n for row in b):
        raise ValueError("incompatible or ragged matrices")
    return m, k, n


def gemm(a: list[list[int]], b: list[list[int]], acc_bits: int = 32) -> list[list[int]]:
    m, k, n = _shape(a, b)
    return [[wrap_signed(sum(a[r][x] * b[x][c] for x in range(k)), acc_bits)
             for c in range(n)] for r in range(m)]


@dataclass(frozen=True)
class Tile:
    row: int
    col: int
    k_offset: int
    rows: int
    cols: int
    depth: int
    bank: int

    @property
    def compute_cycles(self) -> int:
        return self.depth + self.rows + self.cols - 2

    @property
    def scalar_loads(self) -> int:
        return (self.rows + self.cols) * self.depth

    @property
    def result_beats(self) -> int:
        return self.rows * self.cols


def plan_tiles(m: int, k: int, n: int, array: int = 4, k_max: int = 16) -> list[Tile]:
    if min(m, k, n, array, k_max) < 1:
        raise ValueError("all dimensions must be positive")
    tiles = []
    for r in range(0, m, array):
        for c in range(0, n, array):
            for x in range(0, k, k_max):
                tiles.append(Tile(r, c, x, min(array, m-r), min(array, n-c),
                                  min(k_max, k-x), len(tiles) % 2))
    return tiles


def tiled_gemm(a: list[list[int]], b: list[list[int]], array: int = 4,
               k_max: int = 16, acc_bits: int = 32) -> tuple[list[list[int]], list[Tile]]:
    """Host combines raw C tiles across K. Requantization follows the final sum."""
    m, k, n = _shape(a, b)
    tiles = plan_tiles(m, k, n, array, k_max)
    result = [[0] * n for _ in range(m)]
    for t in tiles:
        ta = [row[t.k_offset:t.k_offset+t.depth] for row in a[t.row:t.row+t.rows]]
        tb = [row[t.col:t.col+t.cols] for row in b[t.k_offset:t.k_offset+t.depth]]
        tc = gemm(ta, tb, acc_bits)
        for r in range(t.rows):
            for c in range(t.cols):
                result[t.row+r][t.col+c] = wrap_signed(result[t.row+r][t.col+c] + tc[r][c], acc_bits)
    return result, tiles


def wavefront(a: list[list[int]], b: list[list[int]], array: int = 4,
              acc_bits: int = 32, pauses: set[int] | None = None) -> dict:
    """Cycle model with registered A/B hops, valid bits, and global pause."""
    m, k, n = _shape(a, b)
    if max(m, n) > array or array < 1:
        raise ValueError("this function models one physical tile")
    pauses = pauses or set()
    ah = [[0]*array for _ in range(array)]
    bh = [[0]*array for _ in range(array)]
    av = [[False]*array for _ in range(array)]
    bv = [[False]*array for _ in range(array)]
    acc = [[0]*array for _ in range(array)]
    step = wall = macs = zeros = stalls = 0
    limit = k + m + n - 2
    history = []
    while step < limit:
        if wall in pauses:
            stalls += 1
            history.append({"wall": wall, "step": step, "paused": True, "macs": 0})
            wall += 1
            continue
        na = [[0]*array for _ in range(array)]
        nb = [[0]*array for _ in range(array)]
        va = [[False]*array for _ in range(array)]
        vb = [[False]*array for _ in range(array)]
        active = 0
        for r in range(array):
            for c in range(array):
                if c:
                    aa, aa_valid = ah[r][c-1], av[r][c-1]
                else:
                    x = step-r
                    aa_valid = r < m and 0 <= x < k
                    aa = a[r][x] if aa_valid else 0
                if r:
                    bb, bb_valid = bh[r-1][c], bv[r-1][c]
                else:
                    x = step-c
                    bb_valid = c < n and 0 <= x < k
                    bb = b[x][c] if bb_valid else 0
                na[r][c], nb[r][c] = aa if aa_valid else 0, bb if bb_valid else 0
                va[r][c], vb[r][c] = aa_valid, bb_valid
                if aa_valid and bb_valid:
                    acc[r][c] = wrap_signed(acc[r][c] + aa*bb, acc_bits)
                    active += 1
                    zeros += int(aa == 0 or bb == 0)
        ah, bh, av, bv = na, nb, va, vb
        history.append({"wall": wall, "step": step, "paused": False, "macs": active})
        macs += active
        step += 1
        wall += 1
    return {"result": [row[:n] for row in acc[:m]], "compute_cycles": step,
            "wall_cycles": wall, "stall_cycles": stalls, "valid_macs": macs,
            "zero_macs": zeros, "history": history}


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--m", type=int, default=13)
    p.add_argument("--k", type=int, default=37)
    p.add_argument("--n", type=int, default=11)
    p.add_argument("--array", type=int, default=4)
    p.add_argument("--k-max", type=int, default=16)
    p.add_argument("--bits", type=int, choices=(4, 8), default=8)
    p.add_argument("--seed", type=int, default=42)
    p.add_argument("--output", type=Path)
    args = p.parse_args()
    plan_tiles(args.m, args.k, args.n, args.array, args.k_max)
    rng = random.Random(args.seed)
    lo, hi = -(1 << (args.bits-1)), (1 << (args.bits-1))-1
    a = [[rng.randint(lo, hi) for _ in range(args.k)] for _ in range(args.m)]
    b = [[rng.randint(lo, hi) for _ in range(args.n)] for _ in range(args.k)]
    c, tiles = tiled_gemm(a, b, args.array, args.k_max)
    if c != gemm(a, b):
        raise AssertionError("host K-split accumulation mismatch")
    report = {"shape": [args.m, args.k, args.n], "array": args.array,
              "bits": args.bits, "tile_commands": len(tiles),
              "scalar_operand_writes": sum(t.scalar_loads for t in tiles),
              "active_compute_cycles": sum(t.compute_cycles for t in tiles),
              "raw_result_beats": sum(t.result_beats for t in tiles),
              "passed": True, "tiles": [asdict(t) for t in tiles], "result": c}
    print(f"PASS {args.m}x{args.k} @ {args.k}x{args.n}; INT{args.bits}; {len(tiles)} tile commands")
    print(f"Active wavefront cycles (sum): {report['active_compute_cycles']}")
    print("K chunks are combined by the host before final requantization.")
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, indent=2) + "\n")


if __name__ == "__main__":
    main()
