#!/usr/bin/env python3
"""Generate an independent Python -> RTL rectangular integration fixture."""
import json
from pathlib import Path
import random
import sys

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from sw.model import gemm, requantize


def main():
    size,kmax,m,n,k=4,9,3,4,7
    rng=random.Random(8675309)
    a=[[rng.randrange(-128,128) if rng.randrange(4) else 0 for _ in range(k)] for _ in range(m)]
    b=[[rng.randrange(-128,128) if rng.randrange(3) else 0 for _ in range(n)] for _ in range(k)]
    a[0][0]=-128; b[0][0]=-128
    c=gemm(a,b)
    params=[dict(bias=col*11-999%37,multiplier=col%4+1,shift=(col+999)%6,
                 zero_point=col*3-7,relu=bool(col%2),rounding=bool((999+col)%2)) for col in range(n)]
    q=[[requantize(c[r][col],**params[col]) for col in range(n)] for r in range(m)]
    out=ROOT/'vectors'; out.mkdir(exist_ok=True)
    def write(name,values,bits):
        mask=(1<<bits)-1
        (out/name).write_text(''.join(f'{v&mask:0{bits//4}x}\n' for v in values))
    write('core_a.hex',[a[r][x] if r<m and x<k else 0 for r in range(size) for x in range(kmax)],8)
    write('core_b.hex',[b[x][col] if x<k else 0 for x in range(kmax) for col in range(size)],8)
    write('core_golden.hex',[c[r][col] if r<m else 0 for r in range(size) for col in range(size)],32)
    write('core_quant.hex',[q[r][col] if r<m else 0 for r in range(size) for col in range(size)],8)
    (out/'core_fixture.json').write_text(json.dumps(dict(rows=m,cols=n,depth=k,A=a,B=b,C=c,Q=q,quantization=params),indent=2)+'\n')
    print('Generated Python/RTL fixture: 3x7 @ 7x4, full INT8 range, raw + affine outputs')


if __name__=='__main__': main()
