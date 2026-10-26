#!/usr/bin/env python3
"""Qualify native Gen 3 battle suspend through a private local ModCompass API.

Requires a local Laravel backend with installed dependencies, macOS LÖVE app,
PHP, a trusted localhost TLS certificate/key, and caller-owned imported caches.
Repeat --cache EDITION=PATH for each edition. No ROMs or real accounts are sent
anywhere. Each case uses one fake account and two fresh LÖVE profiles/processes.
This is desktop reconstruction/HTTPS proof, not physical mobile-device proof.
"""
# Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
import argparse
import base64
import hashlib
import http.server
import json
import os
from pathlib import Path
import secrets
import shutil
import socket
import ssl
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
EDITIONS = ('red', 'blue', 'yellow', 'gold', 'silver', 'crystal', 'ruby', 'sapphire', 'emerald', 'firered', 'leafgreen')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--backend', type=Path, required=True)
    parser.add_argument('--php', type=Path, required=True)
    parser.add_argument('--love-app', type=Path, required=True)
    parser.add_argument('--cert', type=Path, required=True)
    parser.add_argument('--key', type=Path, required=True)
    parser.add_argument('--cache', action='append', required=True, metavar='EDITION=PATH')
    parser.add_argument('--move', choices=['TACKLE','SWIFT'], default='SWIFT', help='SWIFT guarantees damage before suspend without modifying imported move data')
    parser.add_argument('--trainer', action='store_true', help='Exercise a real imported trainer instead of the wild battle')
    parser.add_argument('--idle-ticks', type=int, default=0, help='Age the native battle before saving; 108000 ticks = 30 simulated minutes')
    parser.add_argument('--during-animation', action='store_true')
    parser.add_argument('--private-game-cache', action='store_true', help='Transfer the real imported game through the private API; target starts without game data')
    parser.add_argument('--timeout', type=int, default=180)
    args = parser.parse_args()
    caches = {}
    for entry in args.cache:
        edition, directory = entry.split('=', 1)
        if edition not in EDITIONS or edition in caches:
            parser.error('Supply each supported edition at most once')
        caches[edition] = Path(directory).expanduser().resolve(strict=True)
    backend = args.backend.resolve(strict=True)
    php, runtime = args.php.resolve(strict=True), args.love_app.resolve(strict=True)
    cert, key = args.cert.resolve(strict=True), args.key.resolve(strict=True)
    driver = ROOT / 'tests/native_suspend/main.lua'
    profiles = Path.home() / 'Library/Application Support/LOVE'
    from qa_storage import qa_source, qa_cache, qa_copy, qa_profile, qa_run, qa_popen
    # Pin every input before the first destination can trigger collection.
    for path in (ROOT, backend, php, runtime, cert, key, driver, Path(sys.executable), *caches.values()):
        qa_source(path)
    run_id = str(time.time_ns())
    output = ROOT / '.local/qa' / ('retro-gen3-suspend-' + run_id)
    qa_cache(output)
    output.mkdir(parents=True)
    output.chmod(0o700)
    source = output / 'source'
    qa_copy(source)
    source.mkdir()
    shutil.copytree(ROOT / 'src', source / 'src')
    for name in ('assets', 'data', 'tests'):
        (source / name).symlink_to(ROOT / name, target_is_directory=True)
    (source / 'main.lua').write_bytes(driver.read_bytes())
    (source / 'conf.lua').write_text("""function love.conf(t)
 love.filesystem.setSymlinksEnabled(true);t.identity=os.getenv('POKEPORT_IDENTITY')
 t.window.title='RetroRecomped suspend QA';t.window.visible=false
 t.window.width=720;t.window.height=600;t.window.vsync=0;t.console=false
end
""")
    source_hashes = {str(p.relative_to(source)): hashlib.sha256(p.read_bytes()).hexdigest()
                     for p in [*sorted((source / 'src').rglob('*.lua')), source / 'main.lua', source / 'conf.lua']}
    (output / 'source-fingerprints.json').write_text(json.dumps(source_hashes, indent=2) + '\n')
    storage = output / 'backend-storage'
    for name in ('app/private', 'framework/cache/data', 'framework/sessions', 'framework/views', 'logs'):
        (storage / name).mkdir(parents=True, exist_ok=True)
    database = output / 'private.sqlite'
    database.touch()
    # Bind the TLS fixture before starting PHP; no public interface is opened.
    proxy = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Proxy)
    with socket.socket() as available:
        available.bind(('127.0.0.1', 0))
        backend_port = available.getsockname()[1]
    url = 'https://localhost:' + str(proxy.server_port)
    env = os.environ | dict(
        APP_ENV='testing', APP_DEBUG='false', APP_KEY='base64:' + base64.b64encode(secrets.token_bytes(32)).decode(),
        APP_URL=url, LARAVEL_STORAGE_PATH=str(storage), DB_CONNECTION='sqlite', DB_DATABASE=str(database), DB_URL='',
        CACHE_STORE='array', SESSION_DRIVER='array', MAIL_MAILER='array', QUEUE_CONNECTION='sync',
        RETRO_CLOUD_ENABLED='true', RETRO_CLOUD_URL=url, LOG_CHANNEL='stderr',
        APP_CONFIG_CACHE=str(output / 'no-config.php'), APP_ROUTES_CACHE=str(output / 'no-routes.php'),
        NO_PROXY='localhost,127.0.0.1')
    check = '''require "vendor/autoload.php";$a=require "bootstrap/app.php";
$a->make(Illuminate\\Contracts\\Console\\Kernel::class)->bootstrap();
if(config('database.default')!=='sqlite'||config('database.connections.sqlite.database')!==getenv('DB_DATABASE')
 ||config('filesystems.disks.local.root')!==getenv('LARAVEL_STORAGE_PATH').'/app/private')
 throw new RuntimeException('Private QA database and object storage only');'''
    qa_run([str(php), '-r', check], cwd=backend, env=env, check=True, capture_output=True)
    qa_run([str(php), 'artisan', 'migrate', '--force', '--no-interaction'], cwd=backend, env=env,
           check=True, capture_output=True)
    seed = output / 'seed.php'
    seed.write_text('''<?php
require getenv('SUSPEND_BACKEND').'/vendor/autoload.php';
$a=require getenv('SUSPEND_BACKEND').'/bootstrap/app.php';
$a->make(Illuminate\\Contracts\\Console\\Kernel::class)->bootstrap();
if(config('database.default')!=='sqlite'||config('database.connections.sqlite.database')!==getenv('DB_DATABASE'))
 throw new RuntimeException('Private database only');
$u=App\\Models\\User::factory()->create(['name'=>getenv('SUSPEND_NAME'),'email'=>getenv('SUSPEND_EMAIL'),
 'password'=>Illuminate\\Support\\Facades\\Hash::make(getenv('SUSPEND_PASSWORD'))]);
if(!$u->hasVerifiedEmail())throw new RuntimeException('QA account must have a confirmed email');
''')
    children, results = [], []
    process = None
    log = (output / 'php.log').open('ab')
    try:
        process = qa_popen([str(php), '-S', '127.0.0.1:' + str(backend_port),
                           str(backend / 'vendor/laravel/framework/src/Illuminate/Foundation/resources/server.php')],
                          cwd=backend / 'public', env=env, stdout=log, stderr=log)
        proxy.backend_port = backend_port
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.load_cert_chain(cert, key)
        proxy.socket = context.wrap_socket(proxy.socket, server_side=True)
        threading.Thread(target=proxy.serve_forever, daemon=True).start()
        for edition, cache in caches.items():
            email = run_id + '-' + edition + '@suspend.invalid'
            password = 'Suspend-' + secrets.token_urlsafe(22) + '9!'
            qa_run([str(php), str(seed)], cwd=backend,
                   env=env | dict(SUSPEND_BACKEND=str(backend), SUSPEND_EMAIL=email, SUSPEND_PASSWORD=password,
                                  SUSPEND_NAME='Suspend ' + edition),
                   check=True, capture_output=True)
            for role in ('source', 'target'):
                identity = 'oasc-suspend-qa-' + run_id + '-' + edition + '-' + role
                qa_profile(profiles / identity)
                config = dict(edition=edition, role=role, privateGameCache=args.private_game_cache, animation=args.during_animation, idleTicks=args.idle_ticks, trainer=args.trainer, move=args.move, email=email, password=password, cache=str(cache),
                              api=url + '/api/cloud/v1', library=str(runtime / 'Contents/Frameworks/love.framework/Versions/A/love'),
                              result=str(output / (edition + '-' + role + '.json')),
                              expected=str(output / (edition + '-expected.lua')))
                config_path = output / (edition + '-' + role + '-config.json')
                config_path.write_text(json.dumps(config))
                config_path.chmod(0o600)
                with (output / (edition + '-' + role + '.log')).open('ab') as case_log:
                    child = qa_popen([str(runtime / 'Contents/MacOS/love'), str(source)], cwd=ROOT,
                                    env={k:v for k,v in (os.environ | dict(POKEPORT_IDENTITY=identity, POKEPORT_DATA_DIR=str(cache / 'data/generated'),
                                        POKEPORT_NO_DISCORD='1', POKEPORT_SKIP_LEGACY_MIGRATION='1', RETRO_SUSPEND_CONFIG=str(config_path),
                                        SSL_CERT_FILE=str(cert), CURL_CA_BUNDLE=str(cert), NO_PROXY='localhost,127.0.0.1')).items() if k!='POKEPORT_DATA_DIR' or not args.private_game_cache},
                                    stdout=case_log, stderr=case_log)
                    children.append(child)
                    try:
                        child.wait(timeout=args.timeout)
                    except subprocess.TimeoutExpired:
                        child.terminate()
                        child.wait(timeout=10)
                    except Exception:
                        child.terminate()
                        child.wait(timeout=10)
                        raise
                result_path = Path(config['result'])
                result = json.loads(result_path.read_text()) if result_path.exists() else dict(
                    ok=False, edition=edition, role=role, reason='No result; inspect the owned case log')
                results.append(result)
                (output / 'results.json').write_text(json.dumps(results, indent=2))
                print(json.dumps(result), flush=True)
                if not result['ok'] or child.returncode != 0:
                    raise RuntimeError('Native cloud suspend failed: ' + str(output))
        assert all(hashlib.sha256((source / p).read_bytes()).hexdigest() == digest for p, digest in source_hashes.items())
        report = dict(passed=True, editions=list(caches), results=results, sourceSha256=source_hashes,
                      scope='Two independent fresh macOS processes/profiles, real imported data and native battle, private local HTTPS API; no physical or cross-OS proof')
        (output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
        print('GEN3_CLOUD_SUSPEND_PASS ' + str(output), flush=True)
    finally:
        for child in children:
            if child.poll() is None:
                child.terminate()
                child.wait(timeout=10)
        if process and process.poll() is None:
            process.terminate()
            process.wait(timeout=10)
        # serve_forever only started after a successful TLS setup.
        if hasattr(proxy, 'backend_port') and proxy.socket and isinstance(proxy.socket, ssl.SSLSocket):
            proxy.shutdown()
        proxy.server_close()
        log.close()


class Proxy(http.server.BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def proxy(self):
        body = self.rfile.read(int(self.headers.get('Content-Length', '0')))
        headers = {k: v for k, v in self.headers.items() if k.lower() not in ('host', 'connection', 'content-length')}
        headers['Host'] = 'localhost:' + str(self.server.server_port)
        headers['X-Forwarded-Proto'] = 'https'
        request = urllib.request.Request('http://127.0.0.1:' + str(self.server.backend_port) + self.path,
                                         data=body if self.command != 'GET' else None, headers=headers, method=self.command)
        # This fixture never follows a redirect carrying authentication.
        opener = urllib.request.build_opener(NoRedirect)
        try:
            response = opener.open(request, timeout=35)
        except urllib.error.HTTPError as error:
            response = error
        with response:
            data = response.read()
            self.send_response(response.code)
            for key in ('Content-Type', 'ETag', 'Cache-Control'):
                if response.headers.get(key):
                    self.send_header(key, response.headers[key])
            self.send_header('Content-Length', str(len(data)))
            self.end_headers()
            self.wfile.write(data)

    do_GET = do_POST = do_PUT = proxy


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None


if __name__ == '__main__':
    main()
