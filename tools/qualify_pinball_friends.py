#!/usr/bin/env python3
"""ROM-free synthetic friend-service and existing link regressions, by Roxas2712.

This does not contact or qualify the live ModCompass backend.
"""
import argparse
import atexit
import os
from pathlib import Path
import shutil
import sys

ROOT=Path(__file__).resolve().parents[1]

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--lua',default='lua')
    parser.add_argument('--love',type=Path,help='Use the actual LÖVE LuaJIT runtime, including launcher UI regression.')
    args=parser.parse_args()
    executable=str(args.love.expanduser().resolve(strict=True))if args.love else shutil.which(args.lua)
    if not executable:parser.error('Lua executable unavailable; supply --lua /path/to/lua.')
    installed=Path.home()/'.local/lib/origami-qa-storage/active-tools'
    sys.path.insert(0,str(installed if installed.is_dir()else ROOT/'tools'))
    import qa_storage as qa
    qa._storage=qa.Storage(ROOT);atexit.register(qa._storage.close,collect=False)
    qa.qa_source(ROOT);qa.qa_source(Path(executable));qa.qa_source(Path(sys.executable))
    for parent in Path(executable).parents:
        if parent.suffix=='.app':qa.qa_source(parent);break
    profiles={}
    if args.love:
        # conf.lua identities are private to this headless test harness.
        for name in ('pinball_friends_test','run_pinball_duel_tests','friend_play','cloud_net','friends_menu','account_workspace','header_account'):
            identity='oasc-pinball-qa-friends-'+name
            if sys.platform=='darwin':profile=Path.home()/'Library/Application Support/LOVE'/identity
            elif os.name=='nt':profile=Path(os.environ['APPDATA'])/identity
            else:profile=Path(os.getenv('XDG_DATA_HOME',str(Path.home()/'.local/share')))/'love'/identity
            qa.qa_source(profile);profiles[name]=(identity,profile)
    cache=ROOT/'.local/qa/pinball-friends';qa.qa_cache(cache);cache.mkdir(parents=True,exist_ok=True)
    suites=('tests/pinball_friends_test.lua','tests/run_pinball_duel_tests.lua',
            'tests/engine/friend_play.lua','tests/engine/cloud_net.lua','tests/engine/friends_menu.lua',
            'tests/engine/account_workspace.lua')
    if args.love:suites+=('tests/engine/header_account.lua',)
    for suite in suites:
        command=[executable,suite]
        if args.love:
            name=Path(suite).stem;identity,profile=profiles[name];qa.qa_profile(profile)
            host=ROOT/'.local/engine-parity'/('pinball-friends-'+name)
            qa.qa_copy(host,ephemeral=True);host.mkdir(parents=True,exist_ok=True)
            for item in ('src','tests','data','assets','tools','mods','icons'):
                if not(host/item).exists():(host/item).symlink_to(ROOT/item,target_is_directory=True)
            (host/'conf.lua').write_text("function love.conf(t)t.identity="+repr(identity)+";t.window=false;t.modules.graphics=false;t.modules.audio=false;t.modules.physics=false;t.modules.joystick=false;t.modules.video=false end")
            (host/'main.lua').write_text("local runtime=love\nfunction love.load()\nlocal ok,why=pcall(function()assert(loadfile("+repr(suite)+"))()end)\nlove=runtime\nif not ok then print(why)end\nruntime.event.quit(ok and 0 or 1)\nend\n")
            command=[executable,str(host)]
        log=cache/(Path(suite).stem+'.log')
        with log.open('w')as output:
            result=qa.qa_run(command,cwd=ROOT,stdout=output,stderr=output,timeout=60)
        print(log.read_text()[-5000:],flush=True)
        if result.returncode:return result.returncode
    return 0

if __name__=='__main__':raise SystemExit(main())
