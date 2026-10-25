#!/usr/bin/env python3
"""Run every RTL unit bench plus a reproducible parameter regression."""
import argparse
import datetime as dt
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
MODULES = [Path(p).stem for p in (ROOT / "rtl/files.f").read_text().splitlines() if p.strip()]


def regression():
    cases = [(m, {}) for m in MODULES]
    cases += [("signed_mac", {"DATA_W": 4, "ACC_W": w, "ZERO_GATE": g})
              for w in (8, 32) for g in (0, 1)]
    cases += [("pe", {"DATA_W": 4})]
    for name in ("systolic_mesh", "systolic_array"):
        cases += [(name, {"N": n, "DATA_W": w}) for n in (1, 2, 4) for w in (4, 8)]
    cases += [("edgegemm_core", {"N": n, "K_MAX": k, "DATA_W": w, "ZERO_GATE": g})
              for n, k in ((1, 1), (2, 5), (3, 7), (4, 9), (8, 11))
              for w in (4, 8) for g in (0, 1)]
    return cases


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--unit", action="store_true", help="only one run per module")
    ap.add_argument("--module", choices=MODULES)
    ap.add_argument("--vcd", action="store_true")
    args = ap.parse_args()
    cases = [(args.module, {})] if args.module else ([(m, {}) for m in MODULES] if args.unit else regression())
    build = ROOT / "build"
    build.mkdir(exist_ok=True)
    logs = build / "logs"
    logs.mkdir(exist_ok=True)
    iverilog = shlex.split(os.environ.get("IVERILOG", "iverilog"))
    vvp = shlex.split(os.environ.get("VVP", "vvp"))
    results = []
    versions = {}
    for key, cmd in (("iverilog", iverilog + ["-V"]), ("vvp", vvp + ["-V"])):
        r = subprocess.run(cmd, cwd=ROOT, text=True, capture_output=True, check=False)
        versions[key] = (r.stdout + r.stderr).splitlines()[0]
    for index, (module, params) in enumerate(cases):
        label = module + "".join(f"_{k}{v}" for k, v in params.items())
        bench = f"tb_{module}"
        output = build / f"{label}.vvp"
        cmd = iverilog + ["-g2012", "-Wall", "-Itb", "-s", bench, "-o", str(output), "-f", "rtl/files.f", f"tb/{bench}.sv"]
        cmd += [f"-P{bench}.{k}={v}" for k, v in params.items()]
        start = time.monotonic()
        text = "$ " + shlex.join(cmd) + "\n"
        passed = False
        try:
            r = subprocess.run(cmd, cwd=ROOT, text=True, capture_output=True, timeout=90)
            text += r.stdout + r.stderr
            if r.returncode == 0:
                r = subprocess.run(vvp + [str(output)] + (["+vcd"] if args.vcd else []), cwd=ROOT,
                                   text=True, capture_output=True, timeout=90)
                text += r.stdout + r.stderr
                passed = r.returncode == 0 and "PASS" in r.stdout
        except subprocess.TimeoutExpired:
            text += "TIMEOUT\n"
        (logs / f"{label}.log").write_text(text)
        results.append({"module": module, "parameters": params, "passed": passed,
                        "seconds": round(time.monotonic() - start, 3),
                        "checks": sum(map(int, re.findall(r"checks=(\d+)", text))),
                        "summary": next((line for line in text.splitlines() if line.startswith("PASS tb_")), ""),
                        "log": f"build/logs/{label}.log"})
        print(f"[{index+1}/{len(cases)}] {'PASS' if passed else 'FAIL'} {label}", flush=True)
        if not passed:
            print(text[-10000:], file=sys.stderr)
    report = {"utc": dt.datetime.now(dt.timezone.utc).isoformat(), "tools": versions,
              "runs": len(results), "passed": sum(r["passed"] for r in results),
              "modules": len(set(r["module"] for r in results)),
              "assertion_checks": sum(r["checks"] for r in results), "results": results}
    path = build / (f"verification_{args.module}.json" if args.module else ("verification_unit.json" if args.unit else "verification.json"))
    path.write_text(json.dumps(report, indent=2) + "\n")
    print(f"{report['passed']}/{report['runs']} RTL simulations passed; {report['modules']} modules; {report['assertion_checks']} counted checks")
    return 0 if all(r["passed"] for r in results) else 1


if __name__ == "__main__":
    raise SystemExit(main())
