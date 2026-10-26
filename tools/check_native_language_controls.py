#!/usr/bin/env python3
"""Run the existing language controls against the migrated native modules."""
import argparse, json
from pathlib import Path
from qa_storage import qa_source,qa_cache,qa_run

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--mod',type=Path,required=True);ap.add_argument('--lua',type=Path,required=True)
    ap.add_argument('--out',type=Path,required=True);a=ap.parse_args()
    root=Path(__file__).resolve().parents[1];mod=a.mod.resolve();lua=a.lua.resolve();out=a.out.resolve()
    for p in (root,mod,lua):qa_source(p)
    qa_cache(out);out.mkdir(parents=True,exist_ok=True)
    harness=out/'native-controls.lua'
    harness.write_text('''local modRoot,suite=arg[1],arg[2]
local original=dofile
dofile=function(path)
 local relative=path:sub(1,#modRoot+5)==modRoot..'/mod/' and path:sub(#modRoot+6)
 if relative then
  local native=relative:match('^fork/(.+)$')or relative:match('^@host/(.+)$')
  if native then return original('src/translation/rompack/'..native)end
 end
 return original(path)
end
arg={modRoot}
assert(loadfile(modRoot..'/tests/'..suite..'.lua'))()
''')
    suites=['fork_cosmetic_link_unit','fork_display_unit','fork_ui_unit','fork_title_unit','fork_asian_unit','fork_gifts_unit','fork_parity_unit','fork_gba_unit','fork_pc_unit','classic_item_box_unit','gen3_summary_unit']
    results=[]
    for suite in suites:
        log=out/(suite+'.log')
        with log.open('w') as f:p=qa_run([str(lua),str(harness),str(mod),suite],cwd=root,stdout=f,stderr=f)
        results.append(dict(suite=suite,passed=p.returncode==0))
        print(suite,p.returncode,flush=True)
        if p.returncode:print(log.read_text()[-2500:],flush=True)
    (out/'receipt.json').write_text(json.dumps(dict(passed=all(r['passed']for r in results),runs=results),indent=2)+'\n')
    assert all(r['passed']for r in results),'Native control regression failed'

if __name__=='__main__':main()
