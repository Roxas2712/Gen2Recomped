#!/usr/bin/env python3
"""Run the native companion pixel oracle on explicitly supplied LOVE builds."""
from pathlib import Path
import argparse
import atexit
import io
import json
import os
import sys
import tarfile
import time

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--love', type=Path, action='append', required=True)
    parser.add_argument('--backend', action='append', choices=('metal', 'opengl'), required=True)
    parser.add_argument('--qa-tools', type=Path, help='Optional managed QA tooling directory')
    args = parser.parse_args()
    engine = args.engine.resolve()
    sys.path.insert(0, str((args.qa_tools or engine / 'tools').resolve()))
    from qa_storage import Storage
    storage = Storage(engine)
    atexit.register(storage.close)
    for source in (engine, Path(__file__).resolve(), *args.love):
        storage.source(source.resolve())
    head = storage.run(['git', 'rev-parse', 'HEAD'], cwd=engine, check=True,
                       capture_output=True, text=True).stdout.strip()
    if storage.run(['git', 'status', '--porcelain'], cwd=engine, check=True,
                   capture_output=True, text=True).stdout.strip():
        raise SystemExit('Commit the candidate before recording GPU evidence')
    out = engine / '.local' / 'qa' / ('companion-gpu-' + str(time.time_ns()))
    storage.cache(out)
    out.mkdir(parents=True)
    source = out / 'source'
    storage.copy(source)
    source.mkdir()
    archive = storage.run(['git', 'archive', head, 'src', 'assets', 'data', 'tests', 'tools'],
                          cwd=engine, check=True, capture_output=True).stdout
    with tarfile.open(fileobj=io.BytesIO(archive)) as files:
        if any(Path(f.name).is_absolute() or '..' in Path(f.name).parts or f.issym() or f.islnk()
               for f in files.getmembers()):
            raise SystemExit('Unsafe candidate archive')
        files.extractall(source)
    runs = []
    for index, binary in enumerate(args.love):
        for backend in args.backend:
            name = str(index) + '-' + backend
            identity = 'oasc-companion-qa-' + name + '-' + str(time.time_ns())
            storage.identity(identity)
            report = out / (name + '.json')
            env = dict(os.environ, BATTLE_SOURCE_ENGINE=str(source), BATTLE_SOURCE_REPORT=str(report),
                       POKEPORT_GRAPHICS_BACKEND=backend, POKEPORT_IDENTITY=identity, POKEPORT_NO_DISCORD='1')
            with (out / (name + '.log')).open('w') as log:
                result = storage.run([str(binary.resolve()), str(source / 'tools/companion-runtime/host')],
                                     cwd=source, env=env, stdout=log, stderr=log, timeout=120)
            print(name, result.returncode, flush=True)
            if result.returncode or not report.exists():
                print((out / (name + '.log')).read_text()[-5000:])
                raise SystemExit(result.returncode or 1)
            evidence = json.loads(report.read_text())
            if not evidence.get('passed') or evidence.get('backend') != backend:
                raise SystemExit('GPU host did not verify the requested renderer')
            runs.append(dict(binary=str(binary.resolve()), **evidence))
    (out / 'receipt.json').write_text(json.dumps(dict(head=head, runs=runs), indent=2) + '\n')
    print('PASS', head, out)

if __name__ == '__main__':
    main()
