"""Expire generated imports in explicitly scoped LÖVE test profiles only."""
from contextlib import ExitStack
import fcntl
import json
import os
from pathlib import Path
import re
import stat
import time

import qa_legacy_storage as legacy

EDITIONS = ('red','blue','yellow','gold','silver','crystal','heartgold','soulsilver',
            'firered','leafgreen','ruby','sapphire','emerald')
KEEP_DIRS = legacy.PROTECTED_DIRS | {'models','model','src','source','sources','mods'}
KEEP_EXTS = legacy.PROTECTED_EXTS | {'.blend','.obj','.fbx','.glb','.gltf','.dae','.stl','.ply','.vox','.bbmodel'}
SAVE = re.compile(r'\.(?:sav|srm|state|dsv|rtc)(?:[0-9]+|[._-].*)?$', re.I)


def test_profile(name):
    return (legacy.qa_profile(name) or
            re.fullmatch(r'portemon-private-[0-9a-f]{16}',name) is not None or
            re.fullmatch(r'gen2-palette-gpu-[A-Za-z0-9_-]+',name) is not None)


def profile_scope(path, home):
    """Return the outer, explicitly disposable identity; never a player profile."""
    base=Path(home)/'Library/Application Support/LOVE';path=Path(path)
    if not path.is_relative_to(base):return None
    parts=path.relative_to(base).parts
    if not parts or not test_profile(parts[0]):return None
    profile=base/parts[0]
    return profile if profile.resolve()==profile else None


def profiles(home, only=None):
    base=Path(home)/'Library/Application Support/LOVE'
    if not base.is_dir() or base.resolve()!=base:return
    for outer in base.iterdir() if only is None else sorted(only):
        if outer.parent!=base:continue
        if not outer.is_dir() or outer.is_symlink() or not test_profile(outer.name):continue
        yield outer,outer
        # Known isolated-home QA hosts put their actual profile outside LOVE.
        isolated=outer/'isolated-home/Library/Application Support'
        if isolated.resolve()!=isolated or not isolated.is_dir():continue
        for child in isolated.iterdir():
            if child.name=='LOVE' and child.is_dir() and not child.is_symlink():
                for inner in child.iterdir():
                    if inner.is_dir() and not inner.is_symlink():yield outer,inner
            elif (re.fullmatch(r'Gen2Recomp-NativePreview-[A-Za-z0-9_-]+',child.name)
                  and child.is_dir() and not child.is_symlink()):yield outer,child


def signature(info):
    return info.st_ino,info.st_size,info.st_mtime_ns,info.st_ctime_ns


def protected(cache):
    """Legacy import collectors must leave a mixed model/save tree intact."""
    for folder,dirs,names in os.walk(cache,followlinks=False):
        if any(d.lower() in KEEP_DIRS or (Path(folder)/d).is_symlink() for d in dirs):return True
        if any(n in {'.qa-keep','.git'} or Path(n).suffix.lower() in KEEP_EXTS or SAVE.search(n) for n in names):return True
    return False


def rows(cache):
    if cache.resolve()!=cache or not cache.is_dir():return
    for folder,dirs,names in os.walk(cache,followlinks=False):
        folder=Path(folder)
        if '.qa-keep' in names or '.git' in names or '.git' in dirs:
            dirs[:]=[];continue
        dirs[:]=[d for d in dirs if d.lower() not in KEEP_DIRS and not (folder/d).is_symlink()]
        for name in names:
            p=folder/name
            if (p.suffix.lower() in KEEP_EXTS or SAVE.search(name) or
                    name in {'.qa-keep','qa-preserved-sources.json'}):continue
            info=p.lstat()
            if stat.S_ISREG(info.st_mode) and info.st_uid==os.getuid():yield p,info


def aliases(storage):
    found=[]
    for root in set(storage._registered_roots()):
        imports=root/'.local/imports'
        for path in (imports,*(imports/e for e in EDITIONS)):
            if path.is_symlink():found.append(path.resolve())
    return found


def kept(profile, outer):
    return any((p/'.qa-keep').exists() or (p/'.git').exists()
               for p in (profile,*profile.parents) if p==outer or p.is_relative_to(outer))


def acquire(storage, stack, scopes, held):
    for scope in dict.fromkeys(scopes):
        key=storage._key(scope)
        if key in storage.held:return False
        if key in held:continue
        lock=stack.enter_context((storage.state/(key+'.lock')).open('a+'))
        try:fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        except BlockingIOError:return False
        held.add(key)
    return True


def cache_rows(profile):
    return [(p,s) for e in EDITIONS for rel in ('data/generated','assets/generated')
            for p,s in rows(profile/e/rel)]


def sweep(storage, *, max_age=86400, limit=2*1024**3, min_age=3600,
          live=None, clock=time.time, wait=False, only=None):
    """Archive exact cache bytes, then remove idle old data; models/saves stay put."""
    live=live or legacy.LiveUse();home=storage.home
    result=dict(logical_bytes=0,files=0,profiles=0,retained_busy=0)
    with ExitStack() as locks:
        if only is None:
            collector=locks.enter_context((storage.state/'collection.lock').open('a+'))
            try:fcntl.flock(collector,fcntl.LOCK_EX if wait else fcntl.LOCK_EX|fcntl.LOCK_NB)
            except BlockingIOError:return result
        pinned=aliases(storage);inventory=[]
        for outer,profile in profiles(home,only=only):
            try:
                if kept(profile,outer) or any(p.is_relative_to(outer) or outer.is_relative_to(p) for p in pinned):continue
                with ExitStack() as lease:
                    if not acquire(storage,lease,(outer,profile),set()) or live.busy(outer) or live.busy(profile):
                        result['retained_busy']+=1;continue
                    plan=cache_rows(profile)
                    if not plan:continue
                    updated=max(max(s.st_mtime,s.st_ctime) for _,s in plan)
                    inventory.append((updated,outer,profile,sum(s.st_blocks*512 for _,s in plan),len(plan)))
            except (OSError,ValueError):continue
        total=sum(size for _,_,_,size,_ in inventory)
        selected=[];held=set();files=0
        for updated,outer,profile,size,count in sorted(inventory,key=lambda r:(r[0],str(r[2]))):
            age=clock()-updated
            if age<min_age or (age<max_age and total<=limit):continue
            # Bound open descriptors and archive memory on large old test suites.
            if selected and (len(selected)>=48 or files+count>100000):break
            if not acquire(storage,locks,(outer,profile),held):continue
            plan=cache_rows(profile)
            if not plan or max(max(s.st_mtime,s.st_ctime) for _,s in plan)!=updated:continue
            selected.append((outer,profile,plan));total-=size;files+=len(plan)
        if not selected:return result
        # One snapshot/pack per sweep, rather than thousands of small archives.
        if selected:
            # Archive the explicit file list directly. Staging hundreds of
            # thousands of hardlinks needlessly dirties APFS metadata/ctimes.
            for _,_,plan in selected:
                for p,info in plan:
                    if p.parent.resolve()!=p.parent or signature(p.lstat())!=signature(info):
                        raise RuntimeError('Generated import changed before preservation')
            from qa_preserved import Vault
            with Vault(home) as vault:
                proof=vault.capture(home,paths=[p for _,_,plan in selected for p,_ in plan])
            receipts=storage.state/'love-receipts';receipts.mkdir(exist_ok=True)
            receipt=receipts/(proof['commit']+'.json');temp=receipt.with_suffix('.tmp')
            temp.write_text(json.dumps(dict(archive=proof,profiles=[str(p) for _,p,_ in selected]),indent=2))
            temp.replace(receipt)
            pinned=aliases(storage)
            for outer,profile,plan in selected:
                if (kept(profile,outer) or live.busy(outer) or live.busy(profile) or
                        any(p.is_relative_to(outer) or outer.is_relative_to(p) for p in pinned)):
                    result['retained_busy']+=1;continue
                if any(signature(p.lstat())!=signature(s) or p.parent.resolve()!=p.parent for p,s in plan):continue
                changed_editions={p.relative_to(profile).parts[0] for p,_ in plan}
                for edition in changed_editions:
                    marker=profile/edition/'rom-cache.complete'
                    if marker.is_file() and not marker.is_symlink():marker.unlink()
                for p,info in plan:
                    parent=p.parent;parent_info=parent.stat()
                    if parent_info.st_uid!=os.getuid():raise PermissionError('Foreign cache parent')
                    parent.chmod(stat.S_IMODE(parent_info.st_mode)|0o700)
                    p.unlink();result['files']+=1;result['logical_bytes']+=info.st_blocks*512
                result['profiles']+=1
                # Leave model/saves/keep subtrees and every new file untouched.
                parents={p for file,_ in plan for p in file.parents if p!=profile and p.is_relative_to(profile)}
                for folder in sorted(parents,key=lambda p:len(p.parts),reverse=True):
                    if folder.is_dir() and not any(folder.iterdir()):folder.rmdir()
        return result
