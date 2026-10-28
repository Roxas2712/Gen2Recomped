#!/usr/bin/env python3
"""Render the actual Pokéwalker social page with isolated offline fixtures."""
# Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
import argparse
import atexit
import json
import os
from pathlib import Path
import sys
import time

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--love', type=Path, required=True)
    parser.add_argument('--label', required=True)
    parser.add_argument('--conflict', action='store_true', help='Render the explicit complete-snapshot conflict chooser.')
    args = parser.parse_args()
    assert args.label.replace('-', '').isalnum()
    import qa_storage as qa
    qa._storage = qa.Storage(ROOT)
    atexit.register(qa._storage.close, collect=False)
    for path in (ROOT, args.love, Path(sys.executable)):
        qa.qa_source(path.resolve())
    output = ROOT / '.local/qa' / ('walker-online-render-' + args.label)
    qa.qa_cache(output)
    output.mkdir(parents=True, exist_ok=True)
    assert not (output / 'report.json').exists(), 'Preserve existing evidence'
    results = []
    for width, guest in ((360, False), (1120, False), (360, True)):
        label = str(width) + ('-guest' if guest else '-account')
        identity = 'oasc-walker-online-qa-' + args.label + '-' + label
        profile = Path.home() / 'Library/Application Support/LOVE' / identity
        qa.qa_source(profile)
        qa.qa_profile(profile)
        host = ROOT / '.local/engine-parity' / identity
        qa.qa_copy(host, ephemeral=True)
        host.mkdir(parents=True)
        for name in ('src', 'data', 'assets', 'mods', 'tools', 'tests'):
            (host / name).symlink_to(ROOT / name, target_is_directory=True)
        (host / 'main.lua').write_bytes((ROOT / 'tests/fixtures/walker_online_preview.lua').read_bytes())
        (host / 'conf.lua').write_text(
            'function love.conf(t) love.filesystem.setSymlinksEnabled(true);'
            't.identity=' + json.dumps(identity) + ';t.version="12.0";'
            't.window.width=' + str(width) + ';t.window.height=1000;'
            't.modules.audio=false;t.modules.physics=false end\n')
        image = output / (label + '.png')
        with (output / (label + '.log')).open('w') as log:
            child = qa.qa_popen([str(args.love), str(host)], cwd=ROOT,
                                env=os.environ | {'WALKER_PREVIEW_CAPTURE': str(image), 'WALKER_PREVIEW_GUEST': '1' if guest else '0', 'WALKER_PREVIEW_CONFLICT': '1' if args.conflict else '0'}, stdout=log, stderr=log)
            try:
                deadline = time.monotonic() + 60
                while child.poll() is None and time.monotonic() < deadline:
                    time.sleep(.1)
                assert child.poll() == 0 and image.is_file(), 'Renderer failed; see ' + str(output)
            finally:
                if child.poll() is None:
                    child.terminate()
                    child.wait(timeout=10)
        results.append({'width': width, 'guest': guest, 'image': image.name, 'rendered': True})
    (output / 'report.json').write_text(json.dumps({'passed': True, 'scope': 'Actual LÖVE renderer; synthetic social state; no live service', 'results': results}, indent=2) + '\n')
    print(output, flush=True)


if __name__ == '__main__':
    main()
