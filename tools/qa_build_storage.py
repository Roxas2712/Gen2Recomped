"""Limits for the explicit X/Y recompiler output; retain generated C and games.

Integration by Roxas2712. Call while holding the backend's session.lock.
Only matching C compiler object intermediates after successful linking may go.
"""
import re
import os
if os.name != 'nt':import fcntl
import hashlib
import json
from pathlib import Path
if os.name == 'nt':GIB=1024**3
else:from qa_storage import GIB
from qa_legacy_storage import LiveUse


def _digest(path):
    value=hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda:stream.read(1024*1024),b''):value.update(block)
    return value.hexdigest()


def retire_compiler_manifests(work):
    """Preserve Zig manifests outside its lookup path before retiring objects.

    Zig's manifests do not expose their resulting artifact keys. Invalidate all
    owned local manifests under session.lock: a manifest for another source can
    refer to the same deduplicated object. Leaving it behind can make Zig emit a
    zero-byte output while returning success on a later compile.
    """
    cache=Path(work)/'compiler-cache'
    manifests=cache/'local/h';retired=cache/'retired-manifests'
    if not manifests.exists():return 0
    if cache.resolve()!=cache or manifests.resolve()!=manifests:
        raise ValueError('Refusing redirected compiler-cache manifests')
    if retired.exists() and (retired.is_symlink() or not retired.is_dir()):
        raise ValueError('Refusing redirected retired compiler manifests')
    retired.mkdir(exist_ok=True)
    count=0
    for source in manifests.iterdir():
        if source.is_symlink() or not source.is_file() or not re.fullmatch('[0-9a-f]{32,64}\\.txt',source.name):continue
        target=retired/(_digest(source)+'.txt')
        if target.exists():
            if target.is_symlink() or not target.is_file() or _digest(target)!=target.stem:
                raise ValueError('Retired compiler manifest changed')
            source.unlink()
        else:source.rename(target)
        count+=1
    return count


def clean_compiler_duplicates(work, output):
    """Retire only cached objects identical to owned, linked C intermediates.

    Keep generated C, the final library, unrelated cache files and live data.
    Call under session.lock after committing the final library marker, before
    clean_linked_objects removes the original object peers.
    """
    work,output=Path(work),Path(output)
    cache=work/'compiler-cache/local/o'
    if (output.parent!=work/'recompiled' or not re.fullmatch('[0-9a-f]{64}',output.name)
            or output.resolve()!=output or not cache.is_dir() or cache.resolve()!=cache):return 0
    live=LiveUse()
    if (output/'.qa-keep').exists() or live.busy(output) or live.busy(cache):return 0
    committed=False
    for binary in output.glob('0004000000055?00.dylib'):
        if binary.is_symlink():continue
        try:
            marker=json.loads(binary.with_suffix('.complete.json').read_text())
            if marker.get('sha256')==_digest(binary):committed=True;break
        except (OSError,ValueError):continue
    if not committed:return 0
    objects={}
    for obj in output.glob('*.o'):
        if (not obj.is_symlink() and obj.is_file() and obj.with_suffix('.c').is_file()
                and re.fullmatch(r'(?:code[0-9]+|entries|runtime|recomp|[0-9a-f]{8})\.o',obj.name)):
            objects[obj.name]=(obj.stat().st_size,_digest(obj))
    candidates=[]
    for folder in cache.iterdir():
        if not re.fullmatch('[0-9a-f]{32,64}',folder.name) or not folder.is_dir() or folder.is_symlink():continue
        for obj in folder.glob('*.o'):
            expected=objects.get(obj.name)
            if (expected and not obj.is_symlink() and obj.is_file() and obj.stat().st_size==expected[0]
                    and not live.busy(obj) and _digest(obj)==expected[1]):
                candidates.append((obj,expected))
    if not candidates:return 0
    # Invalidate cache lookups first, preserving the metadata byte for byte.
    # An interruption now causes recompilation, never dangling cache lookups.
    retire_compiler_manifests(work)
    removed=0
    for obj,expected in candidates:
        if (not obj.is_symlink() and obj.is_file() and obj.stat().st_size==expected[0]
                and _digest(obj)==expected[1]):
            size=obj.stat().st_blocks*512;obj.unlink();removed+=size
    return removed


def clean_linked_objects(work):
    base=Path(work)/'recompiled';removed=0;live=LiveUse()
    if base.is_symlink() or base.resolve()!=base:return 0
    for output in base.glob('*'):
        if not re.fullmatch('[0-9a-f]{64}',output.name) or output.is_symlink() or not output.is_dir():continue
        if (output/'.qa-keep').exists() or (os.name!='nt' and live.busy(output)):continue
        binaries=list(output.glob('0004000000055?00.'+('dll' if os.name=='nt' else 'dylib')))
        if not any(p.is_file() and not p.is_symlink() for p in binaries):continue
        if os.name=='nt':
            # Called only under the backend's exclusive session lock. Require
            # the committed library digest before retiring its generated peers.
            try:
                if not any(json.loads(p.with_suffix('.complete.json').read_text()).get('sha256')==_digest(p) for p in binaries):continue
            except (OSError,ValueError):continue
        for obj in output.glob('*.o'):
            # Require the generated C peer and a final shared library. No
            # recursive suffix deletion: models named *.obj and user data stay.
            if obj.is_symlink() or not obj.is_file() or not obj.with_suffix('.c').is_file():continue
            if not re.fullmatch(r'(?:code[0-9]+|entries|runtime|recomp|[0-9a-f]{8})\.o',obj.name):continue
            if os.name!='nt' and live.busy(obj):continue
            size=getattr(obj.stat(),'st_blocks',0)*512 or obj.stat().st_size
            try:obj.unlink()
            except PermissionError:continue
            removed+=size
    return removed


def prepare(storage, work, fingerprint):
    work=Path(work)
    if not re.fullmatch('[0-9a-f]{64}',fingerprint):raise ValueError('Invalid build fingerprint')
    clean_linked_objects(work)
    storage.limit_output(work/'recompiled',4*GIB)
    storage.limit_output(work/'recompiled'/fingerprint,2*GIB)


def sweep(storage):
    if os.name=='nt':return 0
    removed=0
    for root in set(storage._registered_roots()):
        work=root/'.local/pokemon-x'
        if not work.is_dir() or work.is_symlink():continue
        with (work/'session.lock').open('a+') as lock:
            try:fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
            except BlockingIOError:continue
            removed+=clean_linked_objects(work)
    return removed
