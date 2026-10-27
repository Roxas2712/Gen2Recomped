"""Limits for the explicit X/Y recompiler output; retain generated C and games.

Integration by Roxas2712. Call while holding the backend's session.lock.
Only matching C compiler object intermediates after successful linking may go.
"""
import re
import fcntl
from pathlib import Path
from qa_storage import GIB
from qa_legacy_storage import LiveUse


def clean_linked_objects(work):
    base=Path(work)/'recompiled';removed=0;live=LiveUse()
    if base.is_symlink() or base.resolve()!=base:return 0
    for output in base.glob('*'):
        if not re.fullmatch('[0-9a-f]{64}',output.name) or output.is_symlink() or not output.is_dir():continue
        if (output/'.qa-keep').exists() or live.busy(output):continue
        if not any(p.is_file() and not p.is_symlink() for p in output.glob('0004000000055?00.dylib')):continue
        for obj in output.glob('*.o'):
            # Require the generated C peer and a final shared library. No
            # recursive suffix deletion: models named *.obj and user data stay.
            if obj.is_symlink() or not obj.is_file() or not obj.with_suffix('.c').is_file():continue
            if not re.fullmatch(r'(?:code[0-9]+|entries|runtime|recomp|[0-9a-f]{8})\.o',obj.name):continue
            if live.busy(obj):continue
            size=obj.stat().st_blocks*512;obj.unlink();removed+=size
    return removed


def prepare(storage, work, fingerprint):
    work=Path(work)
    if not re.fullmatch('[0-9a-f]{64}',fingerprint):raise ValueError('Invalid build fingerprint')
    clean_linked_objects(work)
    storage.limit_output(work/'recompiled',4*GIB)
    storage.limit_output(work/'recompiled'/fingerprint,2*GIB)


def sweep(storage):
    removed=0
    for root in set(storage._registered_roots()):
        work=root/'.local/pokemon-x'
        if not work.is_dir() or work.is_symlink():continue
        with (work/'session.lock').open('a+') as lock:
            try:fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
            except BlockingIOError:continue
            removed+=clean_linked_objects(work)
    return removed
