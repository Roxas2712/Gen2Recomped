#!/usr/bin/env python3
"""Compare every native Twinleaf shape against a pinned earlier renderer."""
import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import tarfile
import time
from qa_storage import qa_source, qa_cache, qa_copy, qa_profile, qa_run
from check_full_game_performance import BOOTSTRAP

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--love', type=Path, required=True)
    parser.add_argument('--platinum', type=Path, required=True)
    parser.add_argument('--reference', required=True, help='Pinned pre-extraction Git commit')
    parser.add_argument('--backend', choices=('metal', 'opengl'), default='metal')
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    binary, rom = args.love.resolve(strict=True), args.platinum.resolve(strict=True)
    for path in (ROOT, binary, rom):
        qa_source(path)
    out = qa_cache(args.out.resolve())
    out.mkdir(parents=True, exist_ok=False)
    def git(*argv):
        return qa_run(['git', *argv], cwd=ROOT, capture_output=True, check=True).stdout
    head = git('rev-parse', 'HEAD').decode().strip()
    reference = git('rev-parse', '--verify', args.reference + '^{commit}').decode().strip()
    assert not git('status', '--porcelain').strip(), 'Commit the candidate first'
    old = git('show', reference + ':src/render/Gen4Model.lua')
    assert b'Gen4Model.unpack' not in old, 'Reference must precede the extraction'
    source = qa_copy(out / 'source', ephemeral=True)
    source.mkdir()
    with tarfile.open(fileobj=io.BytesIO(git('archive', head))) as archive:
        for member in archive.getmembers():
            assert not member.name.startswith('/') and '..' not in Path(member.name).parts
            assert not member.issym() and not member.islnk()
        archive.extractall(source)
    (source / 'reference_gen4_model.lua').write_bytes(old)
    (source / 'main.lua').rename(source / 'engine_main.lua')
    (source / 'main.lua').write_text(BOOTSTRAP)
    identity = 'oasc-gen2recomp-qa-perf-unpack-' + str(time.time_ns())
    qa_profile(Path.home() / 'Library/Application Support/LOVE' / identity)
    env = {k: v for k, v in os.environ.items()
           if not k.startswith(('POKEPORT_', 'PERF_', 'GEN4_UNPACK_'))}
    env.update(POKEPORT_IDENTITY=identity, POKEPORT_VERSION='platinum', POKEPORT_NO_MODS='1',
               POKEPORT_NO_DISCORD='1', POKEPORT_NO_BOOT_REPORT='1', POKEPORT_NOTIFY_ONLY_UPDATES='1',
               POKEPORT_GRAPHICS_BACKEND=args.backend, POKEPORT_IMPORT_ROM=str(rom),
               POKEPORT_IMPORT_ONLY='1')
    with (out / 'import.log').open('w') as log:
        qa_run([str(binary), str(source)], cwd=source, env=env,
               stdout=log, stderr=log, timeout=600, check=True)
    env.pop('POKEPORT_IMPORT_ROM'); env.pop('POKEPORT_IMPORT_ONLY')
    env.update(POKEPORT_DRIVER=str(source / 'tools/gen4_unpack_driver.lua'),
               GEN4_UNPACK_REFERENCE=str(source / 'reference_gen4_model.lua'),
               GEN4_UNPACK_OUT=str(out / 'native.json'))
    with (out / 'compare.log').open('w') as log:
        result = qa_run([str(binary), str(source)], cwd=source, env=env,
                        stdout=log, stderr=log, timeout=300)
    data = json.loads((out / 'native.json').read_text()) if (out / 'native.json').exists() else {}
    stable = head == git('rev-parse', 'HEAD').decode().strip() and not git('status', '--porcelain').strip()
    report = dict(passed=result.returncode == 0 and data.get('passed', False) and stable,
                  candidateCommit=head, referenceCommit=reference, sourceStable=stable,
                  referenceRendererSha256=hashlib.sha256(old).hexdigest(),
                  romSha1=hashlib.sha1(rom.read_bytes()).hexdigest(),
                  native=data, playerProfilesUsed=False)
    (out / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print('Native Twinleaf unpack:', 'PASS' if report['passed'] else 'FAIL', flush=True)
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
