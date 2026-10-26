#!/usr/bin/env python3
"""Build a local macOS app from the qualified native language-pack sources."""
import argparse, hashlib, json, plistlib, shutil
from pathlib import Path
from qa_storage import qa_source,qa_run

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--runtime',type=Path,required=True)
    p.add_argument('--mod',type=Path,required=True)
    p.add_argument('--qa',type=Path,required=True)
    p.add_argument('--out',type=Path,required=True)
    a=p.parse_args();root=Path(__file__).resolve().parents[1]
    for value in (root,a.runtime,a.mod,a.qa):qa_source(value.resolve())
    qa=json.loads(a.qa.read_text());assert qa['passed'],'Native language matrix must pass before packaging'
    out=a.out.resolve();out.mkdir(parents=True,exist_ok=True)
    qa_run(['python3',str(a.mod.resolve()/'tools/package.py'),'--engine',str(root),'--qa',str(a.qa.resolve())],cwd=root,check=True)
    payload=out/'RetroRecomped-Native-UniLanguage.love'
    qa_run(['bash',str(root/'scripts/pack_love.sh'),'--engine-only','--output',str(payload)],cwd=root,check=True)
    import zipfile
    with zipfile.ZipFile(payload) as z:
        # Every source bound by the real-ROM receipt must be packed exactly.
        h=hashlib.sha256()
        for name in sorted(z.namelist(),key=Path):
            if name.startswith('src/') and not name.endswith('/'):
                h.update(name.encode());h.update(z.read(name))
        assert h.hexdigest()==qa['engineSourceSha256'],'Packaged engine differs from the tested sources'
        assert not any(name.lower().endswith(('.gb','.gbc','.gba','.sav')) for name in z.namelist())
    # Use the engine's existing pinned-preview channel: a stable self-update
    # must not replace this locally qualified native implementation.
    with zipfile.ZipFile(payload,'a',compression=zipfile.ZIP_DEFLATED)as z:
        z.writestr('love12_preview.lua','return {channel="native-uni-language"}\n')
    app=out/'RetroRecomped Uni-Language Native.app'
    if app.exists():raise FileExistsError(app)
    shutil.copytree(a.runtime.resolve(),app,symlinks=True)
    resources=app/'Contents/Resources';resources.mkdir(exist_ok=True)
    shutil.copy2(payload,resources/'game.love')
    plist=app/'Contents/Info.plist'
    info=plistlib.loads(plist.read_bytes())
    info.update(CFBundleName='RetroRecomped Uni-Language Native',CFBundleDisplayName='RetroRecomped Uni-Language Native',CFBundleIdentifier='com.roxas2712.retrorecomped.native-language')
    plist.write_bytes(plistlib.dumps(info))
    qa_run(['codesign','--force','--deep','--sign','-',str(app)],check=True)
    qa_run(['codesign','--verify','--deep','--strict',str(app)],check=True)
    target=out/'RetroRecomped-UniLanguage-Native-macOS.zip'
    qa_run(['ditto','-c','-k','--sequesterRsrc','--keepParent',str(app),str(target)],check=True)
    version=json.loads((a.mod/'mod/manifest.json').read_text())['version']
    modZip=a.mod/'dist'/f'uni-language-ascendant-{version}.zip'
    shutil.copy2(modZip,out/modZip.name)
    (out/'Native-Language-QA.json').write_text(json.dumps(qa,indent=2)+'\n')
    (out/'README-DE.txt').write_text('Native Uni-Language für deinen Fork\n\n1. RetroRecomped Uni-Language Native.app starten.\n2. uni-language-ascendant-'+version+'.zip im Modmanager installieren/aktualisieren und aktivieren.\n3. Englisches Basisspiel und passende Sprach-ROM importieren. Bei GBA die englische Basis einmal zusätzlich im Mod-Imports-Menü angeben.\n4. ASCENDANT → UNI-LANGUAGE oder F8 öffnen und Sprache auswählen.\n\nKein separater Gen2-Konvertierungsschritt. Bestehende Spielstände werden durch den Sprachwechsel nicht geschrieben.\n\nGeprüft: die im QA-Bericht aufgeführten deutschen ROMs und nativen Abläufe. Andere Sprachen sind dadurch nicht vollständig zertifiziert.\nLokaler macOS-Build mit Ad-hoc-Signatur; keine Veröffentlichung oder Notarisierung.\n')
    sums=[]
    for file in (payload,target,out/modZip.name):sums.append(hashlib.sha256(file.read_bytes()).hexdigest()+'  '+file.name)
    (out/'SHA256SUMS.txt').write_text('\n'.join(sums)+'\n')
    print(target)

if __name__=='__main__':main()
