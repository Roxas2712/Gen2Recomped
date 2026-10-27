#!/usr/bin/env python3
"""Check reviewed runtime patch application. Contributions by Roxas2712."""
import atexit,json,sys
from pathlib import Path
root=Path(__file__).resolve().parents[1];sys.path.insert(0,str(root/'tools'));import qa_storage as qa;import pinball_rs
qa._storage=qa.Storage(root);atexit.register(qa._storage.close,collect=False)
for p in(root,root/'.local/pinball-rs',Path(sys.executable)):qa.qa_source(p)
out=root/'.local/qa/pinball-runtime-patch';qa.qa_cache(out);out.mkdir(parents=True,exist_ok=True)
patch=root/'tools/pinball-rs-native/runtime-fixes.patch'
old='\n'.join(line[1:]for line in patch.read_text().splitlines()if line.startswith((' ','-'))and not line.startswith('---'))+'\n'
fixture=out/'fixture';target=fixture/'src/runtime/runtime_arm_default_aborts.cpp';target.parent.mkdir(parents=True,exist_ok=True);target.write_text(old+'// unrelated local addition\n');qa.qa_run(['git','init','--quiet',str(fixture)],check=True)
pinball_rs.apply_runtime_fixes(fixture,qa);first=target.read_bytes();assert b'do { runtime_tick(64); }'in first
pinball_rs.apply_runtime_fixes(fixture,qa);assert target.read_bytes()==first and first.endswith(b'// unrelated local addition\n')
target.write_text('unrelated conflicting contents\n');before=target.read_bytes()
try:pinball_rs.apply_runtime_fixes(fixture,qa)
except RuntimeError:pass
else:raise AssertionError('Conflicting runtime edit must be refused')
assert target.read_bytes()==before
print("Runtime patch apply, repeat, conflict and preservation checks passed",flush=True)
