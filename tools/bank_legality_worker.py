"""Private native export + PKHeX analysis; no public inbound listener."""
# Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
from arena_verifier_worker import request

def process(job, config, run=subprocess.run):
    raw = job['input'].encode()
    if hashlib.sha256(raw).hexdigest() != job['input_digest']:
        raise ValueError('Frozen Bank digest mismatch')
    payload = json.loads(raw)
    dataset = config['datasets'].get(payload.get('edition'))
    if not dataset:
        return {'schema': 1, 'parsed': False, 'valid': False, 'error': 'No operator-qualified native data for this edition'}
    with tempfile.TemporaryDirectory(prefix='bank-legality-') as directory:
        source, result = Path(directory) / 'bank.json', Path(directory) / 'native.json'
        source.write_bytes(raw)
        runtime = config.get('lua', ['luajit'])
        if isinstance(runtime, str): runtime = [runtime]
        env = os.environ | {'POKEPORT_DATA_DIR': str(Path(dataset).resolve() / 'data/generated')}
        child = run([*runtime, 'tools/bank_legality_host.lua', str(source), str(result)], cwd=config['root'], env=env,
                               capture_output=True, timeout=120)
        if child.returncode not in (0, 2) or not result.exists():
            raise RuntimeError('Native Bank exporter failed')
        record = json.loads(result.read_text())
        if child.returncode == 2 or 'error' in record:
            return {'schema': 1, 'parsed': False, 'valid': False, 'error': 'Native origin data is incomplete or unsupported'}
        checker = run([config.get('dotnet', 'dotnet'), config['checker']], input=result.read_bytes(),
                                 capture_output=True, timeout=30)
        if checker.returncode not in (0, 2) or len(checker.stdout) > 96 * 1024:
            raise RuntimeError('Independent legality checker failed')
        report = json.loads(checker.stdout)
        report['reward_genetics'] = record.get('reward_genetics', 'not_applicable')
        if report.get('parsed') and report.get('dex') != payload['entry']['canonical'].get('dex'):
            report['valid'] = False
            report['error'] = 'The national species identity differs from the native record'
        return report

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', type=Path, required=True)
    parser.add_argument('--once', action='store_true')
    args = parser.parse_args(); config = json.loads(args.config.read_text())
    token = Path(config['token_file']).read_text().strip()
    while True:
        try:
            job = request(config['api'], token, 'claim', {}, group='bank')['job']
            if job:
                if job['release'] != config['release']: raise ValueError('Legality release mismatch')
                report = process(job, config)
                request(config['api'], token, job['id'] + '/result', {'lease': job['lease'], 'input_digest': job['input_digest'],
                        'release': job['release'], 'result': report}, group='bank')
                print(json.dumps({'job': job['id'], 'parsed': report['parsed'], 'valid': report['valid']}), flush=True)
            if args.once: return
            time.sleep(3)
        except Exception as error:
            print(json.dumps({'worker_error': type(error).__name__}), flush=True)
            if args.once: raise
            time.sleep(10)

if __name__ == '__main__':
    main()
