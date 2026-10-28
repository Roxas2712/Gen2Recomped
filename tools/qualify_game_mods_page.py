#!/usr/bin/env python3
"""Capture the real launcher module page with a synthetic, offline mod fixture.
No real account, ROM, installed package or production installation is used.
Contributions by Roxas2712.
"""
import argparse
import atexit
import json
import os
from pathlib import Path
import sys
import time
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--love', type=Path, required=True)
    parser.add_argument('--label', required=True)
    args = parser.parse_args()
    assert args.label.replace('-', '').isalnum()
    import qa_storage as qa
    qa._storage = qa.Storage(ROOT)
    atexit.register(qa._storage.close, collect=False)
    for path in (ROOT, args.love, Path(sys.executable)):
        qa.qa_source(path.resolve())
    out = ROOT / '.local/qa' / ('module-mods-render-' + args.label)
    qa.qa_cache(out)
    out.mkdir(parents=True, exist_ok=True)
    assert not (out / 'report.json').exists(), 'Preserve existing evidence'
    results = []
    archives = {'result': str(out / 'archives-result.json')}
    for name in ('good', 'wrong_game', 'wrong_generation', 'wrong_engine', 'wrong_api', 'manual'):
        manifest = {'id': 'qa-manual-package' if name == 'manual' else 'qa-module-package',
                    'name': 'QA module package', 'version': '1.0.0', 'api': 3, 'entry': 'main.lua',
                    'games': ['red'] if name in ('wrong_game', 'manual') else ['gen3'] if name == 'wrong_generation' else ['crystal']}
        if name == 'wrong_engine':
            manifest['game_version'] = '>=99.0.0'
        if name == 'wrong_api':
            manifest['api'] = 99
        path = out / (name + '.zip')
        with zipfile.ZipFile(path, 'w', zipfile.ZIP_DEFLATED) as archive:
            archive.writestr('manifest.json', json.dumps(manifest))
            archive.writestr('main.lua', '-- Synthetic QA package; never loaded as game code.\n')
        archives[name] = str(path)
    config = out / 'archives-config.json'
    config.write_text(json.dumps(archives))
    for width, extra in ((1440, 0), (720, 0), (1440, 320)):
        suffix = str(width) + ('-controls' if extra else '')
        identity = 'oasc-module-mods-qa-' + args.label + '-' + suffix
        profile = Path.home() / 'Library/Application Support/LOVE' / identity
        qa.qa_source(profile)
        qa.qa_profile(profile)
        host = ROOT / '.local/engine-parity' / identity
        qa.qa_copy(host, ephemeral=True)
        host.mkdir(parents=True)
        for name in ('src', 'data', 'assets', 'mods', 'tools', 'tests'):
            if (ROOT / name).exists():
                (host / name).symlink_to(ROOT / name, target_is_directory=True)
        (host / 'main.lua').write_bytes((ROOT / 'tests/fixtures/module_mods_preview.lua').read_bytes())
        (host / 'conf.lua').write_text(
            'function love.conf(t) love.filesystem.setSymlinksEnabled(true);'
            't.identity=' + json.dumps(identity) + ';t.version="12.0";'
            't.window.width=' + str(width) + ';t.window.height=960;'
            't.modules.audio=false;t.modules.physics=false end\n')
        image = out / (suffix + '.png')
        with (out / (suffix + '.log')).open('w') as log:
            child = qa.qa_popen([str(args.love), str(host)], cwd=ROOT,
                                env=os.environ | {'MODULE_MODS_CAPTURE': str(image), 'MODULE_MODS_ARCHIVES': str(config), 'MODULE_MODS_SCROLL_EXTRA': str(extra)}, stdout=log, stderr=log)
            try:
                deadline = time.monotonic() + 60
                while child.poll() is None and time.monotonic() < deadline:
                    time.sleep(.1)
                assert child.poll() == 0 and image.is_file(), 'Renderer failed; see ' + str(out)
            finally:
                if child.poll() is None:
                    child.terminate()
                    child.wait(timeout=10)
        results.append({'width': width, 'image': image.name, 'rendered': True})
    archive_result = json.loads((out / 'archives-result.json').read_text())
    (out / 'report.json').write_text(json.dumps({'passed': True, 'scope': 'Actual launcher renderer and ZIP installer, synthetic offline fixtures; not a live download', 'archives': archive_result, 'results': results}, indent=2) + '\n')
    print(out, flush=True)


if __name__ == '__main__':
    main()
