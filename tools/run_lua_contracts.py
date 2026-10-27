"""Run selected repository Lua contracts in fresh states under the QA guard."""
from pathlib import Path
import argparse
import ctypes
import json
import os
import sys
from qa_storage import qa_source,qa_run

ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--lua-library',type=Path,required=True)
p.add_argument('--test',action='append',default=[])
p.add_argument('--syntax',action='append',default=[])
p.add_argument('--worker',action='store_true',help=argparse.SUPPRESS)
a=p.parse_args();assert a.test or a.syntax
library=a.lua_library.resolve()
for name in a.test+a.syntax:
    path=(ROOT/name).resolve();assert path.is_relative_to(ROOT)and path.suffix=='.lua'and path.is_file(),name
if not a.worker:
    for source in (ROOT,library,Path(sys.executable)):qa_source(source)
    command=[sys.executable,__file__,'--worker','--lua-library',str(library)]
    for name in a.test:command+=['--test',name]
    for name in a.syntax:command+=['--syntax',name]
    result=qa_run(command,cwd=ROOT,capture_output=True,text=True)
    print(result.stdout,end='');print(result.stderr,end='',file=sys.stderr)
    count=len(a.test)+(1 if a.syntax else 0)
    assert result.returncode==0 and ('PASS_LUA_CONTRACT_JOBS '+str(count))in result.stdout,'Not every Lua job completed'
    raise SystemExit()
os.chdir(ROOT)
lua=ctypes.CDLL(str(library));lua.luaL_newstate.restype=ctypes.c_void_p
lua.luaL_openlibs.argtypes=[ctypes.c_void_p]
lua.luaL_loadstring.argtypes=[ctypes.c_void_p,ctypes.c_char_p]
lua.lua_pcall.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_int,ctypes.c_int]
lua.lua_tolstring.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_void_p];lua.lua_tolstring.restype=ctypes.c_char_p
lua.lua_close.argtypes=[ctypes.c_void_p]
jobs=['\n'.join('assert(loadfile('+json.dumps(name)+'))'for name in a.syntax)]if a.syntax else []
jobs+=['dofile('+json.dumps(name)+')'for name in a.test]
for code in jobs:
    state=lua.luaL_newstate();lua.luaL_openlibs(state)
    status=lua.luaL_loadstring(state,('_G.POKEPORT_TEST_CHILD=true\n'+code).encode())
    if not status:status=lua.lua_pcall(state,0,0,0)
    if status:print(lua.lua_tolstring(state,-1,None).decode(errors='replace'),file=sys.stderr)
    lua.lua_close(state)
    if status:raise SystemExit(1)
print('PASS_LUA_CONTRACT_JOBS',len(jobs))
