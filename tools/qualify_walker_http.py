#!/usr/bin/env python3
"""Exercise real walker cloud modules against an isolated local ModCompass server.
Two LÖVE profiles simulate two devices sharing one account; an additional
account checks isolation. This does not qualify production login or hardware.
"""
# Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
import argparse
import atexit
import base64
import json
import os
from pathlib import Path
import socket
import sys
import time
import urllib.request
import urllib.error

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('server', 'php', 'love'):
        parser.add_argument('--' + name, type=Path, required=True)
    parser.add_argument('--label', required=True)
    args = parser.parse_args()
    assert args.label.replace('-', '').isalnum()
    import qa_storage as qa
    qa._storage = qa.Storage(ROOT)
    atexit.register(qa._storage.close, collect=False)
    for source in (ROOT, args.server, args.php, args.love, Path(sys.executable)):
        qa.qa_source(source.resolve())
    output = ROOT / '.local/qa' / ('walker-http-' + args.label)
    qa.qa_cache(output)
    output.mkdir(parents=True, exist_ok=True)
    assert not (output / 'test.sqlite').exists(), 'Preserve existing evidence'
    os.chmod(output, 0o700)
    database = output / 'test.sqlite'
    database.touch()
    for part in ('framework/cache/data', 'framework/sessions', 'framework/views', 'logs'):
        (output / 'storage' / part).mkdir(parents=True, exist_ok=True)
    env = os.environ | {'APP_ENV': 'testing', 'APP_DEBUG': 'false', 'APP_KEY': 'base64:' + base64.b64encode(os.urandom(32)).decode(),
                        'DB_CONNECTION': 'sqlite', 'DB_DATABASE': str(database), 'DB_URL': '', 'CACHE_STORE': 'file',
                        'SESSION_DRIVER': 'array', 'MAIL_MAILER': 'array', 'QUEUE_CONNECTION': 'sync', 'BCRYPT_ROUNDS': '4',
                        'RETRO_CLOUD_ENABLED': 'true', 'LARAVEL_STORAGE_PATH': str(output / 'storage'),
                        'APP_CONFIG_CACHE': str(output / 'config.php'), 'APP_ROUTES_CACHE': str(output / 'routes.php'),
                        'LOG_CHANNEL': 'stderr', 'PINBALL_HTTP_FIXTURE': str(output / 'accounts.json')}
    with (output / 'bootstrap.log').open('w') as log:
        qa.qa_run([str(args.php), 'artisan', 'migrate', '--force', '--no-interaction'], cwd=args.server, env=env, stdout=log, stderr=log, check=True)
        qa.qa_run([str(args.php), 'tests/Fixtures/pinball_http.php'], cwd=args.server, env=env, stdout=log, stderr=log, check=True)
    accounts = json.loads((output / 'accounts.json').read_text())
    with socket.socket() as listener:
        listener.bind(('127.0.0.1', 0))
        port = listener.getsockname()[1]
    url = 'http://127.0.0.1:' + str(port)
    results = []
    with (output / 'server.log').open('w') as log:
        backend = qa.qa_popen([str(args.php), '-S', '127.0.0.1:' + str(port), '-t', 'public', 'public/index.php'], cwd=args.server, env=env, stdout=log, stderr=log)
        try:
            for _ in range(100):
                try:
                    urllib.request.urlopen(url + '/api/cloud/v1/objects', timeout=.5)
                    break
                except urllib.error.HTTPError:
                    break
                except OSError:
                    time.sleep(.1)
            hosts = {}
            for device in ('a', 'b', 'foreign'):
                identity = 'oasc-walker-http-qa-' + args.label + '-' + device
                profile = Path.home() / 'Library/Application Support/LOVE' / identity
                qa.qa_source(profile)
                qa.qa_profile(profile)
                host = ROOT / '.local/engine-parity' / identity
                qa.qa_copy(host, ephemeral=True)
                host.mkdir(parents=True)
                for name in ('src', 'data', 'assets', 'mods', 'tools', 'tests'):
                    (host / name).symlink_to(ROOT / name, target_is_directory=True)
                (host / 'main.lua').write_bytes((ROOT / 'tests/fixtures/walker_http.lua').read_bytes())
                (host / 'conf.lua').write_text('function love.conf(t) love.filesystem.setSymlinksEnabled(true);t.identity=' + json.dumps(identity) + ';t.version="12.0";t.window=false;t.modules.audio=false;t.modules.physics=false end\n')
                hosts[device] = host
            for index, (device, phase) in enumerate((('a', 'seed'), ('b', 'advance200'), ('a', 'pull'), ('b', 'advance300'), ('a', 'conflict'), ('foreign', 'foreign'), ('b', 'revision'))):
                account = accounts[1 if device == 'foreign' else 0]
                report = output / (str(index) + '-' + phase + '.json')
                with (output / (str(index) + '-' + phase + '.log')).open('w') as client_log:
                    qa.qa_run([str(args.love), str(hosts[device])], cwd=ROOT,
                              env=os.environ | {'WALKER_HTTP_URL': url, 'WALKER_HTTP_ACCOUNT': account['account'], 'WALKER_HTTP_TOKEN': account['token'], 'WALKER_HTTP_PHASE': phase, 'WALKER_HTTP_REPORT': str(report)},
                              stdout=client_log, stderr=client_log, timeout=75, check=True)
                results.append(json.loads(report.read_text()))
        finally:
            backend.terminate()
            backend.wait(timeout=10)
    (output / 'report.json').write_text(json.dumps({'passed': True, 'scope': __doc__, 'results': results}, indent=2) + '\n')
    print(output, flush=True)


if __name__ == '__main__':
    main()
