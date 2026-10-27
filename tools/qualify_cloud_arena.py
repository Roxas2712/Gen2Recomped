#!/usr/bin/env python3
"""Exercise native Gen 1–3 Arena battles on a disposable local HTTPS service.

Supply local imported caches, PHP/Laravel and a localhost TLS certificate.
Each edition/scenario uses new fake accounts and two independent LÖVE profiles.
No production accounts, servers or game data uploads are used.
"""
# Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
import argparse
import base64
import hashlib
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
import urllib.request

from qualify_cloud_suspend import EDITIONS, Proxy
from qa_storage import qa_source, qa_cache, qa_copy, qa_profile, qa_run, qa_popen

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('backend', 'php', 'love-app', 'cert', 'key'):
        parser.add_argument('--' + name, type=Path, required=True)
    parser.add_argument('--cache', action='append', required=True, metavar='EDITION=PATH')
    parser.add_argument('--scenario', action='append', choices=['complete', 'recovery', 'abort'])
    parser.add_argument('--independent-replay', action='store_true')
    parser.add_argument('--crypto-library', type=Path)
    parser.add_argument('--timeout', type=int, default=180)
    args = parser.parse_args()
    caches = {}
    for entry in args.cache:
        edition, directory = entry.split('=', 1)
        if edition not in EDITIONS or edition in caches:
            parser.error('Supply each supported edition at most once')
        caches[edition] = Path(directory).expanduser().resolve(strict=True)
    backend, php, runtime, cert, key = [p.resolve(strict=True) for p in
        (args.backend, args.php, args.love_app, args.cert, args.key)]
    if args.independent_replay:
        assert args.crypto_library and os.environ.get('RETRO_QA_LUA_LIBRARY'), 'Replay needs the crypto and LuaJIT libraries'
        qa_source(args.crypto_library.resolve(strict=True))
        qa_source(Path(os.environ['RETRO_QA_LUA_LIBRARY']))
    driver = ROOT / 'tests/native_arena/main.lua'
    for path in (ROOT, backend, php, runtime, cert, key, driver, Path(sys.executable), *caches.values()):
        qa_source(path)
    run_id = str(time.time_ns())
    output = ROOT / '.local/qa' / ('retro-cloud-arena-' + run_id)
    qa_cache(output)
    output.mkdir(parents=True, mode=0o700)
    source = output / 'source'
    qa_copy(source, ephemeral=True)
    source.mkdir()
    shutil.copytree(ROOT / 'src', source / 'src')
    for name in ('assets', 'data', 'tools'):
        (source / name).symlink_to(ROOT / name, target_is_directory=True)
    (source / 'main.lua').write_bytes(driver.read_bytes())
    (source / 'conf.lua').write_text("""function love.conf(t)
 love.filesystem.setSymlinksEnabled(true);t.identity=os.getenv('POKEPORT_IDENTITY')
 t.window.title='RetroRecomped Arena QA';t.window.visible=false
 t.window.width=720;t.window.height=600;t.window.vsync=0;t.console=false
end
""")
    hashes = {str(p.relative_to(source)): hashlib.sha256(p.read_bytes()).hexdigest()
              for p in [*sorted((source / 'src').rglob('*.lua')), source / 'main.lua', source / 'conf.lua']}
    storage = output / 'storage'
    for path in ('framework/cache', 'framework/sessions', 'framework/views', 'logs', 'app/private'):
        (storage / path).mkdir(parents=True)
    database = output / 'arena.sqlite'
    database.touch(mode=0o600)
    import http.server
    proxy = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Proxy)
    with socket.socket() as available:
        available.bind(('127.0.0.1', 0))
        backend_port = available.getsockname()[1]
    url = 'https://localhost:' + str(proxy.server_port)
    worker_token = secrets.token_hex(32)
    worker_release = hashlib.sha256((ROOT / 'src/link/ArenaReplay.lua').read_bytes()).hexdigest()
    env = os.environ | dict(RETRO_ARENA_VERIFICATION_REQUIRED='true' if args.independent_replay else 'false',
        RETRO_VERIFIER_TOKEN_SHA256=hashlib.sha256(worker_token.encode()).hexdigest(),RETRO_VERIFIER_RELEASE=worker_release, APP_ENV='testing', APP_DEBUG='false',
        APP_KEY='base64:' + base64.b64encode(secrets.token_bytes(32)).decode(),
        APP_URL=url, LARAVEL_STORAGE_PATH=str(storage), DB_CONNECTION='sqlite',
        DB_DATABASE=str(database), DB_URL='', CACHE_STORE='array', SESSION_DRIVER='array',
        MAIL_MAILER='array', QUEUE_CONNECTION='sync', RETRO_CLOUD_ENABLED='true',
        RETRO_CLOUD_URL=url, LOG_CHANNEL='stderr', APP_CONFIG_CACHE=str(output / 'no-config.php'),
        APP_ROUTES_CACHE=str(output / 'no-routes.php'), NO_PROXY='localhost,127.0.0.1')
    boot = '''require "vendor/autoload.php";$a=require "bootstrap/app.php";
$a->make(Illuminate\\Contracts\\Console\\Kernel::class)->bootstrap();
if(config('database.default')!=='sqlite'||config('database.connections.sqlite.database')!==getenv('DB_DATABASE')
 ||config('filesystems.disks.local.root')!==getenv('LARAVEL_STORAGE_PATH').'/app/private')
 throw new RuntimeException('Private QA database and object storage only');'''
    qa_run([str(php), '-r', boot], cwd=backend, env=env, check=True, capture_output=True)
    qa_run([str(php), 'artisan', 'migrate', '--force', '--no-interaction'], cwd=backend,
           env=env, check=True, capture_output=True)
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain(cert, key)
    proxy.socket = context.wrap_socket(proxy.socket, server_side=True)
    proxy.backend_port = backend_port
    threading.Thread(target=proxy.serve_forever, daemon=True).start()
    client_context = ssl.create_default_context(cafile=str(cert))
    process, children, results = None, [], []

    def call(method, path, payload=None, token=None):
        headers = {'Accept': 'application/json', 'Content-Type': 'application/json'}
        if token:
            headers['Authorization'] = 'Bearer ' + token
        request = urllib.request.Request(url + '/api/cloud/v1' + path,
            data=json.dumps(payload).encode() if payload is not None else None,
            headers=headers, method=method)
        with urllib.request.urlopen(request, context=client_context, timeout=35) as response:
            return json.load(response)

    try:
        with (output / 'php.log').open('ab') as log:
            process = qa_popen([str(php), '-S', '127.0.0.1:' + str(backend_port),
                str(backend / 'vendor/laravel/framework/src/Illuminate/Foundation/resources/server.php')],
                cwd=backend / 'public', env=env, stdout=log, stderr=log)
        for _ in range(100):
            try:
                with socket.create_connection(('127.0.0.1', backend_port), timeout=.1):
                    break
            except OSError:
                time.sleep(.05)
        for edition, cache in caches.items():
            for scenario in args.scenario or ['complete', 'recovery', 'abort']:
                password = 'Arena-' + secrets.token_urlsafe(24) + '9!'
                seed = boot + '''
$people=[];foreach(['left','right'] as $role){
$u=App\\Models\\User::factory()->create(['name'=>'Arena '.getenv('ARENA_CASE').' '.$role,
 'email'=>$role.'-'.getenv('ARENA_CASE').'@arena.invalid','password'=>getenv('ARENA_PASSWORD')]);
$people[$role]=['email'=>$u->email,'id'=>(string)$u->id];}echo json_encode($people);'''
                people = json.loads(qa_run([str(php), '-r', seed], cwd=backend,
                    env=env | dict(ARENA_CASE=edition + '-' + scenario, ARENA_PASSWORD=password),
                    check=True, capture_output=True, text=True).stdout)
                tokens = {}
                for role, person in people.items():
                    login = call('POST', '/auth/login', dict(email=person['email'], password=password, label='Private native Arena QA'))
                    assert login['state'] == 'connected'
                    tokens[role] = login['access_token']
                    call('POST', '/arena/league/registration', {'active': True}, tokens[role])
                requested = call('POST', '/arena/league/challenges', dict(recipient=int(people['right']['id']),
                    format='rookie', editions=[edition]), tokens['left'])
                challenge = next(c for c in requested['challenges'] if c['state'] == 'pending')
                accepted = call('POST', '/arena/league/challenges/' + challenge['id'] + '/respond',
                    dict(accept=True, editions=[edition]), tokens['right'])
                assigned = next(c for c in accepted['challenges'] if c['id'] == challenge['id'])
                cup = call('GET', '/tournaments/' + assigned['tournament_id'], token=tokens['left'])
                match = cup['matches'][0]
                print('NATIVE_ARENA_START ' + edition + ' ' + scenario, flush=True)
                case_children = []
                for role, person in people.items():
                    identity = 'oasc-arena-qa-' + run_id + '-' + edition + '-' + scenario + '-' + role
                    qa_profile(Path.home() / 'Library/Application Support/LOVE' / identity)
                    config = dict(api=url + '/api/cloud/v1', edition=edition, role=role, scenario=scenario,
                        cache=str(cache), cup=cup, match=match, email=person['email'], password=password,
                        result=str(output / (identity + '.json')))
                    config_path = output / (identity + '-config.json')
                    config_path.write_text(json.dumps(config))
                    config_path.chmod(0o600)
                    child_env = os.environ | dict(POKEPORT_IDENTITY=identity,
                        POKEPORT_DATA_DIR=str(cache / 'data/generated'), POKEPORT_NO_DISCORD='1',
                        POKEPORT_SKIP_LEGACY_MIGRATION='1', RETRO_LINK_CONFIG=str(config_path),
                        RETRO_LINK_PHYSFS=str(runtime / 'Contents/Frameworks/love.framework/Versions/A/love'),
                        CURL_CA_BUNDLE=str(cert), SSL_CERT_FILE=str(cert), NO_PROXY='localhost,127.0.0.1')
                    with (output / (identity + '.log')).open('ab') as log:
                        child = qa_popen([str(runtime / 'Contents/MacOS/love'), str(source)],
                            cwd=ROOT, env=child_env, stdout=log, stderr=log)
                    children.append(child)
                    case_children.append((child, Path(config['result'])))
                deadline = time.monotonic() + args.timeout
                while any(c.poll() is None for c, _ in case_children) and time.monotonic() < deadline:
                    if args.independent_replay:
                        job = call('POST','/verifier/jobs/claim',{},worker_token)['job']
                        if job:
                            payload = json.loads(job['input'])
                            native_input, native_result = output / (job['id']+'-input.json'), output / (job['id']+'-result.json')
                            native_input.write_text(job['input']);native_input.chmod(0o600)
                            with (output / 'worker.log').open('ab') as log:
                                replay = qa_run([sys.executable,str(ROOT/'tools/run_lua_check.py'),str(ROOT/'tools/arena_verifier_host.lua'),str(native_input),str(native_result)],
                                    cwd=ROOT,env=os.environ|dict(RETRO_VERIFIER_CRYPTO=str(args.crypto_library),POKEPORT_DATA_DIR=str(caches[payload['edition']]/'data/generated')),
                                    stdout=log,stderr=log)
                            assert native_result.exists(), 'Native verifier failed; inspect worker.log'
                            verification = json.loads(native_result.read_text())
                            print('NATIVE_REPLAY '+json.dumps(verification),flush=True)
                            call('POST','/verifier/jobs/'+job['id']+'/result',dict(lease=job['lease'],input_digest=job['input_digest'],release=job['release'],result=verification),worker_token)
                    time.sleep(.2)
                pair = []
                for child, path in case_children:
                    if child.poll() is None:
                        child.terminate()
                    child.wait(timeout=10)
                    result = json.loads(path.read_text()) if path.exists() else dict(ok=False, reason='No native result; inspect case log')
                    pair.append(result)
                    assert child.returncode == 0 and result['ok'], result
                battle = call('GET', '/tournaments/' + cup['id'] + '/matches/' + match['id'] + '/battle', token=tokens['left'])['battle']
                profiles = {role: call('GET', '/arena/league', token=token) for role, token in tokens.items()}
                wallets = {role: call('GET', '/arena/shop', token=token)['coins'] for role, token in tokens.items()}
                if scenario == 'abort':
                    assert battle['state'] == 'cancelled'
                    assert all(p['points'] == 0 for p in profiles.values()) and all(c == 0 for c in wallets.values())
                else:
                    assert battle['state'] == 'complete'
                    if args.independent_replay: assert battle['verification'] == 'server_native_replay'
                    assert pair[0]['proof'] == pair[1]['proof'] and pair[0]['proof']['turns'] > 0
                    assert sorted(p['points'] for p in profiles.values()) == [-25, 50]
                    assert all(c > 0 for c in wallets.values())
                result = dict(edition=edition, scenario=scenario, battle_state=battle['state'],verification=battle['verification'],
                    points={role: p['points'] for role, p in profiles.items()}, wallets=wallets, results=pair)
                results.append(result)
                (output / 'results.json').write_text(json.dumps(results, indent=2))
                print(json.dumps(result), flush=True)
        assert all(hashlib.sha256((source / p).read_bytes()).hexdigest() == digest for p, digest in hashes.items())
        report = dict(passed=True, results=results, sourceSha256=hashes,
            scope='Independent macOS client profiles and private local HTTPS; no physical or cross-OS proof; ' + ('independent native server replay' if args.independent_replay else 'peer-attested results'))
        (output / 'report.json').write_text(json.dumps(report, indent=2))
        print('NATIVE_ARENA_PASS ' + str(output), flush=True)
    finally:
        for child in children:
            if child.poll() is None:
                child.terminate()
                child.wait(timeout=10)
        if process and process.poll() is None:
            process.terminate()
            process.wait(timeout=10)
        proxy.shutdown()
        proxy.server_close()


if __name__ == '__main__':
    main()
