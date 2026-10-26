#!/usr/bin/env python3
"""Build a local macOS app with built-in, first-run Uni-Language setup."""
import argparse, hashlib, json, plistlib, shutil
from pathlib import Path
from qa_storage import qa_source,qa_run

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--runtime',type=Path,required=True)
    p.add_argument('--qa',type=Path,required=True)
    p.add_argument('--out',type=Path,required=True)
    a=p.parse_args();root=Path(__file__).resolve().parents[1]
    for value in (root,a.runtime,a.qa):qa_source(value.resolve())
    qa=json.loads(a.qa.read_text());assert qa['passed'],'Clean native language setup must pass before packaging'
    assert {r['game']for r in qa['runs']if r['passed']}=={'gold','emerald'},'Clean GB/GBC and GBA setup evidence is required'
    from check_builtin_language_setup import fingerprint
    assert fingerprint(list((root/'src').rglob('*.lua')),root)==qa['engineLuaSha256'],'Engine Lua changed after native setup QA'
    assert fingerprint([v for v in (root/'mods/UNI_LANGUAGE_NATIVE').rglob('*')if v.is_file()],root)==qa['bundledPayloadSha256'],'Bundled profiles changed after native setup QA'
    out=a.out.resolve();out.mkdir(parents=True,exist_ok=True)
    payload=out/'RetroRecomped-Native-UniLanguage.love'
    qa_run(['bash',str(root/'scripts/pack_love.sh'),'--engine-only','--output',str(payload)],cwd=root,check=True)
    import zipfile
    with zipfile.ZipFile(payload) as z:
        # Every source bound by the real-ROM receipt must be packed exactly.
        h=hashlib.sha256()
        for name in sorted(z.namelist(),key=Path):
            if name.startswith('src/') and name.endswith('.lua'):
                h.update(name.encode());h.update(z.read(name))
        assert h.hexdigest()==qa['engineLuaSha256'],'Packaged engine differs from the tested sources'
        h=hashlib.sha256()
        for name in sorted(z.namelist(),key=Path):
            if name.startswith('mods/UNI_LANGUAGE_NATIVE/') and not name.endswith('/'):
                h.update(name.encode());h.update(z.read(name))
        assert h.hexdigest()==qa['bundledPayloadSha256'],'Packaged language component differs from the tested payload'
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
    (out/'Native-Language-QA.json').write_text(json.dumps(qa,indent=2)+'\n')
    (out/'README-DE.txt').write_text('Integriertes Uni-Language für deinen Fork\n\n1. App starten und im Einrichtungsdialog die Sprache wählen.\n2. Unterstützte US-ROM importieren. Danach bietet der Launcher die Spielsprache an und erklärt die exakten Quellen.\n3. Benötigte Sprach-ROM im Dialog hinzufügen und Sprache bestätigen. Die GBA-Basis wird beim US-Import automatisch hinterlegt.\n\nKein separates Mod-ZIP und keine Gen2-Konvertierung. Später ändern: Einstellungen > Spielsprache > Spielsprache (ROM), im aktiven Sprachpaket auch F8.\n\nJapanisch: Kristall. Koreanisch: Gold/Silber (Spielprofile weiterhin Vorschau). Chinesisch: Einrichtungs-/Menüsprache, kein Spielprofil. PT-BR-Menüs ohne zusätzliche ROM; die Spielübersetzung benötigt derzeit die angegebene Fanübersetzungs-ROM. Keine ROMs enthalten.\n\nGeprüft: sauberer Erststart und echte deutsche Gold-/Smaragd-Abläufe laut QA-Bericht; weitere Profile sind dadurch nicht vollständig zertifiziert. Vorhandene Rubin/Saphir-Berichtsüberlagerungen bleiben bestehen.\nLokaler macOS-Build mit Ad-hoc-Signatur; keine Veröffentlichung oder Notarisierung.\n')
    sums=[]
    for file in (payload,target):sums.append(hashlib.sha256(file.read_bytes()).hexdigest()+'  '+file.name)
    (out/'SHA256SUMS.txt').write_text('\n'.join(sums)+'\n')
    print(target)

if __name__=='__main__':main()
