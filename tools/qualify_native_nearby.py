#!/usr/bin/env python3
"""Two local native LÖVE processes discover through UDP and battle through ENet.
This proves local sockets, native gameplay and save restoration, not two physical WLAN devices.
"""
import argparse,json,os,shutil,sys,time
from pathlib import Path
from qa_storage import qa_source,qa_copy,qa_cache,qa_profile,qa_popen
ROOT=Path(__file__).resolve().parents[1]
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--mode',choices=['battle','trade','centers'],default='battle');p.add_argument('--timeout',type=int,default=150);p.add_argument('--cache',action='append',required=True);p.add_argument('--love-app',type=Path,required=True);a=p.parse_args()
 runtime=a.love_app.resolve(strict=True);caches={k:Path(v).resolve(strict=True)for k,v in(x.split('=',1)for x in a.cache)}
 for path in [ROOT,runtime,Path(sys.executable),*caches.values()]:qa_source(path)
 run=str(time.time_ns());out=ROOT/'.local/qa'/('retro-nearby-'+run);qa_cache(out);out.mkdir(mode=0o700)
 source=out/'source';qa_copy(source,ephemeral=True);source.mkdir();shutil.copytree(ROOT/'src',source/'src')
 for name in ['assets','data','tools']:(source/name).symlink_to(ROOT/name,target_is_directory=True)
 shutil.copyfile(ROOT/'tests/native_nearby/main.lua',source/'main.lua')
 (source/'conf.lua').write_text("function love.conf(t)love.filesystem.setSymlinksEnabled(true);t.identity=os.getenv('POKEPORT_IDENTITY');t.window.visible=false;t.window.vsync=0;t.window.width=720;t.window.height=600 end")
 results=[];children=[]
 try:
  for edition,cache in caches.items():
   pair=[]
   for role in (['scan']if a.mode=='centers'else['right','left']):
    identity='oasc-nearby-qa-'+run+'-'+edition+'-'+role;qa_profile(Path.home()/'Library/Application Support/LOVE'/identity)
    cfg={'mode':a.mode,'timeout':a.timeout-5,'edition':edition,'role':role,'cache':str(cache),'result':str(out/(identity+'.json'))};cfgpath=out/(identity+'-config.json');cfgpath.write_text(json.dumps(cfg))
    env=os.environ|{'POKEPORT_IDENTITY':identity,'POKEPORT_DATA_DIR':str(cache/'data/generated'),'POKEPORT_NO_DISCORD':'1','POKEPORT_SKIP_LEGACY_MIGRATION':'1','RETRO_NEAR_CONFIG':str(cfgpath),'RETRO_LINK_PHYSFS':str(runtime/'Contents/Frameworks/love.framework/Versions/A/love')}
    with(out/(identity+'.log')).open('ab')as log:child=qa_popen([str(runtime/'Contents/MacOS/love'),str(source)],cwd=ROOT,env=env,stdout=log,stderr=log)
    pair.append((child,Path(cfg['result'])));children.append(child)
   until=time.monotonic()+a.timeout
   while any(x.poll()is None for x,_ in pair)and time.monotonic()<until:time.sleep(.2)
   rows=[]
   for child,path in pair:
    if child.poll()is None:child.terminate();child.wait(timeout=10)
    row=json.loads(path.read_text())if path.exists()else {'ok':False,'reason':'Missing native result'};rows.append(row)
   results+=rows;(out/'report.json').write_text(json.dumps({'results':results,'physical_devices':False},indent=2));print(json.dumps(rows),flush=True)
   assert all(x['ok']for x in rows)
   if a.mode=='battle':assert rows[0]['proof']['digest']==rows[1]['proof']['digest']
   elif a.mode=='trade':assert rows[0]['receivedSpecies']==rows[1]['sentSpecies']and rows[1]['receivedSpecies']==rows[0]['sentSpecies']
  print('NATIVE_NEARBY_PASS '+str(out),flush=True)
 finally:
  for child in children:
   if child.poll()is None:child.terminate();child.wait(timeout=10)
if __name__=='__main__':main()
