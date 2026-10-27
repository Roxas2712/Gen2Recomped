#!/usr/bin/env python3
"""Run the isolated PKHeX checker against native records from an owned import."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import sys
import time
from qa_storage import qa_source, qa_cache, qa_run

ROOT = Path(__file__).resolve().parents[1]

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--cache', type=Path, required=True)
    p.add_argument('--dotnet', type=Path, required=True)
    p.add_argument('--checker', type=Path, required=True)
    a = p.parse_args()
    cache, dotnet, checker = (x.resolve(strict=True) for x in (a.cache, a.dotnet, a.checker))
    for x in (ROOT, cache, dotnet.parent, checker.parent, Path(os.environ['RETRO_QA_LUA_LIBRARY'])):
        qa_source(x)
    output = ROOT / '.local/qa' / ('retro-bank-legality-' + str(time.time_ns()))
    qa_cache(output); output.mkdir(parents=True, mode=0o700)
    script = output / 'native-records.lua'
    script.write_text("""package.path='./?.lua;./?/init.lua;'..package.path
love=require('tests.love_stub')
local V=require('src.core.GameVersion');V.set('red')
local D=require('src.core.Data');D:load();require('src.mods.Loader').new({noMods=true}):load(D)
local P=require('src.pokemon.Pokemon');local mon=P.new(D,'PIKACHU',30)
mon.ot='ASH';mon.otId=1234
local R=require('src.storage.LegalityRecord');local J=require('src.link.Json')
local function write(name)
 local record=R.export({source={version='red'},mon=mon},D)
 local f=assert(io.open(arg[1]..'/'..name..'.json','wb'));f:write(J.encode(record));f:close()
end
write('native-legal')
local pp=mon.moves[1].pp;mon.moves[1].pp=999
assert(not pcall(R.export,{source={version='red'},mon=mon},D),'Illegal PP must be rejected before the cartridge codec can clamp it')
mon.moves[1].pp=pp
local f=assert(io.open(arg[1]..'/bank-input.json','wb'));f:write(J.encode({schema=1,edition='red',entry={schema=1,source={version='red'},canonical={dex=25},mon=mon}}));f:close()
local psychic=assert(require('src.save_convert.GenSave').crosswalks(D).movesByIndex[94])
mon.moves={{id=psychic,pp=10}}
write('impossible-move')
""")
    with (output / 'native.log').open('wb') as log:
        qa_run([sys.executable, str(ROOT / 'tools/run_lua_check.py'), str(script), str(output)], cwd=ROOT,
               env=os.environ | {'POKEPORT_DATA_DIR': str(cache / 'data/generated')}, stdout=log, stderr=log, check=True)
    results = {}
    for case in ('native-legal', 'impossible-move'):
        with (output / (case + '.json')).open('rb') as source:
            result = qa_run([str(dotnet), str(checker)], stdin=source, capture_output=True, check=True)
        results[case] = json.loads(result.stdout)
    assert results['native-legal']['parsed'] and results['native-legal']['valid'], results['native-legal']
    assert results['impossible-move']['parsed'] and not results['impossible-move']['valid'], results['impossible-move']
    assert any(not m['valid'] for m in results['impossible-move']['moves'])
    from bank_legality_worker import process
    raw = (output / 'bank-input.json').read_text()
    full = process({'input': raw, 'input_digest': hashlib.sha256(raw.encode()).hexdigest()},
                   {'root': str(ROOT), 'datasets': {'red': str(cache)}, 'dotnet': str(dotnet), 'checker': str(checker),
                    'lua': [sys.executable, str(ROOT / 'tools/run_lua_check.py')]}, run=qa_run)
    assert full['parsed'] and full['valid'], full
    results['private-worker'] = full
    (output / 'report.json').write_text(json.dumps({'passed': True, 'checker': 'PKHeX.Core/26.10.18', 'cases': results}, indent=2))
    print('BANK_LEGALITY_PASS', output, flush=True)

if __name__ == '__main__':
    main()
