#!/usr/bin/env python3
"""Qualify cooperative installation using real ZIPs and a new owned LOVE profile."""
# Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
import argparse
import atexit
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import subprocess
import sys
import time
import uuid
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--love', required=True, type=Path)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    executable = args.love.resolve(strict=True)
    output = (args.output or ROOT / '.local/qa' / ('mod-installer-' + str(time.time_ns()))).resolve()
    identity = 'oasc-mod-installer-qa-' + uuid.uuid4().hex
    host = ROOT / '.local/engine-parity' / identity
    if os.getenv('GITHUB_ACTIONS'):
        host = output / 'host'
    run = subprocess.run
    if not os.getenv('GITHUB_ACTIONS'):
        sys.path.insert(0, str(Path.home() / '.local/lib/origami-qa-storage/active-tools'))
        import qa_storage as qa
        qa._storage = qa.Storage(ROOT)
        atexit.register(qa._storage.close)
        for source in (ROOT, executable, Path(sys.executable), Path(__file__)):
            qa.qa_source(source)
        qa.qa_cache(output)
        qa.qa_copy(host, ephemeral=True)
        if sys.platform == 'darwin':
            profile = Path.home() / 'Library/Application Support/LOVE' / identity
        elif os.name == 'nt':
            profile = Path(os.environ['APPDATA']) / 'LOVE' / identity
        else:
            profile = Path(os.getenv('XDG_DATA_HOME', Path.home() / '.local/share')) / 'love' / identity
        qa.qa_source(profile)
        qa.qa_profile(profile)
        run = qa.qa_run
    output.mkdir(parents=True, exist_ok=False)
    host.mkdir(parents=True, exist_ok=False)
    for name in ('conf.lua', 'main.lua'):
        (host / name).write_bytes((ROOT / 'tests/mod_install_runtime' / name).read_bytes())
    entry = 'local mod=...;mod.exports.native=true\n'
    config = {'entry': entry}
    for name in ('v1', 'v2', 'wrong_game', 'wrong_api', 'custom'):
        manifest = dict(id='customprobe' if name == 'custom' else 'nativeprobe', name='Owned native Gen2 fixture', api=2,
                        version='1.0.0' if name == 'v1' else '2.0.0', entry='main.lua',
                        games=['red'] if name == 'wrong_game' else ['crystal'])
        if name == 'wrong_api':
            manifest['api'] = 99
        path = output / ('Pokémon-日本語-' + name + '.zip')
        with zipfile.ZipFile(path, 'w', zipfile.ZIP_DEFLATED) as archive:
            archive.writestr('release/manifest.json', json.dumps(manifest))
            archive.writestr('release/main.lua', entry)
            archive.writestr('release/assets/chunks.bin', bytes(range(256)) * 8192)
        config[name] = str(path)
    corrupt = output / 'corrupt.zip'
    corrupt.write_bytes(b'PK\x03\x04truncated archive')
    config['corrupt'] = str(corrupt)
    folder = output / 'folder-input'
    (folder / 'nested').mkdir(parents=True)
    for name, path in (('folderone', folder / 'one.zip'), ('foldertwo', folder / 'nested/two.zip')):
        with zipfile.ZipFile(path, 'w', zipfile.ZIP_DEFLATED) as archive:
            archive.writestr('manifest.json', json.dumps(dict(id=name, name=name, api=2, version='1.0.0', entry='main.lua', games=['crystal'])))
            archive.writestr('main.lua', entry)
    config['folder'] = str(folder)
    config_path = output / 'fixtures.json'
    config_path.write_text(json.dumps(config), encoding='utf-8')
    env = {key: value for key, value in os.environ.items() if not key.startswith('POKEPORT_')}
    env.update(INSTALL_ENGINE_ROOT=str(ROOT), INSTALL_QA_IDENTITY=identity,
               INSTALL_QA_CONFIG=str(config_path), SDL_VIDEODRIVER='dummy', SDL_AUDIODRIVER='dummy')
    result = run([str(executable), str(host)], cwd=ROOT, env=env,
                 capture_output=True, text=True, timeout=90)
    log = result.stdout + result.stderr
    (output / 'runtime.log').write_text(log, encoding='utf-8')
    print(log, end='', flush=True)
    result.check_returncode()
    match = re.search(r'Native installer: (\d+) checks PASS;', log)
    assert match, 'real installer qualification marker missing'
    inputs = list((ROOT / 'src/mods').glob('ModInstall*.lua')) + [ROOT / 'src/mods/LauncherMods.lua', ROOT / 'src/core/NativeFile.lua']
    report = dict(passed=True, checks=int(match[1]), platform=platform.system(),
                  externalDirectories='External directories: supported' in log,
                  scope='Real ZIP mounting, scoped filesystem writes, cancellation, recovery and native profile IO; no ROM, GPU, network or player profile',
                  inputsSha256={str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest() for path in inputs})
    (output / 'report.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(str(output / 'report.json'), flush=True)


if __name__ == '__main__':
    main()
