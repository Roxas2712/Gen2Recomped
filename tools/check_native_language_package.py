#!/usr/bin/env python3
"""Install/update the final mod ZIP and boot the packaged macOS engine."""
import argparse,hashlib,json,os,shutil
from pathlib import Path
from qa_storage import qa_source,qa_cache,qa_copy,qa_profile,qa_run

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--app',type=Path,required=True);p.add_argument('--zip',type=Path,required=True)
    p.add_argument('--love',type=Path,required=True,help='Unfused runtime for the installer harness')
    p.add_argument('--out',type=Path,required=True);a=p.parse_args()
    root=Path(__file__).resolve().parents[1];app=a.app.resolve();archive=a.zip.resolve();out=a.out.resolve()
    profiles=Path.home()/'Library/Application Support/LOVE';before=profiles/'ula-native-qa-gold'
    for source in(root,app,archive,before,a.love.resolve()):qa_source(source)
    qa_cache(out);out.mkdir(parents=True,exist_ok=True)
    identity='ula-native-qa-package-gold';profile=profiles/identity;qa_profile(profile);profile.mkdir(exist_ok=True)
    shutil.copytree(before/'gold',profile/'gold',dirs_exist_ok=True)
    shutil.copy2(before/'options.lua',profile/'options.lua')
    (profile/'migrated-from-pokemon-love2d.txt').write_text('Isolated native package QA.\n')
    installed=profile/'mods/german_rom_source';qa_copy(installed)
    source=out/'source';qa_copy(source);source.mkdir(exist_ok=True)
    (source/'conf.lua').write_text("function love.conf(t)t.identity=assert(os.getenv('POKEPORT_IDENTITY'));t.version=(love.getVersion()>=12)and'12.0'or'11.5';t.window=false;t.modules.graphics=false;t.modules.audio=false end\n")
    (source/'main.lua').write_text('''function love.load()
local ok,why=xpcall(function()
 local root=assert(os.getenv('NATIVE_ENGINE'));package.path=root..'/?.lua;'..package.path
 local Launcher=require('src.mods.LauncherMods');local zip=assert(os.getenv('NATIVE_ZIP'))
 assert(Launcher.installZip(zip,{expectId='german_rom_source',replace=true}))
 local path='mods/german_rom_source/'
 assert(not love.filesystem.getInfo(path..'fork/main.lua'))
 assert(not love.filesystem.getInfo(path..'host.lua'))
 local raw=require('src.link.Json').decode(assert(love.filesystem.read(path..'manifest.json')))
 local manifest=require('src.mods.Manifest').validate(raw,'mods/german_rom_source')
 local Imports=require('src.mods.ModImports')
 local romFile=assert(io.open(assert(os.getenv('NATIVE_ROM')),'rb'));local bytes=romFile:read('*a');romFile:close()
 for _,spec in ipairs(Imports.of(manifest))do if spec.id=='gold_de'then assert(Imports.install(manifest,spec,bytes))end end
 local preferences=table.concat({'ULA1','preferences/notice.txt=accepted','preferences/ascendant-intro-v1.txt=seen','preferences/ui-language.txt=en','preferences/gold.txt=de',''},string.char(10))
 assert(love.filesystem.write(path..'baseroms/.uni-language-profile',preferences))
 assert(love.filesystem.write('ordinary-save-sentinel','keep this'))
 assert(Launcher.installZip(zip,{expectId='german_rom_source',replace=true}))
 assert(love.filesystem.read(path..'baseroms/gold_de.gbc')==bytes,'ZIP replacement lost validated input')
 assert(love.filesystem.read(path..'baseroms/.uni-language-profile')==preferences,'ZIP replacement lost preferences')
 assert(love.filesystem.read('ordinary-save-sentinel')=='keep this')
 print('NATIVE_LANGUAGE_ZIP_INSTALL_OK')
end,debug.traceback)
if not ok then print(why)end
love.event.quit(ok and 0 or 1)
end
''')
    executable=app/'Contents/MacOS/love'
    env={k:v for k,v in os.environ.items()if not k.startswith('POKEPORT_')}
    env.update(POKEPORT_IDENTITY=identity,POKEPORT_VERSION='gold',POKEPORT_NO_BOOT_REPORT='1',POKEPORT_NO_DISCORD='1',POKEPORT_TOUCH='0',POKEPORT_GRAPHICS_BACKEND='opengl',NATIVE_ENGINE=str(root),NATIVE_ZIP=str(archive),NATIVE_ROM=str(before/'mods/german_rom_source/baseroms/gold_de.gbc'))
    results={}
    for label,target,extra in [('install',source,{}),('native-game',app/'Contents/Resources/game.love',{'POKEPORT_DRIVER':str(root/'tests/drivers/native_rom_languages.lua')})]:
        if label=='native-game':
            # Fused macOS apps omit LOVE/ from their save-directory parent.
            # Mirror only this owned test profile into that native location.
            fused=Path.home()/'Library/Application Support'/identity
            qa_profile(fused);fused.mkdir(parents=True,exist_ok=True)
            for tree in ('gold','mods/german_rom_source','modstorage/german_rom_source'):
                if (profile/tree).exists():shutil.copytree(profile/tree,fused/tree,dirs_exist_ok=True)
            for name in('options.lua','migrated-from-pokemon-love2d.txt'):
                shutil.copy2(profile/name,fused/name)
        log=out/(label+'.log')
        command=[str(a.love.resolve()),str(target)]if label=='install'else[str(executable)]
        with log.open('w')as f:run=qa_run(command,env=dict(env,**extra),cwd=root,stdout=f,stderr=f,timeout=600)
        text=log.read_text();passed=run.returncode==0 and ('NATIVE_LANGUAGE_ZIP_INSTALL_OK'if label=='install'else'NATIVE_ROM_LANGUAGE_OK\tgold')in text
        print(label,passed,text[-3500:]if not passed else'',flush=True)
        results[label]=dict(passed=passed,logSha256=hashlib.sha256(log.read_bytes()).hexdigest())
        if not passed:break
    receipt=dict(passed=len(results)==2 and all(r['passed']for r in results.values()),runs=results,modZipSha256=hashlib.sha256(archive.read_bytes()).hexdigest(),payloadSha256=hashlib.sha256((app/'Contents/Resources/game.love').read_bytes()).hexdigest())
    (out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
    assert receipt['passed'],'Native packaged installation failed'

if __name__=='__main__':main()
