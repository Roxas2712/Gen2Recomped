#!/usr/bin/env python3
"""Qualify the built-in first-run/import flow without installing a language ZIP."""
from pathlib import Path
import argparse,hashlib,json,os,shutil,time
from qa_storage import qa_source,qa_copy,qa_profile,qa_cache,qa_run

ROOT=Path(__file__).resolve().parents[1]

def fingerprint(paths,root):
    h=hashlib.sha256()
    for p in sorted(paths):h.update(p.relative_to(root).as_posix().encode());h.update(p.read_bytes())
    return h.hexdigest()

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--love',type=Path,required=True)
    ap.add_argument('--games',nargs='+',choices=['gold','emerald'],default=['gold','emerald'])
    ap.add_argument('--language',choices=['de','pt-BR'],default='de')
    ap.add_argument('--rom-dir',type=Path,default=Path.home()/'Downloads')
    ap.add_argument('--out',type=Path,required=True)
    a=ap.parse_args();out=a.out.resolve();love=a.love.resolve();roms=a.rom_dir.resolve()
    backup=ROOT.parent/'uni-language-ascendant/backups/local-install-rc10-20261021-160916/pokemon-love2d/german_rom_source/baseroms'
    for p in (ROOT,love,roms,backup):qa_source(p)
    qa_cache(out);out.mkdir(parents=True,exist_ok=True)
    source=out/'source';qa_copy(source,ephemeral=True);source.mkdir(exist_ok=True)
    for name in ('src','assets','data','mods/UNI_LANGUAGE_NATIVE','tools/save-editor','tools/map-editor'):
        shutil.copytree(ROOT/name,source/name,dirs_exist_ok=True)
    for p in (ROOT/'tools').glob('rom_manifest*.json'):
        (source/'tools').mkdir(exist_ok=True);shutil.copyfile(p,source/'tools'/p.name)
    for original,target in [('conf.lua','conf.lua'),('main.lua','engine_main.lua'),
      ('tests/drivers/ptbr_auto.lua'if a.language=='pt-BR'else 'tests/drivers/native_rom_languages.lua','native-game-driver.lua'),('tests/drivers/builtin_language_setup.lua','setup-driver.lua')]:
        shutil.copyfile(ROOT/original,source/target)
    (source/'main.lua').write_text('''local id=assert(os.getenv('POKEPORT_IDENTITY'))
assert(id:match('^ula%-native%-qa%-builtin%-'))
assert(love.filesystem.getIdentity()==id)
assert(love.filesystem.write('migrated-from-pokemon-love2d.txt','Owned built-in language QA.'))
local set=love.filesystem.setIdentity
love.filesystem.setIdentity=function(value,...)assert(value==id);return set(value,...)end
io.stdout:setvbuf('no')
love.errorhandler=function(e)print(debug.traceback(tostring(e),2));return function()return 1 end end
assert(loadfile('engine_main.lua'))()
local RI=require('src.import.RomImporter');local new=RI.new;local importer
local T=require('src.translation.Service');T.enqueueLauncher=function()end;T.enqueue=function()end;T.update=function()end
RI.new=function(...)importer=new(...);return importer end
local co=coroutine.create(assert(loadfile('setup-driver.lua'))())
local update=love.update
love.update=function(dt)
 update(dt)
 if importer and coroutine.status(co)~='dead' then
  local ok,why=coroutine.resume(co,importer)
  if not ok then print('BUILTIN_LANGUAGE_SETUP_FAILED',debug.traceback(co,tostring(why)));love.event.quit(1)end
 end
end
for _,name in ipairs({'keypressed','keyreleased','textinput','mousepressed','mousereleased','touchpressed','touchreleased','gamepadpressed','gamepadreleased'})do love[name]=function()end end
love.keyboard.isDown=function()return false end
''')
    manifest=json.loads((ROOT/'mods/UNI_LANGUAGE_NATIVE/manifest.json').read_text())
    inventory={}
    for folder in (roms,backup):
        if folder.exists():
            for p in folder.iterdir():
                if p.is_file() and p.suffix.lower() in ('.gb','.gbc','.gba'):
                    data=p.read_bytes();inventory[hashlib.sha1(data).hexdigest()]=p
                    inventory[(len(data),hashlib.md5(data).hexdigest())]=p
    runs=[]
    tag=time.strftime('%Y%m%d-%H%M%S')
    for game in a.games:
        baseSha=json.loads((ROOT/f'tools/rom_manifest_{game}.json').read_text())['romSha1']
        base=inventory[baseSha];qa_source(base)
        translated=None
        if a.language=='de':
            spec=next(s for s in manifest['optional_imports'] if s['id']==game+'_de')
            translated=inventory[(spec['size'],spec['md5'])];qa_source(translated)
        identity='ula-native-qa-builtin-'+game+'-'+tag
        profile=Path.home()/'Library/Application Support/LOVE'/identity;qa_profile(profile);profile.mkdir(parents=True,exist_ok=True)
        # Refuse a reused account/import/mod profile, rather than deleting it.
        assert not (profile/'mods/german_rom_source/manifest.json').exists()
        assert not (profile/'options.lua').exists(),'Use a fresh QA identity for a complete first-run receipt'
        (profile/'options.lua').write_text('return {launcherAnimations=false,cloudAutoSync=false,gameCacheUpload=false}')
        env={k:v for k,v in os.environ.items() if not k.startswith('POKEPORT_')}
        env.update(POKEPORT_IDENTITY=identity,POKEPORT_NO_BOOT_REPORT='1',POKEPORT_NO_DISCORD='1',POKEPORT_TOUCH='0',POKEPORT_GRAPHICS_BACKEND='opengl',
          NATIVE_SETUP_GAME=game,NATIVE_SETUP_BASE=str(base),NATIVE_SETUP_LANGUAGE=a.language)
        if translated:env['NATIVE_SETUP_SOURCE']=str(translated)
        else:env.pop('NATIVE_SETUP_SOURCE',None)
        log=out/(game+'.log');print('BUILTIN',game,flush=True)
        with log.open('w') as f:p=qa_run([str(love),str(source)],cwd=source,env=env,stdout=f,stderr=f,timeout=900)
        marker='PTBR_AUTO_GAME_OK'if a.language=='pt-BR'else'NATIVE_ROM_LANGUAGE_OK'
        body=log.read_text();passed=p.returncode==0 and 'BUILTIN_LANGUAGE_SETUP_OK\t'+game in body and marker+'\t'+game in body
        print(game,'PASS'if passed else 'FAIL',body[-6500:]if not passed else '',flush=True)
        runs.append(dict(game=game,passed=passed,logSha256=hashlib.sha256(log.read_bytes()).hexdigest()))
        for shot in profile.glob('*.png'):shutil.copyfile(shot,out/(game+'-'+shot.name))
        if not passed:break
    receipt=dict(passed=len(runs)==len(a.games) and all(r['passed']for r in runs),runs=runs,
      engineLuaSha256=fingerprint(list((source/'src').rglob('*.lua')),source),
      bundledPayloadSha256=fingerprint([p for p in (source/'mods/UNI_LANGUAGE_NATIVE').rglob('*')if p.is_file()],source),
      ptbrPatchBundleSha256=fingerprint([p for p in(source/'assets/language-patches/pt-BR').rglob('*')if p.is_file()],source),
      language=a.language,scope='Clean profile. Built-in payload, no language ZIP. First-run locale/font checks, actual US import, native game round trips and progress preservation. PT-BR: US-only offline generation through the actual asynchronous modal; no extra language ROM. German: exact source acquisition/rejection. Asian gameplay requires separate real-ROM qualification.')
    (out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
    assert receipt['passed'],'Built-in language setup failed'

if __name__=='__main__':main()
