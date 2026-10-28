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
import hashlib
import struct
import zlib
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--love', type=Path, required=True)
    parser.add_argument('--label', required=True)
    parser.add_argument('--conflict', action='store_true', help='Render the explicit complete-snapshot conflict chooser.')
    parser.add_argument('--enrollment', action='store_true', help='Render the mandatory minigame notice instead of the social page.')
    parser.add_argument('--content', action='store_true', help='Exercise real ZIP/PNG import, content setup and five basic minigames.')
    args = parser.parse_args()
    assert sum((args.enrollment, args.content, args.conflict)) <= 1
    assert args.label.replace('-', '').isalnum()
    import qa_storage as qa
    qa._storage = qa.Storage(ROOT)
    atexit.register(qa._storage.close, collect=False)
    for path in (ROOT, args.love, Path(sys.executable)):
        qa.qa_source(path.resolve())
    output = ROOT / '.local/qa' / (('minigame-content-render-' if args.content else 'minigame-enrollment-render-' if args.enrollment else 'walker-online-render-') + args.label)
    qa.qa_cache(output)
    output.mkdir(parents=True, exist_ok=True)
    assert not (output / 'report.json').exists(), 'Preserve existing evidence'
    pack = output / 'test-shapes.mgpack'
    if args.content:
        # Independent two-colour test pixels, never game artwork.
        def chunk(kind, data):
            return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data))
        pixels = b''.join(b'\x00' + bytes((80, 180 if y < 16 else 80, 220, 255)) * 16 for y in range(32))
        png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', 16, 32, 8, 6, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(pixels)) + chunk(b'IEND', b'')
        manifest = ('return {format=1,name="Independent test shapes",source="Generated QA pixels",credits="Roxas2712",terms="Test-only independent fixture",entries={{key="front/25",file="shape.png",size=' + str(len(png)) + ',md5="' + hashlib.md5(png).hexdigest() + '",width=16,height=32}}}')
        with zipfile.ZipFile(pack, 'w', zipfile.ZIP_DEFLATED) as archive:
            archive.writestr('minigames.lua', manifest)
            archive.writestr('shape.png', png)
    results = []
    cases = ((360, 800, False), (851, 393, False)) if args.enrollment or args.content else ((360, 1000, False), (1120, 1000, False), (360, 1000, True))
    for width, height, guest in cases:
        label = str(width) + 'x' + str(height) + ('-guest' if guest else '-account')
        identity = 'oasc-walker-online-qa-' + args.label + '-' + label
        profile = Path.home() / 'Library/Application Support/LOVE' / identity
        qa.qa_source(profile)
        qa.qa_profile(profile)
        host = ROOT / '.local/engine-parity' / identity
        qa.qa_copy(host, ephemeral=True)
        host.mkdir(parents=True)
        for name in ('src', 'data', 'assets', 'mods', 'tools', 'tests'):
            (host / name).symlink_to(ROOT / name, target_is_directory=True)
        fixture = 'minigame_content_preview.lua' if args.content else 'minigame_enrollment_preview.lua' if args.enrollment else 'walker_online_preview.lua'
        (host / 'main.lua').write_bytes((ROOT / 'tests/fixtures' / fixture).read_bytes())
        (host / 'conf.lua').write_text(
            'function love.conf(t) love.filesystem.setSymlinksEnabled(true);'
            't.identity=' + json.dumps(identity) + ';t.version="12.0";'
            't.window.width=' + str(width) + ';t.window.height=' + str(height) + ';'
            't.modules.audio=false;t.modules.physics=false end\n')
        image = output / (label + '.png')
        with (output / (label + '.log')).open('w') as log:
            child = qa.qa_popen([str(args.love), str(host)], cwd=ROOT,
                                env=os.environ | {'WALKER_PREVIEW_CAPTURE': str(image), 'WALKER_PREVIEW_PACK': str(pack), 'WALKER_PREVIEW_GUEST': '1' if guest else '0', 'WALKER_PREVIEW_CONFLICT': '1' if args.conflict else '0'}, stdout=log, stderr=log)
            try:
                deadline = time.monotonic() + 60
                while child.poll() is None and time.monotonic() < deadline:
                    time.sleep(.1)
                assert child.poll() == 0 and (image.with_suffix('.passed') if args.content else image).is_file(), 'Renderer failed; see ' + str(output)
            finally:
                if child.poll() is None:
                    child.terminate()
                    child.wait(timeout=10)
        results.append({'width': width, 'height': height, 'guest': guest, 'images': [p.name for p in sorted(output.glob(label + '*.png')) if p.stat().st_size > 10], 'rendered': True})
    (output / 'report.json').write_text(json.dumps({'passed': True, 'scope': 'Actual LÖVE renderer/filesystem; generated test content and synthetic social state; no live service', 'results': results}, indent=2) + '\n')
    print(output, flush=True)


if __name__ == '__main__':
    main()
