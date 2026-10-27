"""Bound JSON report files and preserve full evidence in verified gzip streams."""
import gzip
import hashlib
import json
import os
from pathlib import Path
import shutil
import tempfile

MIB=1024**2


def _signature(path):
    s=path.stat();return s.st_ino,s.st_size,s.st_mtime_ns,s.st_ctime_ns


def _digest(stream):
    h=hashlib.sha256();size=0
    for chunk in iter(lambda:stream.read(MIB),b''):h.update(chunk);size+=len(chunk)
    return h.hexdigest(),size


def _publish(path, temporary, digest, size, passed=None):
    archive=path.with_suffix(path.suffix+'.gz')
    with gzip.open(temporary,'rb') as stream:verified=_digest(stream)
    if verified!=(digest,size):raise RuntimeError('Compressed report verification failed')
    if archive.exists():
        with gzip.open(archive,'rb') as stream:
            same=_digest(stream)==(digest,size)
        if same:Path(temporary).unlink()
        else:
            # Keep one previous compressed generation, never grow raw reports.
            previous=archive.with_suffix('.previous.gz')
            archive.replace(previous);os.link(temporary,archive);Path(temporary).unlink()
    else:os.link(temporary,archive);Path(temporary).unlink()
    return dict(format='compressed-qa-report-v1',archive=archive.name,
                sha256=digest,original_bytes=size,passed=passed)


def compress_report(path):
    """Verify a byte-exact compressed copy before replacing raw JSON by an index."""
    path=Path(path)
    if path.is_symlink() or not path.is_file() or path.resolve()!=path:raise ValueError('Unsafe report path')
    before=_signature(path)
    with path.open('rb') as stream:
        if before[1]<32*MIB:return 0
        first=stream.read(200)
        if b'compressed-qa-report-v1' in first:return 0
        stream.seek(max(0,before[1]-4096));tail=stream.read()
        import re
        match=re.search(rb'"passed"\s*:\s*(true|false)\s*}\s*$',tail)
        passed=(match[1]==b'true') if match else None
    fd,tmp=tempfile.mkstemp(prefix='.qa-report-',dir=path.parent);os.close(fd)
    h=hashlib.sha256();size=0
    try:
        with path.open('rb') as source,gzip.open(tmp,'wb',compresslevel=1) as output:
            for chunk in iter(lambda:source.read(MIB),b''):h.update(chunk);size+=len(chunk);output.write(chunk)
        with open(tmp,'rb') as stream:os.fsync(stream.fileno())
        index=_publish(path,tmp,h.hexdigest(),size,passed)
        if _signature(path)!=before:raise RuntimeError('Report changed during compression')
        pending=path.with_name('.'+path.name+'.index-'+str(os.getpid()))
        pending.write_text(json.dumps(index,indent=2)+'\n');pending.replace(path)
        return size-path.stat().st_size-path.with_suffix(path.suffix+'.gz').stat().st_size
    finally:
        Path(tmp).unlink(missing_ok=True)


def write_report(report,path,*,threshold=32*MIB,max_raw=4*1024*MIB,max_compressed=128*MIB):
    """Stream JSON; large reports never create a multi-GB uncompressed file."""
    path=Path(path);path.parent.mkdir(parents=True,exist_ok=True)
    fd,tmp=tempfile.mkstemp(prefix='.qa-report-',dir=path.parent);raw=os.fdopen(fd,'wb')
    output=None;h=hashlib.sha256();size=0
    try:
        for value in json.JSONEncoder(indent=2).iterencode(report):
            data=value.encode();size+=len(data);h.update(data)
            if size>max_raw:raise RuntimeError('Uncompressed QA report budget exceeded')
            if output is None and size>threshold:
                raw.close();prefix=Path(tmp).read_bytes();raw=open(tmp,'wb');output=gzip.GzipFile(fileobj=raw,mode='wb',compresslevel=1)
                output.write(prefix)
            (output or raw).write(data)
            if output is not None and raw.tell()>max_compressed:raise RuntimeError('Compressed QA report budget exceeded')
        data=b'\n';size+=1;h.update(data)
        if size>max_raw:raise RuntimeError('Uncompressed QA report budget exceeded')
        (output or raw).write(data)
        if output is not None:output.close()
        if output is not None and raw.tell()>max_compressed:raise RuntimeError('Compressed QA report budget exceeded')
        raw.flush();os.fsync(raw.fileno());raw.close()
        if output is None:Path(tmp).replace(path)
        else:
            # A new generation replaces the previous full report only after
            # verification. Keep a conflicting older archive for inspection.
            index=_publish(path,tmp,h.hexdigest(),size,report.get('passed'))
            pending=path.with_name('.'+path.name+'.index-'+str(os.getpid()))
            pending.write_text(json.dumps(index,indent=2)+'\n');pending.replace(path)
        return path
    finally:
        if output is not None:output.close()
        raw.close();Path(tmp).unlink(missing_ok=True)
