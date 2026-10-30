#!/usr/bin/env python3
"""Two native GBC Pinball clients, real localhost transport and opponent video."""
import argparse
import atexit
import asyncio
import importlib.util
import json
import os
from pathlib import Path
import shutil
import socket
import sys
import threading
import time

ROOT=Path(__file__).resolve().parents[1]
def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--love',type=Path,required=True)
    p.add_argument('--mode',choices=['enet','relay'],default='enet')
    p.add_argument('--field',type=int,choices=[0,1],default=0)
    args=p.parse_args();love=args.love.expanduser().resolve(strict=True)
    sys.path.insert(0,str(Path.home()/'.local/lib/origami-qa-storage/active-tools'))
    import qa_storage as q
    q._storage=q.Storage(ROOT);atexit.register(q._storage.close,collect=False)
    identity='oasc-pinball-qa-gbc-network-'+args.mode
    profile=Path.home()/'Library/Application Support/LOVE'/identity
    manifest=ROOT/'.local/pinball-gbc/library.json';data=json.loads(manifest.read_text())
    for path in [ROOT,love,love.parents[2],profile,manifest,Path(data['rom']),Path(data['bridge']),Path(sys.executable)]:q.qa_source(path)
    out=ROOT/'.local/qa'/('pinball-gbc-network-'+args.mode);q.qa_cache(out);out.mkdir(parents=True,exist_ok=True)
    q.qa_profile(profile);profile.mkdir(parents=True,exist_ok=True)
    player=out/'empty-player';q.qa_source(player);player.mkdir(exist_ok=True)
    host=ROOT/'.local/engine-parity'/('pinball-gbc-network-'+args.mode);q.qa_copy(host,ephemeral=True);host.mkdir(parents=True,exist_ok=True)
    for name in ['src','assets','data','mods','tools']:
        if not(host/name).exists():(host/name).symlink_to(ROOT/name,target_is_directory=True)
    shutil.copy2(ROOT/'tests/pinball_gbc_network.lua',host/'main.lua')
    (host/'conf.lua').write_text("function love.conf(t)t.identity="+repr(identity)+";t.window.width=1200;t.window.height=850;t.window.vsync=1;t.modules.physics=false;love.filesystem.setSymlinksEnabled(true)end\n")
    with socket.socket(socket.AF_INET,socket.SOCK_DGRAM)as sock:sock.bind(('127.0.0.1',0));port=sock.getsockname()[1]
    loop=None;server=None
    if args.mode=='relay':
        spec=importlib.util.spec_from_file_location('pinball_relay',ROOT/'tools/pinball_relay.py');module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
        loop=asyncio.new_event_loop();thread=threading.Thread(target=loop.run_forever,daemon=True);thread.start()
        relay=module.Relay()
        server=asyncio.run_coroutine_threadsafe(asyncio.start_server(relay.client,'127.0.0.1',0,limit=32768),loop).result(10)
        port=server.sockets[0].getsockname()[1]
    report=out/'report.json'
    env=dict(os.environ,POKEPORT_IDENTITY=identity,OA_QA_IDENTITY=identity,PINBALL_NETWORK_MODE=args.mode,
        PINBALL_NETWORK_LIBRARY=str(manifest),PINBALL_NETWORK_PORT=str(port),PINBALL_NETWORK_REPORT=str(report),
        PINBALL_NETWORK_PLAYER=str(player),PINBALL_NETWORK_FIELD=str(args.field))
    started=time.time()
    try:
        with(out/'run.log').open('w')as log:result=q.qa_run([str(love),str(host)],cwd=ROOT,env=env,stdout=log,stderr=log,timeout=100)
    finally:
        if server:
            async def close_relay():
                server.close();await server.wait_closed()
                writers=list(relay.connections)
                for writer in writers:writer.close()
                await asyncio.gather(*(writer.wait_closed()for writer in writers),return_exceptions=True)
                await asyncio.sleep(.01)
            asyncio.run_coroutine_threadsafe(close_relay(),loop).result(10)
            loop.call_soon_threadsafe(loop.stop);thread.join(10);loop.close()
    if report.exists()and report.stat().st_mtime>=started:
        data=json.loads(report.read_text());print(json.dumps(data))
        if not data.get('passed'):return result.returncode or 1
    else:print((out/'run.log').read_text()[-5000:])
    assert not list(player.iterdir()),'Network guests must never write solo saves'
    return result.returncode
if __name__=='__main__':raise SystemExit(main())
