#!/usr/bin/env python3
"""Check reviewed runtime patch application. Contributions by Roxas2712."""
import atexit,json,sys
from pathlib import Path
root=Path(__file__).resolve().parents[1];sys.path.insert(0,str(root/'tools'));import qa_storage as qa;import pinball_rs
qa._storage=qa.Storage(root);atexit.register(qa._storage.close,collect=False)
for p in(root,root/'.local/pinball-rs',Path(sys.executable)):qa.qa_source(p)
out=root/'.local/qa/pinball-runtime-patch';qa.qa_cache(out);out.mkdir(parents=True,exist_ok=True)
patch=root/'tools/pinball-rs-native/runtime-fixes.patch'
runtime=root/'.local/pinball-rs/gbarecomp'
paths=[line.split(' b/',1)[1]for line in patch.read_text().splitlines()if line.startswith('diff --git ')]
fixture=out/'fixture';fixture.mkdir(parents=True,exist_ok=True)
qa.qa_run(['git','init','--quiet',str(fixture)],check=True)
original={}
for path in paths:
    data=qa.qa_run(['git','-C',str(runtime),'show',pinball_rs.RUNTIME+':'+path],capture_output=True,check=True).stdout
    original[path]=data+b'// unrelated local addition\n'
    target=fixture/path;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(original[path])
# Upgrade an installation that already has only the earlier HALT correction.
qa.qa_run(['git','-C',str(fixture),'apply','--include=src/runtime/runtime_arm_default_aborts.cpp',str(patch)],check=True)
pinball_rs.apply_runtime_fixes(fixture,qa)
first={path:(fixture/path).read_bytes()for path in paths}
assert b'do { runtime_tick(64); }'in first['src/runtime/runtime_arm_default_aborts.cpp']
assert b'PixelCandidate object_pixels'in first['src/gba/gba_ppu.cpp']
pinball_rs.apply_runtime_fixes(fixture,qa)
assert all((fixture/path).read_bytes()==data and data.endswith(b'// unrelated local addition\n')for path,data in first.items())
# A later-file conflict must leave an earlier pending file untouched.
for path,data in original.items():(fixture/path).write_bytes(data)
target=fixture/'src/runtime/runtime_arm_default_aborts.cpp';target.write_text('unrelated conflicting contents\n')
before={path:(fixture/path).read_bytes()for path in paths}
try:pinball_rs.apply_runtime_fixes(fixture,qa)
except RuntimeError:pass
else:raise AssertionError('Conflicting runtime edit must be refused')
assert all((fixture/path).read_bytes()==data for path,data in before.items())
print("Runtime patches: previous-build upgrade, repeat, conflict and all-file preservation passed",flush=True)
