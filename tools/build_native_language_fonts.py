#!/usr/bin/env python3
"""Rebuild the offline launcher glyph subsets from a pinned upstream Noto TTC.

Requires fonttools. The input is NotoSansCJK-Regular.ttc from
notofonts/noto-cjk f8d157532fbfaeda587e826d4cd5b21a49186f7c,
Sans/OTC/. No game cartridge or network input is read by this tool.
"""
from pathlib import Path
import argparse, hashlib, json, unicodedata
from fontTools import subset
from fontTools.ttLib import TTFont

ROOT=Path(__file__).resolve().parents[1]

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('ttc',type=Path)
    args=ap.parse_args()
    # The exact upstream input is recorded alongside the redistributed subset.
    digest=hashlib.sha256(args.ttc.read_bytes()).hexdigest()
    pinned=json.loads((ROOT/'mods/UNI_LANGUAGE_NATIVE/fonts/BUILD.json').read_text())
    assert digest==pinned['sourceSha256'],'Unexpected font source; review provenance before replacing the pinned input'
    chars=set(range(32,256))
    for root in (ROOT/'src',ROOT/'mods/UNI_LANGUAGE_NATIVE'):
        for path in sorted(root.rglob('*.lua')):
            chars.update(map(ord,path.read_text(errors='replace')))
    chars.update(c for c in range(0x3040,0x3100) if unicodedata.category(chr(c))!='Cn')
    for index,region in enumerate(('jp','kr','sc','tc')):
        font=TTFont(args.ttc,fontNumber=index,recalcTimestamp=False)
        missing=chars-set(font.getBestCmap())
        # Some scripts unrelated to CJK (and nonprinting controls) deliberately
        # use the normal launcher font. Every CJK character must be present.
        assert not any(0x3000<=c<=0xD7AF for c in missing),sorted(missing)
        options=subset.Options();options.name_IDs=['*'];options.name_legacy=True
        options.name_languages=['*'];options.notdef_outline=True
        sub=subset.Subsetter(options=options);sub.populate(unicodes=chars);sub.subset(font)
        family='AscendantLauncher'+region.upper()
        for record in font['name'].names:
            if record.nameID in (1,3,4,6,16):record.string=family.encode(record.getEncoding())
        if 'CFF ' in font:
            cff=font['CFF '].cff;cff.fontNames=[family]
            cff.topDictIndex[0].FamilyName=family;cff.topDictIndex[0].FullName=family
        target=ROOT/f'mods/UNI_LANGUAGE_NATIVE/fonts/ascendant-{region}.otf'
        font.save(target)
        print(region,len(font.getBestCmap()),target.stat().st_size)

if __name__=='__main__':main()
