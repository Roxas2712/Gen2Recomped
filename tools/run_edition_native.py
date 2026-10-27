"""Run the actual edition importer/renderer in an isolated, guarded QA profile.

A private payload supplies unchanged runtime assets; current tracked Lua,
shader and metadata sources are overlaid and hashed before boot. Cartridges,
personal saves and the source runtime app remain read-only inputs.
"""
from pathlib import Path
from datetime import datetime, timezone
import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
import time
import zipfile
from qa_storage import qa_source, qa_cache, qa_copy, qa_profile, qa_run, qa_popen

ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('edition',choices=['leafgreen','firered','ruby','sapphire','emerald','gold','silver','crystal'])
parser.add_argument('--rom',type=Path,required=True)
parser.add_argument('--payload',type=Path,required=True)
parser.add_argument('--runtime-app',type=Path,required=True)
parser.add_argument('--driver',required=True)
parser.add_argument('--cache-source',type=Path,help='Prior accepted import; reuse cache only when all extraction inputs match')
parser.add_argument('--installed-profile',type=Path,help='Read-only input: clone only this edition cache, never player saves')
parser.add_argument('--story-save-source',type=Path,help='Resume a qualified own RS/LeafGreen normal-menu checkpoint; never personal saves')
parser.add_argument('--verify-story-continue',action='store_true',help="Queue the RS driver's ordinary CONTINUE verification and exit")
parser.add_argument('--speed',type=int,default=8)
parser.add_argument('--timeout',type=int,default=1200)
parser.add_argument('--freeze',type=Path,help=argparse.SUPPRESS)
parser.add_argument('--tracked-sources',type=Path,help=argparse.SUPPRESS)
args=parser.parse_args()
driver=Path(args.driver)
assert not driver.is_absolute() and '..'not in driver.parts and driver.suffix=='.lua'
if args.verify_story_continue:
    assert args.story_save_source and args.edition in('ruby','sapphire')and str(driver)=='tests/rs_story_driver.lua'

def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()

if args.freeze:
    engine=args.freeze;engine.mkdir(parents=True)
    with zipfile.ZipFile(args.payload)as archive:
        for member in archive.infolist():
            path=Path(member.filename)
            assert not path.is_absolute() and '..'not in path.parts
        archive.extractall(engine)
    # The parent already owns and supervises this pure-copy worker. Reuse its
    # tracked input list instead of creating a second storage manager merely
    # to run git (and repeating global collection at worker startup/exit).
    if args.tracked_sources:
        assert args.tracked_sources.parent==engine.parent
        tracked=json.loads(args.tracked_sources.read_text())
        assert isinstance(tracked,list)and all(isinstance(n,str)for n in tracked)
    else:
        tracked=qa_run(['git','ls-files','-z'],cwd=ROOT,capture_output=True,check=True).stdout.decode().split('\0')
    paths={name for name in tracked if name and Path(name).suffix in ('.lua','.json','.glsl','.frag','.vert')
           and (name.startswith(('src/','data/','compat/','lib/','tools/map-editor/'))or name in ('main.lua','conf.lua')
                or re.fullmatch(r'tools/rom_manifest_[a-z0-9_]+\.json',name))}
    paths.update([str(driver),'tests/drivers/util.lua'])
    if str(driver)=='tests/rs_battle_panel_native_driver.lua':
        paths.add('tests/rs_battle_panel_reference.lua')
    candidate={}
    for name in sorted(paths):
        source=ROOT/name;target=engine/name
        assert source.resolve().is_relative_to(ROOT) and not Path(name).is_absolute() and '..'not in Path(name).parts,name
        assert source.is_file() and not source.is_symlink(),name
        target.parent.mkdir(parents=True,exist_ok=True)
        raw=source.read_bytes()
        if name=='src/core/Version.lua':
            # CI stamps this one release string. Keep the tested product's
            # stamp while refusing changes to shell/API/cache/save contracts.
            stamped=target.read_bytes()
            neutral=lambda data:re.sub(rb'engine\s*=\s*"[^"]+"',b'engine="RELEASE_STAMP"',data,count=1)
            assert neutral(raw)==neutral(stamped),'Compatibility metadata changed; build a new qualified base payload'
            raw=stamped
        target.write_bytes(raw);candidate[name]=hashlib.sha256(raw).hexdigest()
    main=engine/'main.lua'
    main.write_bytes(b"io.stdout:setvbuf('no')\n"+main.read_bytes()+b"\nlove.errorhandler=function(e)print(debug.traceback(tostring(e),2));return function()return 1 end end\n")
    conf=engine/'conf.lua'
    conf.write_bytes(conf.read_bytes()+b"\nlocal configure=love.conf\nfunction love.conf(t)configure(t);assert(t.identity:match('^oasc%-edition%-qa%-'),'Own edition QA identity required');t.window.visible=false end\n")
    hashes={str(p.relative_to(engine)):digest(p)for p in engine.rglob('*')if p.is_file()}
    (engine.parent/'frozen-files.json').write_text(json.dumps(hashes,indent=2)+'\n')
    (engine.parent/'candidate-inputs.json').write_text(json.dumps(candidate,indent=2)+'\n')
    raise SystemExit()

for source in (ROOT,args.rom,args.payload,args.runtime_app,Path(sys.executable)):qa_source(source.resolve())
previous=None;cache=None
assert not(args.cache_source and args.installed_profile)
if args.cache_source:
    previous=args.cache_source.resolve();record=json.loads((previous/'verification.json').read_text())
    assert record['edition']==args.edition and record['identity'].startswith('oasc-edition-qa-')
    assert record['status']=='pass' and record['cartridgeSHA1']==hashlib.sha1(args.rom.read_bytes()).hexdigest()
    cache=Path.home()/'Library/Application Support/LOVE'/record['identity']/args.edition
    assert (cache/'rom-cache.complete').is_file()
    qa_source(previous);qa_source(cache.parent)
elif args.installed_profile:
    previous=args.installed_profile.resolve();cache=previous/args.edition
    qa_source(previous)
    assert not cache.is_symlink()and (cache/'rom-cache.complete').is_file()
    assert (cache/'rom-cache.complete').read_text().splitlines()[0].endswith(hashlib.sha1(args.rom.read_bytes()).hexdigest())
story=None;story_save=None
if args.story_save_source:
    prior=args.story_save_source.resolve()
    assert args.edition in ('leafgreen','ruby','sapphire')and prior.parent==ROOT/'.local/qa'
    assert prior.name.startswith('gen2recomp-qa-'+args.edition+'-')and not prior.is_symlink()
    sv=json.loads((prior/'verification.json').read_text());sr=json.loads((prior/'result.json').read_text())
    checkpoint=json.loads((prior/'normal-save-checkpoint.json').read_text())
    assert sv['cartridgeSHA1']==hashlib.sha1(args.rom.read_bytes()).hexdigest()
    if args.edition in ('ruby','sapphire'):
        from rs_story_checkpoint import qualify
        inherited=qualify(args.edition,prior.name,sv,sr,checkpoint)
    else:
        assert sv['frozenSourceUnchanged']and sv['externalSaveRecoveryDisabled']and sv['allModsDisabled']
        assert sv['status']=='pass'or(sv['status']=='fail'and sv.get('stoppedOwnChildReason')=='native QA timeout')
        assert sv['cartridgeSHA1']==hashlib.sha1(args.rom.read_bytes()).hexdigest()
        assert checkpoint['sourceRun']==prior.name and checkpoint['profileIdentity']==sv['identity']
        assert checkpoint['producedThroughNormalSaveMenu']and checkpoint['personalSave']is False
        assert checkpoint['saveRelativePath']=='profiles/guest/save_leafgreen.lua'or re.fullmatch(r'profiles/guest/saves/leafgreen/slot[1-9][0-9]*\.lua',checkpoint['saveRelativePath'])
        assert all(sr[k]for k in ('continuousFromNewGame','noTeleport','noPartyInjection','noDirectStoryFlagEdits'))
        assert sr['starter']['level']==5 and sr['parcelObtained']and sr['parcelReturned']and sr['pokedexObtained']
        rows=sr['commands'];first,last=checkpoint['saveMenuCommandRange']
        assert rows[first-1]['seq']==first and rows[last-1]['seq']==last
        assert rows[first-1]['before']['top']['source']=='src/ui/Gen3StartMenu.lua'
        assert rows[last-1]['after']==checkpoint['snapshotAfterSaveCommand']
        assert rows[last-1]['after']['top']['source']=='src/world/OverworldController.lua'
        assert any(r['input'].get('button')=='a'for r in rows[first-1:last])
        # Story advance sends only ordinary A presses until the free field returns.
        assert any((r['input'].get('button')=='a'or r['input'].get('op')=='advance')and r['before']['top'].get('source')=='src/ui/ChoiceBox.lua'
                   and r['before']['top'].get('index')==1
                   and any(s.get('source')=='src/ui/Gen3StartMenu.lua'for s in r['before']['stack'])
                   for r in rows[first-1:last]),'Checkpoint needs an actual YES in the normal SAVE flow'
        inherited={k:sr[k]for k in ('starter','parcelObtained','parcelReturned','pokedexObtained')}
    prior_profile=Path.home()/'Library/Application Support/LOVE'/sv['identity']
    for path in (prior,prior_profile):qa_source(path)
    assert prior_profile.resolve()==prior_profile
    story_save=prior_profile/checkpoint['saveRelativePath'];assert not story_save.is_symlink()
    assert digest(story_save)==checkpoint['sha256']
    story={'priorRun':str(prior),'priorVerificationSHA256':digest(prior/'verification.json'),
           'priorResultSHA256':digest(prior/'result.json'),'checkpoint':checkpoint,
           'inherited':inherited,
           'runtimeUpgrade':True,'personalSave':False}
stamp=datetime.now(timezone.utc).strftime('%Y%m%d%H%M%S%f')
identity='oasc-edition-qa-'+args.edition+'-'+stamp
out=ROOT/'.local/qa'/('gen2recomp-qa-'+args.edition+'-'+stamp);engine=out/'engine'
profile=Path.home()/'Library/Application Support/LOVE'/identity
qa_cache(out);qa_copy(engine,ephemeral=True);qa_source(profile);qa_profile(profile)
out.mkdir(parents=True)
tracked_source_paths=out/'tracked-source-paths.json'
tracked=qa_run(['git','ls-files','-z'],cwd=ROOT,capture_output=True,check=True).stdout.decode().split('\0')
tracked_source_paths.write_text(json.dumps(tracked)+'\n')
command=[sys.executable,__file__,args.edition,'--rom',str(args.rom.resolve()),
         '--payload',str(args.payload.resolve()),'--runtime-app',str(args.runtime_app.resolve()),'--driver',str(driver)]
qa_run(command+['--freeze',str(engine),'--tracked-sources',str(tracked_source_paths)],cwd=ROOT,check=True)
candidate=json.loads((out/'candidate-inputs.json').read_text())
if args.cache_source:
    old=json.loads((previous/'candidate-inputs.json').read_text())
    def extraction(name):
        return name.startswith(('src/import/','compat/','tools/rom_manifest_'))or name=='src/core/GameVersion.lua'
    assert {k:v for k,v in candidate.items()if extraction(k)}=={k:v for k,v in old.items()if extraction(k)},'Extraction inputs changed; run a fresh import'
runtime=engine/'.qa-runtime.app'
qa_run(['ditto',str(args.runtime_app.resolve()),str(runtime)],check=True)
qa_run([sys.executable,'-c',
        'from pathlib import Path;import plistlib,sys;p=Path(sys.argv[1]);(p/"Contents/Resources/game.love").unlink();f=p/"Contents/Info.plist";d=plistlib.loads(f.read_bytes());d["CFBundleIdentifier"]=sys.argv[2];d["CFBundleName"]="Edition QA "+sys.argv[2].rsplit(".",1)[-1];d["LSUIElement"]=True;f.write_bytes(plistlib.dumps(d))',
        str(runtime),'org.roxas2712.editionqa.'+stamp],check=True)
profile.mkdir(parents=True)
(profile/'migrated-from-pokemon-love2d.txt').write_text('Own native edition QA; never migrate player data.\n')
if cache:qa_run(['cp','-cR',str(cache),str(profile/args.edition)],check=True)
if story:
    # A new QA profile has no slot registry; let the native resolver adopt
    # these unchanged bytes through its usual legacy-save migration.
    target=profile/('profiles/guest/save_'+args.edition+'.lua');target.parent.mkdir(parents=True,exist_ok=True)
    target.write_bytes(story_save.read_bytes());assert digest(target)==story['checkpoint']['sha256']
    story['copiedSaveAbsolutePath']=str(target)
    (out/'story-lineage.json').write_text(json.dumps(story,indent=2)+'\n')
receipt={'edition':args.edition,'identity':identity,'sourceCommit':qa_run(['git','rev-parse','HEAD'],cwd=ROOT,capture_output=True,text=True,check=True).stdout.strip(),
         'cartridgeSHA1':hashlib.sha1(args.rom.read_bytes()).hexdigest(),'basePayloadSHA256':digest(args.payload),
         'runtimeAppSource':str(args.runtime_app.resolve()),'nativeRenderer':True,'hiddenWindow':True,
         'physicalIOSDeviceTested':False,'allModsDisabled':True,'fullImport':not bool(cache),
         'externalSaveRecoveryDisabled':True,'legacyMigrationDisabled':True,'candidateInputsSHA256':digest(out/'candidate-inputs.json'),
         'releaseStampPreserved':True,'compatibilityFieldsMatchSource':True,
         'cacheSource':str(previous)if previous else None,'status':'running'}
receipt['installedCacheInput']=bool(args.installed_profile)
if story:receipt['continuedOwnNormalStorySave']=story
(out/'verification.json').write_text(json.dumps(receipt,indent=2)+'\n')
if args.verify_story_continue:
    # The unchanged story driver first performs all native CONTINUE checks;
    # only then can it dispatch this ordinary verification command.
    (out/'story-commands.json').write_text(json.dumps([{'op':'verify-continue'}])+'\n')
env=dict(os.environ,POKEPORT_IDENTITY=identity,POKEPORT_VERSION=args.edition,POKEPORT_IMPORT_ROM=str(args.rom.resolve()),
         POKEPORT_DRIVER=str(engine/driver),POKEPORT_SPEED=str(args.speed),POKEPORT_NO_MODS='1',
         POKEPORT_NO_BOOT_REPORT='1',POKEPORT_NO_DISCORD='1',POKEPORT_SKIP_LEGACY_MIGRATION='1',POKEPORT_ISOLATED_TESTING='1',
         EDITION_QA_OUT=str(out))
print('EDITION_NATIVE_QA',out,flush=True)
with (out/'native.log').open('w')as log:
    child=qa_popen([str(runtime/'Contents/MacOS/love'),str(engine)],cwd=ROOT,env=env,stdout=log,stderr=-2)
    deadline=time.monotonic()+args.timeout
    try:
        while child.poll()is None:
            fatal=re.search(r'^(?:src/import/RomImporter\.lua:\d+:|driver error:)',(out/'native.log').read_text(errors='replace'),re.M)
            if fatal or time.monotonic()>deadline:
                receipt['stoppedOwnChildReason']='fatal importer error'if fatal else 'native QA timeout'
                child.terminate()
                try:child.wait(timeout=10)
                except subprocess.TimeoutExpired:child.kill();child.wait()
                break
            time.sleep(.5)
    finally:
        if child.poll()is None:child.kill();child.wait()
hashes=json.loads((out/'frozen-files.json').read_text())
assert all(digest(engine/name)==h for name,h in hashes.items()),'Frozen source changed'
receipt.update(exitCode=child.returncode,frozenSourceUnchanged=True)
receipt['unexpectedImporterRun']=bool(cache and re.search(r'^\[info\] Gen[123] maps:',(out/'native.log').read_text(errors='replace'),re.M))
result=out/'result.json'
if not result.is_file()and (profile/'edition-result.json').is_file():
    result.write_bytes((profile/'edition-result.json').read_bytes())
for capture in profile.glob('*.png'):(out/capture.name).write_bytes(capture.read_bytes())
receipt['status']='pass'if child.returncode==0 and not receipt['unexpectedImporterRun']and result.is_file()and json.loads(result.read_text())['status']=='pass'else 'fail'
(out/'verification.json').write_text(json.dumps(receipt,indent=2)+'\n')
assert receipt['status']=='pass',(out/'native.log').read_text(errors='replace')[-10000:]
print('PASS_NATIVE_EDITION',out,flush=True)
