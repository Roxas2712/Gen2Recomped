#!/usr/bin/env python3
"""Check actual macOS worker focus/pause QoS without opening a window.

Requires a prepared private native installation. Contributions by Roxas2712.
"""
import argparse
import atexit
import json
import os
from pathlib import Path
import sys

ROOT=Path(__file__).resolve().parents[1]

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--love',type=Path,required=True)
    args=parser.parse_args()
    if sys.platform!='darwin':parser.error('This check exercises macOS QoS.')
    love=args.love.expanduser().resolve(strict=True)
    work=ROOT/'.local/pinball-rs'
    manifest=work/'library.json';session=json.loads(manifest.read_text())
    helper=Path.home()/'.local/lib/origami-qa-storage/active-tools'
    sys.path.insert(0,str(helper if helper.is_dir()else ROOT/'tools'))
    import qa_storage as qa
    qa._storage=qa.Storage(ROOT);atexit.register(qa._storage.close,collect=False)
    identity='oasc-pinball-qa-priority'
    profile=Path.home()/'Library/Application Support/LOVE'/identity
    for path in (ROOT,work,love,profile,Path(sys.executable)):qa.qa_source(path)
    for parent in love.parents:
        if parent.suffix=='.app':qa.qa_source(parent);break
    for key in ('rom','bios','bridge'):qa.qa_source(Path(session[key]))
    qa.qa_profile(profile)
    cache=ROOT/'.local/qa/pinball-priority';qa.qa_cache(cache);cache.mkdir(parents=True,exist_ok=True)
    host=ROOT/'.local/engine-parity/pinball-priority';qa.qa_copy(host,ephemeral=True);host.mkdir(parents=True,exist_ok=True)
    for name in ('src','tests'):
        if not(host/name).exists():(host/name).symlink_to(ROOT/name,target_is_directory=True)
    (host/'conf.lua').write_text("function love.conf(t)t.identity="+repr(identity)+";t.window=false;t.modules.graphics=false;t.modules.audio=false;t.modules.physics=false;t.modules.video=false end")
    (host/'main.lua').write_text("function love.load()local ok,why=pcall(function()assert(loadfile('tests/pinball_worker_priority.lua'))()end);if not ok then print(why)end;love.event.quit(ok and 0 or 1)end")
    env=dict(os.environ,PINBALL_PRIORITY_MANIFEST=str(manifest));env.pop('ASCENDANT_PINBALL_DEFAULT_QOS',None)
    log=cache/'run.log'
    with log.open('w')as output:result=qa.qa_run([str(love),str(host)],cwd=ROOT,env=env,stdout=output,stderr=output,timeout=45)
    print(log.read_text()[-2500:]);return result.returncode

if __name__=='__main__':raise SystemExit(main())
