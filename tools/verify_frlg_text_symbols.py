"""Verify native FRLG text-window symbol offsets against matching retail ELFs."""
from pathlib import Path
import argparse,hashlib,json
from gen3_sibling_manifest import Symbols
NAMES=('gMenuMessageWindow_Gfx','gSignpostWindow_Gfx','gStdTextWindow_Gfx','gTextWindowPalettes')
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--rom',type=Path,required=True);p.add_argument('--elf',type=Path,required=True)
p.add_argument('--manifest',type=Path,required=True);p.add_argument('--update',action='store_true')
a=p.parse_args();rom=a.rom.read_bytes();manifest=json.loads(a.manifest.read_text())
assert hashlib.sha1(rom).hexdigest()==manifest['romSha1']
symbols=Symbols(a.elf,rom);rows={}
for name in NAMES:
 candidates=symbols.by_name[name];assert len(candidates)==1,name
 row=candidates[0];rows[name]=row['at']
 if not a.update:assert manifest['symbols'][name]==row['at'],name
if a.update:
 # Preserve existing source formatting and every unrelated manifest field.
 raw=a.manifest.read_text();indent='    'if '\n  "symbols": {'in raw else'  '
 key='"symbols": {';assert raw.count(key)==1
 insert='\n'.join(indent+'"'+name+'": '+str(at)+','for name,at in rows.items())
 assert not any('"'+name+'":'in raw for name in rows)
 raw=raw.replace(key,key+'\n'+insert,1)
 assert json.loads(raw)==dict(manifest,symbols=dict(manifest['symbols'],**rows))
 a.manifest.write_text(raw)
print(json.dumps({'edition':manifest['version'],'verifiedBytes':symbols.checked_bytes,'symbols':rows}))
