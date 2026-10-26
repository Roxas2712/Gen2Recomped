#!/usr/bin/env python3
"""Import an owned Red cartridge and run the full generated-data suite."""
# Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import shutil
import sys
import tarfile
import time

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from qa_storage import qa_source, qa_cache, qa_copy, qa_profile, qa_run
from check_full_game_performance import BOOTSTRAP


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('love', 'lua', 'red', 'out'):
        parser.add_argument('--' + name, type=Path, required=True)
    parser.add_argument('--suite', action='append', default=[], help='run selected legacy suites in isolated states')
    args = parser.parse_args()
    for suite in args.suite:
        assert suite.startswith('tests/') and (ROOT / suite).resolve().is_relative_to(ROOT / 'tests')
        assert (ROOT / suite).is_file()
    love, lua, rom = (p.resolve(strict=True) for p in (args.love, args.lua, args.red))
    for path in (ROOT, love, lua, rom):
        qa_source(path)
    out = args.out.resolve()
    qa_cache(out)
    source = out / 'source'
    qa_copy(source)
    out.mkdir(parents=True, exist_ok=False)
    source.mkdir()
    head = qa_run(['git', 'rev-parse', 'HEAD'], cwd=ROOT, capture_output=True, text=True, check=True).stdout.strip()
    assert not qa_run(['git', 'status', '--porcelain', '--untracked-files=normal'], cwd=ROOT,
                      capture_output=True, text=True, check=True).stdout.strip(), 'Commit the candidate first'
    digest = hashlib.sha1(rom.read_bytes()).hexdigest()
    admission = 'assert(require("src.core.GameVersion").acceptsSha1("red",' + json.dumps(digest) + '))'
    qa_run([str(lua), '-e', admission], cwd=ROOT, capture_output=True, text=True, check=True)
    # Source-inspection suites read scripts, mobile manifests, docs and shipped
    # mods as well as runtime code. Freeze the complete committed repository.
    archive = qa_run(['git', 'archive', head], cwd=ROOT, capture_output=True, check=True).stdout
    with tarfile.open(fileobj=io.BytesIO(archive)) as tar:
        for member in tar.getmembers():
            assert not member.name.startswith('/') and '..' not in Path(member.name).parts
            assert not member.issym() and not member.islnk()
        tar.extractall(source)
    (source / 'main.lua').rename(source / 'engine_main.lua')
    (source / 'main.lua').write_text(BOOTSTRAP)
    identity = 'oasc-gen2recomp-qa-perf-red-suite-' + str(time.time_ns())
    profile = Path.home() / 'Library/Application Support/LOVE' / identity
    qa_profile(profile)
    env = {k: v for k, v in os.environ.items() if not k.startswith(('POKEPORT_', 'PERF_', 'PALETTE_'))}
    env.update(POKEPORT_IDENTITY=identity, POKEPORT_VERSION='red', POKEPORT_IMPORT_ROM=str(rom),
               POKEPORT_IMPORT_ONLY='1', POKEPORT_NO_MODS='1', POKEPORT_NO_BOOT_REPORT='1',
               POKEPORT_NO_DISCORD='1', POKEPORT_NOTIFY_ONLY_UPDATES='1')
    with (out / 'import.log').open('w') as log:
        qa_run([str(love), str(source)], cwd=source, env=env, stdout=log, stderr=log,
               timeout=600, check=True)
    assert (profile / 'rom-cache.complete').is_file(), 'fresh Red import is incomplete'
    for tree in ('data/generated', 'assets/generated'):
        shutil.copytree(profile / tree, source / tree, dirs_exist_ok=True)
    env = {k: v for k, v in env.items() if not k.startswith('POKEPORT_')}
    codes = []
    with (out / 'suite.log').open('w') as log:
        for suite in args.suite or [None]:
            command = [str(lua), 'tests/run_isolated_suite.lua', suite] if suite else [str(lua), 'tests/run_tests.lua']
            log.write('RUN ' + str(suite or 'tests/run_tests.lua') + '\n');log.flush()
            result = qa_run(command, cwd=source, env=env, stdout=log, stderr=log, timeout=1800)
            codes.append(result.returncode)
    code = next((c for c in codes if c),0)
    log = (out / 'suite.log').read_text()
    stable = qa_run(['git', 'rev-parse', 'HEAD'], cwd=ROOT, capture_output=True,
                    text=True, check=True).stdout.strip() == head
    report = dict(passed=code == 0 and stable, sourceCommit=head, sourceStable=stable,
                  romSha1=digest, freshImport=True, playerProfilesUsed=False,
                  suiteExit=code, suites=args.suite or ['tests/run_tests.lua'], suiteLogSha256=hashlib.sha256(log.encode()).hexdigest(),
                  importLogSha256=hashlib.sha256((out / 'import.log').read_bytes()).hexdigest(),
                  verdict=log.strip().splitlines()[-1] if log.strip() else 'missing output')
    (out / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report), flush=True)
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    sys.exit(main())
