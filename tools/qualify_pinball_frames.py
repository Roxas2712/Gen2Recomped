#!/usr/bin/env python3
"""Measure actual displayed Pinball images in the normal launcher loop.

Requires a private prepared installation and LÖVE. Contributions by Roxas2712.
Does not certify other devices, every game scene, or an absence of stutters.
"""
import argparse
import atexit
import json
import os
from pathlib import Path
import re
import shutil
import sys
import time

ROOT=Path(__file__).resolve().parents[1]

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--love',type=Path,required=True)
    parser.add_argument('--label',default='current')
    parser.add_argument('--seconds',type=int,default=40)
    parser.add_argument('--seats',type=int,choices=(1,2),default=1)
    parser.add_argument('--full-table',action='store_true')
    parser.add_argument('--allow-background',action='store_true',help='Measure continued native playback without focus; do not auto-pause.')
    parser.add_argument('--pause-unfocused',action='store_true',help='Pause and exclude background time instead of failing a long run on focus loss.')
    parser.add_argument('--field',type=int,choices=(0,1),default=0)
    parser.add_argument('--locale',choices=('en','fr','de','it','es'),default='en')
    args=parser.parse_args()
    if not re.fullmatch(r'[a-z0-9-]{1,40}',args.label)or not 10<=args.seconds<=600:
        parser.error('Use a lowercase label and 10–600 seconds.')
    executable=args.love.expanduser().resolve(strict=True)
    work=ROOT/'.local/pinball-rs'
    manifest=json.loads((work/'library.json').read_text())
    if not manifest.get('ready'):parser.error('Prepare the private Pinball installation first.')
    installed=Path.home()/'.local/lib/origami-qa-storage/active-tools'
    sys.path.insert(0,str(installed if installed.is_dir()else ROOT/'tools'))
    import qa_storage as qa
    qa._storage=qa.Storage(ROOT);atexit.register(qa._storage.close,collect=False)
    identity='oasc-pinball-qa-frame-'+args.label
    if sys.platform=='darwin':profile=Path.home()/'Library/Application Support/LOVE'/identity
    elif os.name=='nt':profile=Path(os.environ['APPDATA'])/identity
    else:profile=Path(os.getenv('XDG_DATA_HOME',str(Path.home()/'.local/share')))/'love'/identity
    cache=ROOT/'.local/qa'/('pinball-frames-'+args.label)
    host=ROOT/'.local/engine-parity'/('pinball-frames-'+args.label)
    # Pin all originals before any destination may initiate collection.
    for path in (ROOT,work,executable,profile,sys.executable):qa.qa_source(path)
    for parent in executable.parents:
        if parent.suffix=='.app':qa.qa_source(parent);break
    for variant in [manifest,*manifest.get('variants',{}).values()]:
        for key in ('rom','bios','bridge','intro_assets'):
            if variant.get(key):qa.qa_source(Path(variant[key]))
    qa.qa_profile(profile);profile.mkdir(parents=True,exist_ok=True)
    qa.qa_cache(cache);cache.mkdir(parents=True,exist_ok=True)
    player=cache/'player';qa.qa_profile(player);player.mkdir(exist_ok=True)
    qa.qa_copy(host,ephemeral=True);host.mkdir(parents=True,exist_ok=True)
    (host/'src').mkdir(exist_ok=True)
    for source in (ROOT/'src').iterdir():
        target=host/'src'/source.name
        if source.name=='pinball':shutil.copytree(source,target,dirs_exist_ok=True)
        elif not target.exists():target.symlink_to(source,target_is_directory=source.is_dir())
    for name in ('assets','data','tools','mods','icons'):
        if not(host/name).exists():(host/name).symlink_to(ROOT/name,target_is_directory=True)
    shutil.copy2(ROOT/'main.lua',host/'base-main.lua')
    shutil.copy2(ROOT/'conf.lua',host/'conf.lua')
    shutil.copy2(ROOT/'tests/pinball_frame_driver.lua',host/'main.lua')
    options='return {launcherSetupVersion=1,launcherAnimations=false,cloudAutoSync=false,launcherSaveStorageChoice="local"}'
    (profile/'profiles/guest').mkdir(parents=True,exist_ok=True)
    for path in (profile/'options.lua',profile/'profiles/guest/options.lua'):path.write_text(options)
    (profile/'pinball-locale.txt').write_text(args.locale)
    report=cache/'report.json'
    env=dict(os.environ,POKEPORT_IDENTITY=identity,OA_QA_IDENTITY=identity,
        ASCENDANT_PINBALL_ROOT=str(ROOT),ASCENDANT_PINBALL_START='1',ASCENDANT_PINBALL_SEATS=str(args.seats),
        PINBALL_FRAME_ALLOW_BACKGROUND='1'if args.allow_background else'0',PINBALL_FRAME_PAUSE_UNFOCUSED='1'if args.pause_unfocused else'0',PINBALL_FRAME_FIELD=str(args.field),PINBALL_FRAME_LOCALE=args.locale,PINBALL_FRAME_REPORT=str(report),PINBALL_FRAME_SECONDS=str(args.seconds),PINBALL_FRAME_PLAYER=str(player),
        PINBALL_FRAME_TABLE='1'if args.full_table else'0')
    started=time.time()
    with(cache/'run.log').open('w')as log:
        result=qa.qa_run([str(executable),str(host)],cwd=ROOT,env=env,stdout=log,stderr=log,timeout=args.seconds*3+180)
    if report.exists()and report.stat().st_mtime>=started:
        data=json.loads(report.read_text())
        keys=('passed','seconds','wall_seconds','unique_native_presents','focus_lost_frames','focus_excluded_seconds',
              'allow_background','audio_restarts','display','source_gap','native','simulation','composition','thread_cpu','rounds','scheduler')
        print(json.dumps({key:data[key]for key in keys if key in data},indent=2))
        print('Detailed private report: '+str(report))
    else:
        print((cache/'run.log').read_text()[-5000:])
        return result.returncode or 1
    return result.returncode

if __name__=='__main__':raise SystemExit(main())
