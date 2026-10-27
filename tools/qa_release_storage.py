"""Bound known release outputs while retaining current packages and exact members."""
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import time
import zipfile
from contextlib import ExitStack
import qa_legacy_storage as legacy
from qa_preserved import Vault


def family(path):
    name=path.name
    if re.fullmatch(r'Origami-Ascendant-[0-9.]+-macOS\.zip',name):return 'macOS'
    if re.fullmatch(r'Origami-Ascendant-[0-9.]+-iOS-experimental\.ipa',name):return 'iOS'
    if re.fullmatch(r'Origami-Ascendant-[0-9.]+-Original-API3-[A-Za-z0-9-]+-Mod\.zip',name):return 'API3-mod'
    if re.fullmatch(r'Origami-Ascendant-Gen2Recomped-[A-Za-z0-9._-]+\.zip',name) and 'candidate' not in name:
        return 'gen2-engine' if re.fullmatch(r'Origami-Ascendant-Gen2Recomped-[0-9.]+-(?:development|native-preview)\.zip',name) else 'gen2-mod'
    return None


def scope(path, root):
    path=Path(path);root=Path(root)
    if path.parent==root/'dist' and family(path):return path
    for name in ('ios-release','release-unpacked'):
        base=root/'.local'/name
        if path==base or path.is_relative_to(base):return base
    return None


def signature(path):
    s=path.lstat();return s.st_dev,s.st_ino,s.st_size,s.st_mtime_ns,s.st_ctime_ns


def protected_zip(path):
    with zipfile.ZipFile(path) as z:
        return any('.git' in Path(m.filename).parts or Path(m.filename).suffix.lower() in
                   legacy.PROTECTED_EXTS|{'.dsv','.rtc','.nds','.3ds','.cxi'} or
                   any(p in {'saves','savegames','savestates','baseroms'} for p in Path(m.filename).parts)
                   for m in z.infolist())


def plan(root, now, max_age):
    groups={};retained=[];targets=[]
    for p in (root/'dist').glob('*'):
        f=family(p)
        if f and p.is_file() and not p.is_symlink():groups.setdefault(f,[]).append(p)
    for f,paths in groups.items():
        newest=max(paths,key=lambda p:p.stat().st_mtime_ns);retained.append(newest)
        # Also retain the highest explicitly numbered mod, even if a copied
        # older package has a newer filesystem timestamp.
        numbered=[p for p in paths if re.search(r'gen2\.([0-9]+)',p.name)]
        if numbered:retained.append(max(numbered,key=lambda p:int(re.search(r'gen2\.([0-9]+)',p.name)[1])))
        if not zipfile.is_zipfile(newest):retained.extend(paths);continue
        targets.extend(p for p in paths if p not in retained)
    if 'macOS' in groups and zipfile.is_zipfile(max(groups['macOS'],key=lambda p:p.stat().st_mtime_ns)):
        targets.extend(p for p in (root/'.local/release-unpacked').glob('Origami-Ascendant-[0-9]*') if p.is_dir())
    if 'iOS' in groups and zipfile.is_zipfile(max(groups['iOS'],key=lambda p:p.stat().st_mtime_ns)):
        targets.extend(root/'.local/ios-release'/name for name in ('game.love','game-final.love','native-executable'))
    return retained,[p for p in targets if p.exists() and not p.is_symlink() and
        now-max(p.stat().st_ctime,p.stat().st_mtime)>=max_age]


def sweep(storage, *, roots=None, max_age=86400):
    result=dict(allocated_bytes=0,files=0,outputs=0,retained_busy=0,retained_packages=[])
    with (storage.state/'release-collection.lock').open('a+') as collector:
        try:fcntl.flock(collector,fcntl.LOCK_EX|fcntl.LOCK_NB)
        except BlockingIOError:return result
        live=legacy.LiveUse()
        with ExitStack() as stack:
            vault=None
            for root in sorted(set(roots or storage._registered_roots())):
                root=Path(root)
                if root.is_symlink() or (root/'.qa-keep').exists():continue
                kept,targets=plan(root,storage.clock(),max_age)
                result['retained_packages'].extend(map(str,kept))
                for path in targets:
                    if path.resolve()!=path or legacy.kept(path) or live.busy(path):continue
                    scope_path=scope(path,root)
                    key=storage._key(scope_path)
                    if key in storage.held:continue
                    with (storage.state/(key+'.lock')).open('a+') as lock:
                        try:fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
                        except BlockingIOError:result['retained_busy']+=1;continue
                        try:
                            rows=[(p,s) for p,s in legacy.files(path) if p.suffix.lower() not in {'.dsv','.rtc'} and
                                  not re.search(r'\.(?:sav|srm|state|dsv|rtc)(?:[0-9]+|[._-].*)?$',p.name,re.I) and
                                  not re.fullmatch(r'save_[^.]+\.lua',p.name) and
                                  'profiles' not in p.relative_to(path).parts[:-1]] if path.is_dir() else list(legacy.files(path))
                            if not rows:continue
                            if any(storage.clock()-max(s.st_ctime,s.st_mtime)<max_age for _,s in rows):continue
                            zipped=path.is_file() and path.suffix in {'.zip','.love','.ipa'}
                            if zipped and protected_zip(path):continue
                            before={p:signature(p) for p,_ in rows}
                            if vault is None:vault=stack.enter_context(Vault(storage.home))
                            proof=vault.capture_zip(path) if zipped else vault.capture(path,paths=[p for p,_ in rows]) if path.is_dir() else vault.capture(path)
                            # Keep the newest package decision fresh across a slow capture.
                            current_kept,_=plan(root,storage.clock(),max_age)
                            if path in current_kept or live.busy(path) or legacy.kept(path):continue
                            if any(signature(p)!=s for p,s in before.items()):continue
                            receipts=storage.state/'release-receipts';receipts.mkdir(exist_ok=True)
                            receipt=receipts/(storage._key(path)+'-'+proof['commit']+'.json')
                            temp=receipt.with_suffix('.tmp');temp.write_text(json.dumps(dict(path=str(path),preserved=proof),indent=2));temp.replace(receipt)
                            for p,s in rows:
                                if p.parent.resolve()!=p.parent or p.lstat().st_uid!=os.getuid():raise ValueError('Changed output ancestor/owner')
                                p.unlink();result['allocated_bytes']+=s.st_blocks*512;result['files']+=1
                            if path.is_dir():
                                parents=set()
                                for p,_ in rows:
                                    folder=p.parent
                                    while folder.is_relative_to(path):
                                        if folder in parents:break
                                        parents.add(folder);folder=folder.parent
                                for folder in sorted(parents,key=lambda p:len(p.parts),reverse=True):
                                    if folder.is_dir() and not any(folder.iterdir()) and folder.name not in legacy.PROTECTED_DIRS:folder.rmdir()
                            result['outputs']+=1
                            print('[qa-release] archived and removed',path,flush=True)
                        except (OSError,ValueError,zipfile.BadZipFile) as error:
                            print('[qa-release] retained for retry',path,str(error),flush=True)
    return result
