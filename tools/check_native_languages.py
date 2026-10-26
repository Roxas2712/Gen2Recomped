#!/usr/bin/env python3
"""Qualify an ordinary, converter-free Uni-Language mod on isolated native games."""
import argparse, atexit, hashlib, json, os
from pathlib import Path
import shutil, sys, time
from qa_storage import qa_source, qa_cache, qa_copy, qa_profile, qa_run

ROOT=Path(__file__).resolve().parents[1]
GAMES=('red','blue','yellow','gold','silver','crystal','firered','leafgreen','ruby','sapphire','emerald')

def runtime_files(mod):
    return sorted(p for p in mod.rglob('*') if p.is_file() and p.parts[len(mod.parts)] not in ('fork','baseroms')
                  and p.name not in ('host.lua','HOST-QA.json','HOST-COMPATIBILITY.md')
                  and p.suffix.lower() not in ('.gb','.gbc','.gba','.sav'))

def fingerprint(files,root):
    h=hashlib.sha256()
    for p in files: h.update(p.relative_to(root).as_posix().encode());h.update(p.read_bytes())
    return h.hexdigest()

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--mod',type=Path,required=True)
    ap.add_argument('--love',type=Path,required=True)
    ap.add_argument('--rom-dir',type=Path,default=Path.home()/'Downloads')
    ap.add_argument('--games',nargs='+',choices=GAMES,default=list(GAMES))
    ap.add_argument('--out',type=Path,required=True)
    ap.add_argument('--reuse-imports',action='store_true')
    a=ap.parse_args();a.mod=a.mod.resolve();a.love=a.love.resolve();a.rom_dir=a.rom_dir.resolve();mod=a.mod/'mod';out=a.out.resolve()
    for p in (ROOT,a.mod,a.love,a.rom_dir): qa_source(p)
    # Existing inputs are pinned before any managed cleanup starts.
    backup=a.mod/'backups/local-install-rc10-20261021-160916/pokemon-love2d/german_rom_source/baseroms'
    qa_source(backup)
    for game in a.games: qa_source(Path.home()/'Library/Application Support/LOVE'/('ula-native-qa-'+game))
    qa_cache(out);out.mkdir(parents=True,exist_ok=True)
    source=out/'source';qa_copy(source);source.mkdir(exist_ok=True)
    # Freeze the actual working tree, including the new native implementation.
    for folder in ('src','assets','data','tools'):
        shutil.copytree(ROOT/folder,source/folder,dirs_exist_ok=True,ignore=shutil.ignore_patterns('__pycache__','*.pyc'))
    shutil.copy2(ROOT/'conf.lua',source/'conf.lua');shutil.copy2(ROOT/'main.lua',source/'engine_main.lua')
    (source/'main.lua').write_text('''local identity=assert(os.getenv('POKEPORT_IDENTITY'))
assert(identity:match('^ula%-native%-qa%-'))
assert(love.filesystem.getIdentity()==identity)
assert(love.filesystem.write('migrated-from-pokemon-love2d.txt','Isolated native language QA.'))
local set=love.filesystem.setIdentity
love.filesystem.setIdentity=function(id,...)assert(id==identity);return set(id,...)end
io.stdout:setvbuf('no')
love.errorhandler=function(e)print(debug.traceback(tostring(e),2));return function()return 1 end end
assert(loadfile('engine_main.lua'))()
for _,name in ipairs({'keypressed','keyreleased','textinput','mousepressed','mousereleased','touchpressed','touchreleased','gamepadpressed','gamepadreleased'})do love[name]=function()end end
if love.keyboard then love.keyboard.isDown=function()return false end end
''')
    files=runtime_files(mod);modHash=fingerprint(files,mod)
    engineFiles=sorted(p for p in (ROOT/'src').rglob('*') if p.is_file())
    engineHash=fingerprint(engineFiles,ROOT)
    driver=out/'native-language-driver.lua'
    shutil.copy2(ROOT/'tests/drivers/native_rom_languages.lua',driver)
    driverHash=hashlib.sha256(driver.read_bytes()).hexdigest()
    # Exact identities; names are used only to find candidates.
    inventory={}
    candidates=list(a.rom_dir.glob('*'))+(list(backup.glob('*')) if backup.exists() else [])
    for p in candidates:
        if p.is_file() and p.suffix.lower() in ('.gb','.gbc','.gba'):
            data=p.read_bytes();inventory[(len(data),hashlib.md5(data).hexdigest())]=p
            inventory[hashlib.sha1(data).hexdigest()]=p
    manifest=json.loads((mod/'manifest.json').read_text())
    baseSpecs={g:json.loads((ROOT/('tools/rom_manifest.json' if g=='red' else f'tools/rom_manifest_{g}.json')).read_text())['romSha1'] for g in a.games}
    results=[]
    for game in a.games:
        identity='ula-native-qa-'+game;profile=Path.home()/'Library/Application Support/LOVE'/identity
        qa_profile(profile);profile.mkdir(parents=True,exist_ok=True)
        env={k:v for k,v in os.environ.items() if not k.startswith('POKEPORT_')}
        env.update(POKEPORT_IDENTITY=identity,POKEPORT_VERSION=game,POKEPORT_NO_BOOT_REPORT='1',POKEPORT_NO_DISCORD='1',POKEPORT_TOUCH='0',POKEPORT_GRAPHICS_BACKEND='opengl')
        if not a.reuse_imports or not (profile/('' if game=='red' else game)/'rom-cache.complete').exists():
            baseSha=baseSpecs[game]
            if game=='crystal' and baseSha not in inventory:
                baseSha='f4cd194bdee0d04ca4eac29e09b8e4e9d818c133'
            rom=inventory[baseSha];qa_source(rom)
            print('IMPORT',game,flush=True)
            with (out/(game+'-import.log')).open('w') as log:
                p=qa_run([str(a.love),str(source)],cwd=source,env=dict(env,POKEPORT_IMPORT_ROM=str(rom),POKEPORT_IMPORT_ONLY='1',POKEPORT_NO_MODS='1'),stdout=log,stderr=log,timeout=600)
            if p.returncode: raise RuntimeError((out/(game+'-import.log')).read_text()[-8000:])
        installed=profile/'mods/german_rom_source';qa_copy(installed)
        # Copy only the ordinary mod payload: there is no fork/ subtree.
        if (installed/'fork').exists(): raise RuntimeError('Unexpected conversion backend in dedicated QA profile')
        for path in files:
            target=installed/path.relative_to(mod);target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(path,target)
        imports=installed/'baseroms';imports.mkdir(exist_ok=True)
        for spec in manifest['optional_imports']:
            if spec['id'] in (game+'_de',game+'_en'):
                sourceRom=inventory[(spec['size'],spec['md5'])];qa_source(sourceRom);shutil.copy2(sourceRom,imports/spec['file'])
        (imports/'.uni-language-profile').write_text('ULA1\npreferences/notice.txt=accepted\npreferences/ascendant-intro-v1.txt=seen\npreferences/ui-language.txt=en\npreferences/'+game+'.txt=de\n')
        (profile/'options.lua').write_text('return {mods={german_rom_source=true},modOptions={german_rom_source={language="auto",showPicker=false}}}')
        logPath=out/(game+'-native.log');print('NATIVE',game,flush=True)
        with logPath.open('w') as log:
            p=qa_run([str(a.love),str(source)],cwd=source,env=dict(env,POKEPORT_DRIVER=str(driver)),stdout=log,stderr=log,timeout=600)
        body=logPath.read_text();passed=p.returncode==0 and 'NATIVE_ROM_LANGUAGE_OK\t'+game in body
        print(game,'PASS' if passed else 'FAIL',body[-3500:] if not passed else '',flush=True)
        for name in ('title','world'):
            shot=profile/('native-language-'+name+'.png')
            if shot.exists():shutil.copy2(shot,out/(game+'-'+name+'.png'))
        results.append(dict(game=game,language='de',passed=passed,logSha256=hashlib.sha256(logPath.read_bytes()).hexdigest()))
    receipt=dict(format=1,version=manifest['version'],passed=all(r['passed'] for r in results),modPayloadSha256=modHash,engineSourceSha256=engineHash,driverSha256=driverHash,
                 converterFiles=0,files=[p.relative_to(mod).as_posix() for p in files],runs=results,
                 scope='Actual German ROMs on the listed native games: native load, title/world rendering, mechanics, EN/DE switching, failed-switch rollback, rejected imports, position/save preservation; real nurse scripts on GSC. Other source languages are not certified by these runs.')
    (out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
    assert fingerprint(runtime_files(mod),mod)==modHash,'Mod changed during verification'
    assert fingerprint(engineFiles,ROOT)==engineHash,'Engine changed during verification'
    if not receipt['passed']:sys.exit(1)

if __name__=='__main__':main()
