"""Outbound-only private Arena verifier; credentials never appear in command arguments."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import subprocess
import ssl
import tempfile
import time
import urllib.request
import urllib.parse
import urllib.error


def request(api, token, path, value, group='jobs'):
    if group not in ('jobs', 'bank'):
        raise ValueError('Unknown private verifier queue')
    url = api.rstrip('/') + '/verifier/' + group + '/' + path
    if urllib.parse.urlsplit(url).scheme != 'https':
        raise ValueError('The worker requires HTTPS')
    body = json.dumps(value).encode()
    req = urllib.request.Request(url, data=body, method='POST', headers={
        'Authorization': 'Bearer ' + token, 'Content-Type': 'application/json', 'Accept': 'application/json'})
    # A changed service URL must never forward the private worker key.
    class NoRedirect(urllib.request.HTTPRedirectHandler):
        def redirect_request(self, *args, **kwargs):
            return None
    with urllib.request.build_opener(NoRedirect, urllib.request.HTTPSHandler(context=ssl.create_default_context(cafile=os.environ.get('SSL_CERT_FILE')))).open(req, timeout=25) as response:
        return json.load(response)


def process(job, root, datasets, executable):
    raw = job['input'].encode()
    if hashlib.sha256(raw).hexdigest() != job['input_digest']:
        raise ValueError('Frozen input digest mismatch')
    payload = json.loads(raw)
    edition = payload.get('edition')
    if edition not in datasets:
        return {'ok': False, 'reason': 'No operator-qualified dataset for this edition'}
    dataset = Path(datasets[edition]).resolve()
    env = os.environ | {'POKEPORT_DATA_DIR': str(dataset / 'data/generated'),
                        'RETRO_VERIFIER_CRYPTO': os.environ.get('RETRO_VERIFIER_CRYPTO', 'libcrypto.so.3')}
    with tempfile.TemporaryDirectory(prefix='arena-replay-') as folder:
        source, result = Path(folder) / 'input.json', Path(folder) / 'result.json'
        source.write_bytes(raw)
        command = executable if isinstance(executable, list) else [executable]
        child = subprocess.run([*command, 'tools/arena_verifier_host.lua', str(source), str(result)],
                               cwd=root, env=env, capture_output=True, timeout=120)
        if child.returncode not in (0, 2) or not result.exists():
            # Detailed engine logs stay private; clients see a useful bounded reason.
            print(json.dumps({'native_process_exit': child.returncode, 'diagnostic': (child.stdout + child.stderr).decode(errors='replace')[-1500:]}), flush=True)
            raise RuntimeError('Native verifier process failed')
        parsed = json.loads(result.read_text())
        if bool(parsed.get('ok')) != (child.returncode == 0):
            raise ValueError('Native verifier exit status disagrees')
        return parsed


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', type=Path, required=True)
    parser.add_argument('--once', action='store_true')
    args = parser.parse_args()
    config = json.loads(args.config.read_text())
    root = Path(config['root']).resolve()
    token = Path(config['token_file']).read_text().strip()
    release = config['release']
    while True:
        try:
            job = request(config['api'], token, 'claim', {})['job']
            if job:
                if job['release'] != release:
                    raise ValueError('Worker release does not match the frozen job')
                result = process(job, root, config['datasets'], config.get('lua', 'luajit'))
                request(config['api'], token, job['id'] + '/result', {
                    'lease': job['lease'], 'input_digest': job['input_digest'], 'release': release, 'result': result})
                print(json.dumps({'job': job['id'], 'verified': bool(result.get('ok')), 'reason': result.get('reason')}), flush=True)
            elif args.once:
                return
            else:
                time.sleep(3)
        except Exception as error:
            # Do not log request headers, job contents, tokens or account data.
            print(json.dumps({'worker_error': type(error).__name__, 'reason': str(getattr(error, 'reason', error))[:160]}), flush=True)
            if args.once:
                raise SystemExit(1)
            time.sleep(10)


if __name__ == '__main__':
    main()
