#!/usr/bin/env python3
"""Render the actual native GBA menus and a battle with a converter-free mod."""
import argparse,hashlib,json,os,shutil
from pathlib import Path
from qa_storage import qa_source,qa_cache,qa_copy,qa_profile,qa_run,qa_ula

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--love',type=Path,required=True);p.add_argument('--candidate',type=Path,required=True)
    p.add_argument('--games',nargs='+',default=['firered','leafgreen','ruby','sapphire','emerald'])
    p.add_argument('--out',type=Path,required=True);a=p.parse_args()
    root=Path(__file__).resolve().parents[1];a.love=a.love.resolve();a.candidate=a.candidate.resolve();out=a.out.resolve()
    profiles=Path.home()/'Library/Application Support/LOVE'
    for source in (root,a.love,a.candidate,*[profiles/('ula-native-qa-'+g)for g in a.games]):qa_source(source)
    qa_cache(out);out.mkdir(parents=True,exist_ok=True)
    driver=out/'driver.lua';shutil.copy2(root/'tests/drivers/native_rom_language_ui.lua',driver)
    results=[]
    for game in a.games:
        before=profiles/('ula-native-qa-'+game);identity='ula-native-qa-ui-'+game;profile=profiles/identity
        qa_profile(profile);profile.mkdir(exist_ok=True)
        shutil.copytree(before/game,profile/game,dirs_exist_ok=True)
        mod=profile/'mods/german_rom_source';qa_copy(mod)
        shutil.copytree(before/'mods/german_rom_source',mod,dirs_exist_ok=True)
        compiled=profile/'modstorage/german_rom_source/compiled';qa_ula(compiled)
        if (before/'modstorage/german_rom_source').exists():shutil.copytree(before/'modstorage/german_rom_source',profile/'modstorage/german_rom_source',dirs_exist_ok=True)
        shutil.copy2(before/'options.lua',profile/'options.lua')
        env={k:v for k,v in os.environ.items()if not k.startswith('POKEPORT_')}
        env.update(POKEPORT_IDENTITY=identity,POKEPORT_VERSION=game,POKEPORT_NO_BOOT_REPORT='1',POKEPORT_NO_DISCORD='1',POKEPORT_TOUCH='0',POKEPORT_GRAPHICS_BACKEND='opengl',POKEPORT_DRIVER=str(driver))
        log=out/(game+'.log');print('NATIVE_UI',game,flush=True)
        with log.open('w')as f:run=qa_run([str(a.love),str(a.candidate)],cwd=a.candidate,env=env,stdout=f,stderr=f,timeout=600)
        body=log.read_text();passed=run.returncode==0 and 'NATIVE_LANGUAGE_GBA_FULL_OK\t'+game in body
        results.append(dict(game=game,passed=passed,logSha256=hashlib.sha256(log.read_bytes()).hexdigest()))
        print(game,'PASS'if passed else'FAIL',body[-5000:]if not passed else'',flush=True)
        for shot in profile.glob('ula-'+game+'-full-*.png'):shutil.copy2(shot,out/shot.name)
    receipt=dict(passed=all(r['passed']for r in results),runs=results,driverSha256=hashlib.sha256(driver.read_bytes()).hexdigest(),scope='Actual native GBA title, party, summary/info/skills/moves, bag, dex/entry, region, storage, card, naming, options, Emerald Pokenav, battle and language round trip. Party preparation is an explicit QA fixture; no normal SAVE.')
    (out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
    assert receipt['passed'],'Native language UI failed'

if __name__=='__main__':main()
