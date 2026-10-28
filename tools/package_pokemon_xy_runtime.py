"""Validate and embed a reviewed 3DS sidecar in a macOS application.

Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
"""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import shutil

from qa_storage import qa_source


def sha(path):
    with path.open('rb') as stream:return hashlib.file_digest(stream,'sha256').hexdigest()


def verify(root):
    root=Path(root).resolve(strict=True)
    metadata=json.loads((root/'runtime.json').read_text())
    if metadata.get('schema')!=1 or metadata.get('bridge_protocol')!=1 or metadata.get('platform')!='macos-arm64':
        raise ValueError('Unsupported 3DS runtime manifest.')
    files=json.loads((root/'files.json').read_text())
    if not isinstance(files,dict) or not files:
        raise ValueError('Missing 3DS runtime inventory.')
    for name,digest in files.items():
        path=PurePosixPath(name)
        if path.is_absolute() or '..' in path.parts:
            raise ValueError('Unsafe runtime path.')
        if path.suffix.lower() in {'.3ds','.cxi','.cia','.cci','.gb','.gbc','.gba','.nds','.sav','.srm','.state'} or any(p in {'decrypted','recompiled','player','saves','savestates'} for p in path.parts):
            raise ValueError('Game data is not a runtime component: '+name)
        source=root/name
        if not source.is_file() or sha(source)!=digest:
            raise ValueError('Changed runtime component: '+name)
    for path in root.rglob('*'):
        if path.is_symlink():
            if not path.resolve(strict=True).is_relative_to(root):
                raise ValueError('Runtime symlink escapes its bundle.')
        elif path.is_file() and path.name not in {'runtime.json','files.json'} and str(path.relative_to(root)) not in files:
            raise ValueError('Unlisted runtime file: '+str(path.relative_to(root)))
    for name,digest in metadata['artifacts'].items():
        if files.get(name)!=digest:
            raise ValueError('Runtime identity does not match its inventory.')
    identity=dict(metadata);expected=identity.pop('id')
    actual=hashlib.sha256(json.dumps(identity,sort_keys=True,separators=(',',':')).encode()).hexdigest()
    if actual!=expected:
        raise ValueError('Runtime identity digest mismatch.')
    return metadata


def install(runtime,app):
    runtime=Path(runtime).resolve(strict=True);app=Path(app).resolve(strict=True)
    qa_source(runtime)
    metadata=verify(runtime)
    resources=app/'Contents/Resources'
    if not (resources/'game.love').is_file():
        raise ValueError('Select a packaged LÖVE macOS application.')
    target=resources/'3ds-runtime'
    if target.exists():
        raise ValueError('Existing bundled runtime is preserved; build a new application.')
    shutil.copytree(runtime,target,symlinks=True)
    verify(target)
    return {'id':metadata['id'],'platform':metadata['platform'],'editions':metadata['editions'],'minimumMacOS':metadata['minimum_macos']}


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runtime',type=Path,required=True);parser.add_argument('--app',type=Path,required=True)
    args=parser.parse_args()
    print(json.dumps(install(args.runtime,args.app)),flush=True)
