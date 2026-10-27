"""Audit reviewed German text used by the account/community launcher views.

This is a source audit, not a claim about arbitrary user/mod text or every
engine language. The same inventory feeds optional launcher translation.
"""
# Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
import argparse
import json
from pathlib import Path
import re
import sys
import os
import shutil
import time
from qa_storage import qa_source, qa_cache, qa_run

ROOT = Path(__file__).resolve().parents[1]
FILES = ['src/import/BankPages.lua', 'src/import/BankWorkspace.lua',
         'src/import/TournamentWorkspace.lua', 'src/import/AccountWorkspace.lua',
         'src/import/ArenaShopView.lua', 'src/import/ArenaPresentation.lua',
         'src/import/GiftDesigner.lua', 'src/ui/RetroOverlay.lua', 'src/ui/FriendsMenu.lua',
         'src/import/FirstRun.lua', 'src/cloud/BankVerification.lua', 'src/translation/AccountErrors.lua']
TOKEN = re.compile(r'--\[(=*)\[[\s\S]*?\]\1\]|--[^\n]*|\[(=*)\[[\s\S]*?\]\2\]|"(?:[^"\\]|\\.)*"|\'(?:[^\'\\]|\\.)*\'|[A-Za-z_][A-Za-z_0-9]*|==|~=|\.\.|[^\s]')

def decode(token):
    if token[:1] not in ('"', "'"):
        return None
    # Source inventory only: never evaluate Lua, names or remote content.
    value = token[1:-1]
    escapes = {'n': '\n', 'r': '\r', 't': '\t', '\\': '\\', '"': '"', "'": "'"}
    return re.sub(r'\\([nrt\\"\'])', lambda m: escapes[m[1]], value)

def collect(root=ROOT):
    rows = {}
    for filename in FILES:
        source = (root / filename).read_text()
        tokens = [(m.group(), m.start()) for m in TOKEN.finditer(source) if not m.group().startswith('--')]
        def record(start, offset=0):
            nesting = 0; calls = []; previous = None
            for token, position in tokens[start:]:
                if token in ('(', '{', '['):
                    nesting += 1
                    calls.append('__index' if token == '[' else previous if token == '(' and previous and re.match(r'^[A-Za-z_]', previous) and previous not in {'and','or','not'} else None)
                if token in (')', '}', ']'):
                    if nesting == 0: break
                    nesting -= 1
                    if calls: calls.pop()
                if nesting == 0 and token == ',':
                    if offset: offset -= 1;continue
                    break
                if offset: continue
                text = decode(token)
                if text and re.search(r'[A-Za-z]{2}', text) and previous not in {'==','~='} and not any(c and c not in {'L','F','tostring'} for c in calls):
                    rows.setdefault(text, []).append(filename + ':' + str(source.count('\n', 0, position) + 1))
                previous = token
        for i, (token, _) in enumerate(tokens[:-2]):
            if token in {'text', 'paragraph', 'para', 'line', 'button', 'row', 'field', 'check', 'L', 'F', 'launcherLookup', 'launcherFormat'} and tokens[i+1][0] == '(':
                record(i+2,offset=1 if filename.endswith('FirstRun.lua')and token=='button'else 0)
            elif token == 'label' and tokens[i+1][0] == '(':
                record(i+2, offset=1)
            elif token in {'notice', 'label', 'note'} and tokens[i+1][0] == '=':
                text = decode(tokens[i+2][0])
                if text and re.search(r'[A-Za-z]{2}', text):
                    rows.setdefault(text, []).append(filename + ':' + str(source.count('\n', 0, tokens[i+2][1]) + 1))
            elif filename.endswith('BankVerification.lua') and token == 'nil' and tokens[i+1][0] == ',':
                text = decode(tokens[i+2][0])
                if text: rows.setdefault(text, []).append(filename)
    return rows

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--inventory', action='store_true', help='Print source strings and call sites without executing Lua.')
    args = parser.parse_args()
    qa_source(ROOT);qa_source(Path(sys.executable))
    if os.environ.get('RETRO_QA_LUA_LIBRARY'):qa_source(Path(os.environ['RETRO_QA_LUA_LIBRARY']))
    lua=shutil.which('luajit')
    if lua:qa_source(Path(lua))
    rows = collect()
    if args.inventory:
        print(json.dumps(rows, ensure_ascii=False, indent=2));return
    # Only bounded source inventory reaches the existing guarded Lua runner.
    output=ROOT/'.local/qa'/('launcher-locale-audit-'+str(time.time_ns()))
    qa_cache(output);output.mkdir(parents=True,exist_ok=True)
    inventory=output/'inventory.json';inventory.write_text(json.dumps(rows,ensure_ascii=False))
    source = 'love=require("tests.love_stub");local C=require("src.translation.LauncherCatalog").de;local N=require("src.translation.NativeLanguageCatalog").de;local J=require("src.link.Json");local file=assert(io.open('+json.dumps(str(inventory),ensure_ascii=False)+',"rb"));local rows=J.decode(file:read("*a"));file:close();local missing={};for text,sites in pairs(rows)do if not C[text]and not N[text]then missing[#missing+1]={text=text,sites=sites}end end;table.sort(missing,function(a,b)return a.text<b.text end);print(J.encode({missing=missing}));assert(#missing==0,"Unreviewed launcher strings")'
    command=[lua,'-e',source]if lua else [sys.executable,str(ROOT/'tools/run_lua_check.py'),'-e',source]
    result = qa_run(command,cwd=ROOT,timeout=60,capture_output=True)
    sys.stdout.buffer.write(result.stdout);sys.stderr.buffer.write(result.stderr)
    if result.returncode==0:print(json.dumps({"reviewedSourceStrings":len(rows),"views":len(FILES),"language":"de","passed":True}),flush=True)
    raise SystemExit(result.returncode)

if __name__ == '__main__':
    main()
