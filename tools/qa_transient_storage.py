"""Explicit idle Cargo outputs, obsolete preview copies and large QA reports."""
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import time
from contextlib import contextmanager
import qa_legacy_storage as legacy
from qa_preserved import Vault
from qa_report_storage import compress_report

SOURCE_EXTS={'.rs','.c','.h','.cpp','.hpp','.lua','.py','.toml','.md','.json','.txt','.lock'}
MODEL_EXTS={'.obj','.blend','.glb','.gltf','.fbx','.vox','.dae','.stl','.ply','.bbmodel'}
SAVE=re.compile(r'\.(?:sav|srm|state|dsv|rtc)(?:[0-9]+|[._-].*)?$',re.I)


def digest(path):
    h=hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda:stream.read(1024**2),b''):h.update(chunk)
    return h.hexdigest()


def signature(p):
    s=p.lstat();return s.st_ino,s.st_size,s.st_mtime_ns,s.st_ctime_ns


@contextmanager
def leases(storage,paths):
    handles=[]
    try:
        for p in dict.fromkeys(paths):
            key=storage._key(p)
            if key in storage.held:
                if storage.held[key][2]:continue
                yield False;return
            f=(storage.state/(key+'.lock')).open('a+');handles.append(f)
            try:fcntl.flock(f,fcntl.LOCK_EX|fcntl.LOCK_NB)
            except BlockingIOError:yield False;return
        yield True
    finally:
        for f in handles:f.close()


def clean_cargo(storage,root,*,min_age=3600,live=None):
    root=Path(root);base=root/'.local/qa/pokemon-x-feasibility';target=base/'target'
    installed=root/'.local/pokemon-x/bin/libascendant_3ds_bridge.dylib'
    linked=target/'release/libascendant_3ds_bridge.dylib';live=live or legacy.LiveUse()
    if (target.resolve()!=target or not target.is_dir() or legacy.kept(target) or
        not linked.is_file() or not installed.is_file()):return 0
    with leases(storage,[base,target]) as available:
        if not available or live.busy(target):return 0
        if digest(installed)!=digest(linked):return 0
        rows=list(legacy.files(target))
        if not rows or time.time()-max(max(s.st_ctime,s.st_mtime) for _,s in rows)<min_age:return 0
        plan=[]
        for p,s in rows:
            if p==linked or not stat.S_ISREG(s.st_mode):continue
            if p.suffix.lower() in SOURCE_EXTS|MODEL_EXTS or SAVE.search(p.name):continue
            if any(part.lower() in {'models','src','sources','saves','profiles','hd-content'} for part in p.relative_to(target).parts):continue
            compiled=p.suffix in {'.o','.rlib','.rmeta','.d','.a','.so','.dylib','.exe'}
            if not compiled and s.st_mode&0o111:
                with p.open('rb') as stream:compiled=stream.read(4) in {b'\x7fELF',b'\xcf\xfa\xed\xfe',b'\xce\xfa\xed\xfe',b'\xfe\xed\xfa\xcf',b'\xca\xfe\xba\xbe'}
            if compiled:
                plan.append((p,s,signature(p)))
        removed=0
        for p,s,before in plan:
            if signature(p)!=before:continue
            p.unlink();removed+=s.st_blocks*512
        return removed


def clean_previews(storage,root,*,min_age=3600,live=None):
    root=Path(root);live=live or legacy.LiveUse();runs=[]
    for run in (root/'.local/qa').glob('native-qualified-preview-*'):
        if re.fullmatch(r'native-qualified-preview-[0-9]+',run.name) and run.is_dir() and run.resolve()==run:runs.append(run)
    if len(runs)<2:return 0
    keep={max(runs,key=lambda p:int(p.name.rsplit('-',1)[1]))}
    metadata=root/'.local/state/native-qualified-preview-packages.json'
    if metadata.is_file():
        try:
            current=Path(json.loads(metadata.read_text())['root']).resolve()
            if current not in runs:return 0
            keep.add(current)
        except (OSError,ValueError,KeyError):return 0
    removed=0
    for run in runs:
        candidate=run/'candidate'
        if run in keep or not candidate.is_dir() or legacy.kept(candidate) or live.busy(run):continue
        with leases(storage,[run,candidate]) as available:
            if not available:continue
            plan=list(legacy.files(candidate))
            if not plan or time.time()-max(max(s.st_ctime,s.st_mtime) for _,s in plan)<min_age:continue
            before={p:signature(p) for p,_ in plan}
            with Vault(storage.home) as vault:proof=vault.capture(candidate,paths=[p for p,_ in plan])
            # Metadata can change while capturing a previous package generation.
            if metadata.is_file() and Path(json.loads(metadata.read_text())['root']).resolve()==run:continue
            if live.busy(run) or any(signature(p)!=s for p,s in before.items()):continue
            receipt=run/'qa-preserved-sources.json'
            data=json.loads(receipt.read_text()) if receipt.exists() else {};data['candidate']=proof
            pending=receipt.with_suffix('.tmp');pending.write_text(json.dumps(data,indent=2));pending.replace(receipt)
            for p,s in plan:
                if p.parent.resolve()!=p.parent:raise ValueError('Changed preview ancestor')
                p.unlink();removed+=s.st_blocks*512
    return removed


def sweep(storage,*,roots=None,min_age=3600):
    result={'reports_bytes':0,'cargo_bytes':0,'preview_bytes':0}
    with (storage.state/'transient-collection.lock').open('a+') as lock:
        try:fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        except BlockingIOError:return result
        live=legacy.LiveUse()
        for root in set(roots or storage._registered_roots()):
            root=Path(root)
            if root.resolve()!=root or not root.is_dir() or (root/'.qa-keep').exists():continue
            result['cargo_bytes']+=clean_cargo(storage,root,min_age=min_age,live=live)
            result['preview_bytes']+=clean_previews(storage,root,min_age=min_age,live=live)
            reports=set((root/'.local/qa').glob('*/ci-artifact/enemy-action-report.json'))
            reports.update((root/'.local/qa').glob('*/enemy-action-report.json'))
            for path in reports:
                if path.resolve()!=path or path.stat().st_size<32*1024**2 or legacy.kept(path):continue
                if time.time()-max(path.stat().st_ctime,path.stat().st_mtime)<min_age or live.busy(path):continue
                run=root/'.local/qa'/path.relative_to(root/'.local/qa').parts[0]
                with leases(storage,[run,path]) as available:
                    if available:result['reports_bytes']+=compress_report(path)
    return result
