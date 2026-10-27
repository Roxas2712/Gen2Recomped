#!/usr/bin/env python3
"""Qualify Portuguese from US inputs only, with exact output and native games."""
from pathlib import Path
import argparse,hashlib,json,os,shutil,time
from qa_storage import qa_source,qa_copy,qa_profile,qa_cache,qa_run
from check_builtin_language_setup import fingerprint

ROOT=Path(__file__).resolve().parents[1]
GAMES=['red','blue','yellow','gold','silver','crystal','ruby','sapphire','firered','leafgreen','emerald']

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--love',type=Path,required=True);ap.add_argument('--out',type=Path,required=True)
    ap.add_argument('--games',nargs='+',choices=GAMES,default=GAMES)
    ap.add_argument('--rom-dir',type=Path,default=Path.home()/'Downloads')
    ap.add_argument('--base-rom',type=Path,help='Exact base override for a single-edition/revision check')
    ap.add_argument('--cache-profile-template',default='ula-native-qa-{game}',help='Owned English-cache seed identity; must contain {game}')
    a=ap.parse_args();love=a.love.resolve();out=a.out.resolve();roms=a.rom_dir.resolve()
    assert a.cache_profile_template.startswith('ula-native-qa-')and'{game}'in a.cache_profile_template and'/'not in a.cache_profile_template and'\\'not in a.cache_profile_template,'Only owned QA profile names can seed English caches'
    oldProfiles={g:Path.home()/'Library/Application Support/LOVE'/a.cache_profile_template.format(game=g)for g in a.games}
    for p in (ROOT,love,roms,*oldProfiles.values()):qa_source(p)
    if a.base_rom:
        assert len(a.games)==1,'A base override requires exactly one edition';qa_source(a.base_rom.resolve())
    qa_cache(out);out.mkdir(parents=True,exist_ok=True);source=out/'source';qa_copy(source,ephemeral=True);source.mkdir(exist_ok=True)
    for name in ('src','assets','data','mods/UNI_LANGUAGE_NATIVE','tools/save-editor','tools/map-editor'):
        shutil.copytree(ROOT/name,source/name,dirs_exist_ok=True)
    for path in(ROOT/'tools').glob('rom_manifest*.json'):
        (source/'tools').mkdir(exist_ok=True);shutil.copyfile(path,source/'tools'/path.name)
    shutil.copyfile(ROOT/'conf.lua',source/'conf.lua');shutil.copyfile(ROOT/'main.lua',source/'engine_main.lua')
    shutil.copyfile(ROOT/'tests/drivers/ptbr_auto.lua',source/'ptbr-driver.lua')
    (source/'main.lua').write_text('''local identity=assert(os.getenv('POKEPORT_IDENTITY'))
assert(identity:match('^ula%-native%-qa%-ptbr%-'))
assert(love.filesystem.getIdentity()==identity)
assert(love.filesystem.write('migrated-from-pokemon-love2d.txt','Owned automatic Portuguese QA.'))
local set=love.filesystem.setIdentity
love.filesystem.setIdentity=function(id,...)assert(id==identity);return set(id,...)end
io.stdout:setvbuf('no')
love.errorhandler=function(e)print(debug.traceback(tostring(e),2));return function()return 1 end end
assert(loadfile('engine_main.lua'))()
if not os.getenv('POKEPORT_IMPORT_ONLY') then
 local Game=require('src.core.Game');local load=Game.load
 Game.load=function(self,...)
  local N=require('src.translation.NativeLanguages');local version=os.getenv('POKEPORT_VERSION')
  local manifest=assert(N.manifest());local state=N.describe(version,'pt-BR',manifest)
  assert(state.automatic and not state.sourceReady,'A PT-BR input was supplied instead of being generated')
  local f=assert(io.open(os.getenv('PTBR_US_INPUT'),'rb'));local bytes=f:read('*a');f:close()
  local sha=love.data.encode('string','hex',love.data.hash('string','sha1',bytes))
  assert(N.keepBase(version,bytes,sha))
  local retained=N.describe(version,'pt-BR',manifest);assert(retained.canPrepare and not retained.nextEntry,'US base still asks for an extra language ROM')
  assert(require('src.translation.PtbrPatch').prepare(version,manifest))
  assert(N.select(version,'pt-BR'))
  print('PTBR_US_ONLY_PREPARED',version)
  return load(self,...)
 end
end
for _,name in ipairs({'keypressed','keyreleased','textinput','mousepressed','mousereleased','touchpressed','touchreleased','gamepadpressed','gamepadreleased'})do love[name]=function()end end
love.keyboard.isDown=function()return false end
''')
    recipes=json.loads((ROOT/'assets/language-patches/pt-BR/index.json').read_text())['recipes']
    inventory={}
    for path in roms.iterdir():
        if path.is_file()and path.suffix.lower()in('.gb','.gbc','.gba'):
            inventory[hashlib.sha1(path.read_bytes()).hexdigest()]=path
    override=None
    if a.base_rom:
        override=hashlib.sha1(a.base_rom.read_bytes()).hexdigest();inventory[override]=a.base_rom.resolve()
    tag=time.strftime('%Y%m%d-%H%M%S');runs=[]
    for game in a.games:
        recipe=next(r for r in recipes if r['game']==game and r['baseSha1']in inventory and(not override or r['baseSha1']==override))
        base=inventory[recipe['baseSha1']];qa_source(base)
        identity='ula-native-qa-ptbr-'+game+'-'+tag
        profile=Path.home()/'Library/Application Support/LOVE'/identity;qa_profile(profile);profile.mkdir(parents=True,exist_ok=True)
        prefix=''if game=='red'else game
        old=oldProfiles[game]/prefix;dest=profile/prefix;dest.mkdir(exist_ok=True)
        if(old/'rom-cache.complete').exists():
            for name in('data','assets'):shutil.copytree(old/name,dest/name,dirs_exist_ok=True)
            shutil.copyfile(old/'rom-cache.complete',dest/'rom-cache.complete')
        env={k:v for k,v in os.environ.items()if not k.startswith('POKEPORT_')}
        env.update(POKEPORT_IDENTITY=identity,POKEPORT_VERSION=game,POKEPORT_NO_BOOT_REPORT='1',POKEPORT_NO_DISCORD='1',POKEPORT_TOUCH='0',POKEPORT_GRAPHICS_BACKEND='opengl',PTBR_US_INPUT=str(base))
        if not(dest/'rom-cache.complete').exists():
            with(out/(game+'-import.log')).open('w')as f:p=qa_run([str(love),str(source)],cwd=source,env=dict(env,POKEPORT_IMPORT_ROM=str(base),POKEPORT_IMPORT_ONLY='1',POKEPORT_NO_MODS='1'),stdout=f,stderr=f,timeout=600)
            assert p.returncode==0,'US import failed'
        print('PTBR',game,flush=True);log=out/(game+'.log')
        with log.open('w')as f:p=qa_run([str(love),str(source)],cwd=source,env=dict(env,POKEPORT_DRIVER=str(source/'ptbr-driver.lua')),stdout=f,stderr=f,timeout=600)
        body=log.read_text();passed=p.returncode==0 and 'PTBR_AUTO_GAME_OK\t'+game in body and 'PTBR_US_ONLY_PREPARED\t'+game in body
        print(game,'PASS'if passed else'FAIL',body[-6500:]if not passed else'',flush=True)
        runs.append(dict(game=game,passed=passed,logSha256=hashlib.sha256(log.read_bytes()).hexdigest()))
        for shot in profile.glob('ptbr-auto-*.png'):shutil.copyfile(shot,out/(game+'-'+shot.name))
        if not passed:break
    receipt=dict(passed=len(runs)==len(a.games)and all(r['passed']for r in runs),runs=runs,
      engineLuaSha256=fingerprint(list((source/'src').rglob('*.lua')),source),
      bundledPayloadSha256=fingerprint([p for p in(source/'mods/UNI_LANGUAGE_NATIVE').rglob('*')if p.is_file()],source),
      ptbrPatchBundleSha256=fingerprint([p for p in(source/'assets/language-patches/pt-BR').rglob('*')if p.is_file()],source),
      scope='US inputs only; no PT-BR ROM supplied. Exact target reconstruction, native profile load, mechanical-field identity, rendered title/world, EN/PT switching, failure rollback and live progress preservation; actual Portuguese nurses on GSC. No full-story or multiplayer certification.')
    (out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
    assert receipt['passed'],'Automatic Portuguese acceptance failed'

if __name__=='__main__':main()
