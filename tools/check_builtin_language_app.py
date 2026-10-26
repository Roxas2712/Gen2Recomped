#!/usr/bin/env python3
"""Run native language acceptance inside the actual fused macOS app."""
from pathlib import Path
import argparse,hashlib,json,os,shutil,time
from qa_storage import qa_source,qa_profile,qa_cache,qa_run

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--app',type=Path,required=True)
    ap.add_argument('--source-profile',type=Path,required=True)
    ap.add_argument('--out',type=Path,required=True)
    a=ap.parse_args();root=Path(__file__).resolve().parents[1]
    app=a.app.resolve();original=a.source_profile.resolve();out=a.out.resolve()
    assert original.name.startswith('ula-native-qa-builtin-gold-'),'Only an owned built-in Gold acceptance profile may seed this check'
    for p in (root,app,original):qa_source(p)
    qa_cache(out);out.mkdir(parents=True,exist_ok=True)
    identity='ula-native-qa-builtin-package-'+time.strftime('%Y%m%d-%H%M%S')
    # Fused macOS LOVE uses Application Support/<identity>, without /LOVE/.
    profile=Path.home()/'Library/Application Support'/identity
    qa_profile(profile);assert not profile.exists();shutil.copytree(original,profile)
    driver=out/'packaged-driver.lua'
    driver.write_text('return function(game)\n assert(game.mods.exports.german_rom_source.sessionBoot)\n print("BUILTIN_PACKAGED_GAME_OK")\n return assert(loadfile('+json.dumps(str(root/'tests/drivers/native_rom_languages.lua'))+'))()(game)\nend\n')
    env={k:v for k,v in os.environ.items()if not k.startswith('POKEPORT_')}
    env.update(POKEPORT_IDENTITY=identity,POKEPORT_VERSION='gold',POKEPORT_DRIVER=str(driver),POKEPORT_NO_BOOT_REPORT='1',POKEPORT_NO_DISCORD='1',POKEPORT_TOUCH='0',POKEPORT_GRAPHICS_BACKEND='opengl')
    log=out/'gold-packaged.log'
    with log.open('w')as f:p=qa_run([str(app/'Contents/MacOS/love')],cwd=root,env=env,stdout=f,stderr=f,timeout=180)
    body=log.read_text();passed=p.returncode==0 and 'BUILTIN_PACKAGED_GAME_OK'in body and 'NATIVE_ROM_LANGUAGE_OK\tgold'in body
    receipt={'passed':passed,'scope':'Actual fused macOS app, built-in pack, copied owned Gold QA guest profile and exact input sources; no installed language ZIP. Native render, language round trips, failure rollback and progress preservation.',
      'logSha256':hashlib.sha256(log.read_bytes()).hexdigest(),'payloadSha256':hashlib.sha256((app/'Contents/Resources/game.love').read_bytes()).hexdigest()}
    (out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print('PACKAGED',passed,flush=True)
    if not passed:print(body[-6500:]);raise SystemExit(1)

if __name__=='__main__':main()
