#!/usr/bin/env python3
"""Full launcher/native TCG UI and example-mod qualification. By Roxas2712."""
from pathlib import Path
import argparse
import atexit,sys,os,subprocess
root=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--love',type=Path,required=True);parser.add_argument('--min-free-gib',type=float,default=20);args=parser.parse_args();assert args.min_free_gib>=2
sys.path.insert(0,str(Path.home()/'.local/lib/origami-qa-storage/active-tools'));import qa_storage as q
q._storage=q.Storage(root);q._storage.min_free=args.min_free_gib*1024**3;atexit.register(q._storage.close,collect=False)
love=args.love.resolve(strict=True)
identity='oasc-tcg-qa-ui';profile=Path.home()/'Library/Application Support/LOVE'/identity
for p in [root,love,profile,root/'.local/tcg-gbc']:q.qa_source(p)
q.qa_profile(profile);profile.mkdir(parents=True,exist_ok=True);(profile/'options.lua').write_text('return {launcherLanguage="en",launcherSetupVersion=1,launcherOriginalCartridges=false,cloudAutoSync=false}');(profile/'tcg-mods').mkdir(exist_ok=True);(profile/'tcg-mods/enabled.json').write_text('{"tcg_status":true}')
(root/'.local/tcg-gbc/test-player').mkdir(exist_ok=True)
host=root/'.local/engine-parity/tcg-ui';q.qa_copy(host,ephemeral=True);host.mkdir(parents=True,exist_ok=True)
for item in ['src','assets','data','tools','mods','icons','conf.lua']:
 if not(host/item).exists():(host/item).symlink_to(root/item,target_is_directory=(root/item).is_dir())
import shutil
if not(host/'tcg-mods').exists():shutil.copytree(root/'tcg-mods',host/'tcg-mods')
(host/'main.lua').write_text('''love.filesystem.setSymlinksEnabled(true)
assert(loadfile('''+repr(str(root/'main.lua'))+'''))()
love.errorhandler=function(err)io.stderr:write(tostring(err)..'\\n');return function()return 1 end end
local RI=require('src.import.RomImporter');local new=RI.new;local ui
RI.new=function(...)ui=new(...);ui._setupOverlay=nil;ui._setupPending=nil;return ui end
local update=love.update;local draw=love.draw;local ticks=0
function love.update(dt)
 update(dt);ticks=ticks+1
 if ticks==190 then assert(ui and ui._tcgPlayer,'TCG native player did not open: '..tostring(ui and ui._tcgNotice));assert(#ui._tcgPlayer.mods.mods==1,'TCG example mod did not load: '..tostring(love.filesystem.read('tcg-mods/enabled.json'))..' / '..tostring(#require('src.tcg.Mods').list())..' / '..love.filesystem.getSaveDirectory())end
 if ticks==195 then ui:keypressed('escape')end
 if ticks==225 then assert(ui and not ui._tcgPlayer,'TCG player failed to return to the launcher');ui:_sbBack();ui.section='games';ui.gamesView='cartridges';ui.browseConsole='gbc';ui.browseSeries='pokemon' end
 if ticks==250 then love.event.quit()end
end
function love.draw(...)
 draw(...)
 if ticks==190 then love.graphics.captureScreenshot('tcg-native-ui.png')end
 if ticks==220 then love.graphics.captureScreenshot('tcg-launcher-ui.png')end
 if ticks==245 then love.graphics.captureScreenshot('tcg-library-ui.png')end
end
''')
env=dict(os.environ,POKEPORT_IDENTITY=identity,OA_QA_IDENTITY=identity,ASCENDANT_TCG_GBC_START='1',ASCENDANT_TCG_GBC_ROOT=str(root),POKEPORT_SKIP_LEGACY_MIGRATION='1',POKEPORT_NO_BOOT_REPORT='1')
out=root/'.local/qa/tcg-ui';q.qa_cache(out);out.mkdir(parents=True,exist_ok=True)
with(out/'ui.log').open('w')as log:r=q.qa_run([str(love),str(host)],cwd=root,env=env,stdout=log,stderr=log,timeout=90)
print('exit',r.returncode);print((out/'ui.log').read_text()[-5000:])
for name in ['tcg-native-ui.png','tcg-launcher-ui.png','tcg-library-ui.png']:
 source=profile/name
 if source.exists():(out/name).write_bytes(source.read_bytes())
assert r.returncode==0
