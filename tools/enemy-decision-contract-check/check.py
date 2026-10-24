#!/usr/bin/env python3
"""Run unchanged decision consumers against both native engines."""
import argparse
import json
import os
from pathlib import Path
import subprocess

REFERENCE = "10613015fc68d924915570bd1abee34b70d5bd01"


def git(root, *args):
    return subprocess.check_output(["git", "-C", str(root), *args], text=True).strip()


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--gen1", type=Path, required=True)
    p.add_argument("--gen2", type=Path, default=Path(__file__).resolve().parents[2])
    p.add_argument("--lua", default=os.environ.get("LUA", "luajit"))
    p.add_argument("--host-api", type=int, choices=[2, 3], default=3)
    p.add_argument("--report", type=Path)
    a = p.parse_args()
    source, host = a.gen1.resolve(), a.gen2.resolve()
    if git(source, "rev-parse", "HEAD") != REFERENCE or git(source, "status", "--porcelain"):
        p.error("reference must be clean at " + REFERENCE)
    runs, differences = [], []
    for version in ["red", "gold", "silver", "crystal", "firered", "emerald"]:
        observations = []
        for backend, engine, api in [("gen1", source, 3), ("gen2", host, a.host_api)]:
            run = subprocess.run([a.lua, str(host / "tests/enemy_decision/worker.lua"), str(host), backend,
                                  version, str(api), "unified"], cwd=engine,
                                 capture_output=True, text=True, timeout=45)
            lines = [l.removeprefix("ENEMY_DECISION ") for l in run.stdout.splitlines() if l.startswith("ENEMY_DECISION ")]
            if run.returncode or len(lines) != 1:
                detail = "\n".join(x for x in run.stdout.splitlines() if not x.startswith("ENEMY_DECISION "))
                raise RuntimeError(f"{backend}/{version}: {detail[:3000]}{run.stderr[:3000]}")
            value = json.loads(lines[0]); observations.append(value)
            runs.append({"backend": backend, "version": version, "api": api, "observations": value})
        if len(observations[0]) != len(observations[1]):
            differences.append({"version": version, "error": "observation count"})
        for i, (left, right) in enumerate(zip(*observations)):
            if left != right:
                differences.append({"version": version, "row": i, "reference": left, "host": right})
        print(("PASS" if observations[0] == observations[1] else "FAIL"), version)
    assert not git(source, "status", "--porcelain"), "reference changed"
    report = {"reference_ref": REFERENCE, "host_ref": git(host, "rev-parse", "HEAD"),
              "host_dirty": bool(git(host, "status", "--porcelain")), "host_api": a.host_api,
              "runs": runs, "differences": differences}
    if a.report:
        a.report.write_text(json.dumps(report, indent=2) + "\n")
    if differences:
        for d in differences:
            print(json.dumps(d, sort_keys=True))
        raise SystemExit(1)


if __name__ == "__main__":
    main()
