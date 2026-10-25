#!/usr/bin/env python3
"""Run an unchanged decoded-layout consumer on the old and native hosts."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

PIN = '37a49b31f458d51ea9e00b90f2a247272ad09cb8'


def run(command, cwd):
    return subprocess.check_output(command, cwd=cwd, text=True)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--gen1', type=Path, required=True)
    p.add_argument('--gen2', type=Path, default=Path(__file__).resolve().parents[2])
    p.add_argument('--lua', default='luajit')
    p.add_argument('--report', type=Path)
    a = p.parse_args()
    gen1, gen2 = a.gen1.resolve(), a.gen2.resolve()
    git = lambda *args: run(['git', *args], gen1).strip()
    if git('rev-parse', 'HEAD') != PIN or git('status', '--porcelain'):
        p.error('Gen1 must be clean at ' + PIN)
    folder = gen2 / 'tools/gen1-layout-compat'
    command = [a.lua, str(folder / 'worker.lua'), str(gen2)]
    original, native = run(command, gen1), run(command, gen2)
    if original != native:
        raise RuntimeError('decoded-layout consumer differs between engines')
    checks = int(native.splitlines()[0])
    assert checks >= 245
    if git('status', '--porcelain'):
        raise RuntimeError('reference changed during check')
    paths = [gen2 / 'src/core/game3/layout_native.lua',
             gen2 / 'tests/engine/gen1_layout_native.lua', gen2 / 'tests/gba_layout/consumer.lua',
             folder / 'worker.lua', folder / 'check.py']
    report = dict(gen1Commit=PIN, checksPerHost=checks,
                  consumerSha256=hashlib.sha256(native.encode()).hexdigest(),
                  sourceSha256={str(path.relative_to(gen2)): hashlib.sha256(path.read_bytes()).hexdigest()
                                for path in paths},
                  nativeGridBridged=False, collisionOrSaveChanges=False,
                  playerProfilesUsed=False, originalOrigamiLoads=False, fullLegacyMapContract=False)
    if a.report:
        a.report.parent.mkdir(parents=True, exist_ok=True)
        a.report.write_text(json.dumps(report, indent=2) + '\n')
    print('PASS', checks, 'unchanged decoded-layout checks per engine')


if __name__ == '__main__':
    main()
