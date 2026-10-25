#!/usr/bin/env python3
"""Package source/docs/evidence, excluding build products, and verify every byte."""
import argparse
import hashlib
from pathlib import Path
import zipfile

ROOT=Path(__file__).resolve().parents[1]
EXCLUDED={'build','.git','__pycache__','.venv'}


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--output',type=Path,default=ROOT.parent/'EdgeGEMM-Systolic-Array-main.zip')
    args=ap.parse_args()
    output=args.output.resolve()
    files=[p for p in sorted(ROOT.rglob('*')) if p.is_file() and not p.is_symlink()
           and not any(part in EXCLUDED for part in p.relative_to(ROOT).parts)
           and p.name!='MANIFEST.sha256' and p.resolve()!=output
           and p.suffix not in {'.pyc','.vvp','.vcd','.zip'}]
    modules=[Path(line).stem for line in (ROOT/'rtl/files.f').read_text().splitlines() if line.strip()]
    missing=[m for m in modules if not (ROOT/'tb'/f'tb_{m}.sv').exists()]
    if missing:raise RuntimeError(f'Missing dedicated benches: {missing}')
    manifest=''.join(f'{hashlib.sha256(p.read_bytes()).hexdigest()}  {p.relative_to(ROOT).as_posix()}\n' for p in files)
    (ROOT/'MANIFEST.sha256').write_text(manifest)
    files.append(ROOT/'MANIFEST.sha256')
    output.parent.mkdir(parents=True,exist_ok=True)
    with zipfile.ZipFile(output,'w',zipfile.ZIP_DEFLATED,compresslevel=9) as z:
        for p in files:
            info=zipfile.ZipInfo('EdgeGEMM/'+p.relative_to(ROOT).as_posix(),date_time=(2026,10,25,0,0,0))
            info.compress_type=zipfile.ZIP_DEFLATED
            info.external_attr=(0o100644 << 16)
            z.writestr(info,p.read_bytes())
    with zipfile.ZipFile(output) as z:
        if z.testzip() is not None:raise RuntimeError('ZIP CRC failure')
        for line in manifest.splitlines():
            digest,name=line.split('  ',1)
            if hashlib.sha256(z.read('EdgeGEMM/'+name)).hexdigest()!=digest:
                raise RuntimeError(f'ZIP byte mismatch: {name}')
    print(f'PASS: {len(files)} files; {len(modules)} RTL modules and dedicated benches; manifest verified')
    print(f'{output.name}: {output.stat().st_size:,} bytes')
    print(f'SHA256 {hashlib.sha256(output.read_bytes()).hexdigest()}')


if __name__=='__main__':main()
