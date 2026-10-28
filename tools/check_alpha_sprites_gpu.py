#!/usr/bin/env python3
# Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
"""Check final world-compositor alpha/grass pixels and native depth cutouts.

No ROMs, mods or player saves. A separate --engine checkout can be used to
reproduce the pre-fix failure with the same fixture. macOS packaged apps need
--runtime-app so their embedded game is not launched instead of the fixture.
"""
import argparse
import atexit
import hashlib
import json
import os
from pathlib import Path
import sys
import uuid

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import qa_storage as qa


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    runtime = parser.add_mutually_exclusive_group(required=True)
    runtime.add_argument('--runtime-app', type=Path)
    runtime.add_argument('--love', type=Path)
    parser.add_argument('--engine', type=Path, default=ROOT)
    parser.add_argument('--backend', choices=['metal', 'opengl', 'opengles', 'vulkan'], required=True)
    parser.add_argument('--version', choices=['red', 'crystal'], required=True)
    args = parser.parse_args()
    source = args.engine.resolve()
    runtime = (args.runtime_app or args.love).resolve()
    qa._storage = qa.Storage(ROOT)
    atexit.register(qa._storage.close)
    run_id = 'alpha-sprites-' + uuid.uuid4().hex[:12]
    group = ROOT / '.local/qa' / run_id
    host, out = group / 'candidate', group / 'evidence'
    identity = 'oasc-gen2recomp-qa-' + run_id
    profile = Path.home() / 'Library/Application Support/LOVE' / identity if sys.platform == 'darwin' else Path(os.environ.get('APPDATA', Path.home() / '.local/share')) / 'LOVE' / identity
    for item in (ROOT, source, runtime, profile, Path(__file__), Path(sys.executable)):
        qa.qa_source(item)
    qa.qa_profile(profile)
    qa.qa_cache(out)
    qa.qa_copy(host, ephemeral=True)
    out.mkdir(parents=True, exist_ok=True)
    host.mkdir(parents=True, exist_ok=True)
    if args.runtime_app:
        exe = host / 'Alpha QA.app/Contents/MacOS/love'
        exe.parent.mkdir(parents=True)
        qa.qa_run(['/bin/cp', str(runtime / 'Contents/MacOS/love'), str(exe)], check=True)
        (exe.parent.parent / 'Frameworks').symlink_to(runtime / 'Contents/Frameworks', target_is_directory=True)
    else:
        exe = runtime
    for name in ('conf.lua', 'main.lua'):
        (host / name).write_bytes((ROOT / 'tools/alpha-sprite-gpu' / name).read_bytes())
    provenance = {'engine': str(source), 'backend': args.backend, 'version': args.version, 'sources': {}}
    for name in ('src/render/SpriteRenderer.lua', 'src/render/TileRenderer.lua', 'src/world/OverworldController.lua', 'src/render/Renderer.lua'):
        provenance['sources'][name] = hashlib.sha256((source / name).read_bytes()).hexdigest()
    (out / 'sources.json').write_text(json.dumps(provenance, indent=2) + '\n')
    env = {k: v for k, v in os.environ.items() if not k.startswith(('POKEPORT_', 'ALPHA_'))}
    env.update(POKEPORT_IDENTITY=identity, POKEPORT_GRAPHICS_BACKEND=args.backend,
               ALPHA_ENGINE=str(source), ALPHA_OUT=str(out), ALPHA_VERSION=args.version,
               POKEPORT_NO_DISCORD='1')
    with (out / 'native.log').open('w') as log:
        result = qa.qa_run([str(exe), str(host)], cwd=ROOT, env=env, stdout=log, stderr=log, timeout=90)
    print((out / 'native.log').read_text())
    print('Evidence:', out, flush=True)
    if result.returncode:
        return result.returncode
    report = json.loads((out / 'report.json').read_text())
    assert all(report[key] for key in ('transparentBackground', 'authoredColor', 'foregroundGrass', 'depthCutout', 'depthBody'))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
