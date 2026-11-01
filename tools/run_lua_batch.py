"""Run isolated LuaJIT states under one guarded QA process."""
# Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
import argparse
import ctypes
import json
import os
import sys
from pathlib import Path
from qa_storage import qa_source

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--syntax', action='append', default=[])
parser.add_argument('--suite', action='append', default=[])
parser.add_argument('--legacy-bank-source')
parser.add_argument('--keep-going', action='store_true', help='Report every suite; any failure still fails the run.')
parser.add_argument('--rumble-source')
args = parser.parse_args()
library = Path(os.environ['RETRO_QA_LUA_LIBRARY'])
for path in [root, library]:
    qa_source(path)
if args.legacy_bank_source:
    qa_source(Path(args.legacy_bank_source))
if args.rumble_source:
    qa_source(Path(args.rumble_source))
lua = ctypes.CDLL(str(library))
lua.luaL_newstate.restype = ctypes.c_void_p
lua.luaL_openlibs.argtypes = [ctypes.c_void_p]
lua.luaL_loadfile.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
lua.luaL_loadstring.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
lua.lua_pcall.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int]
lua.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_void_p]
lua.lua_tolstring.restype = ctypes.c_char_p
lua.lua_getfield.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_char_p]
lua.lua_topointer.argtypes = [ctypes.c_void_p, ctypes.c_int]
lua.lua_topointer.restype = ctypes.c_void_p
lua.lua_settop.argtypes = [ctypes.c_void_p, ctypes.c_int]
lua.lua_tointeger.argtypes = [ctypes.c_void_p, ctypes.c_int]
lua.lua_tointeger.restype = ctypes.c_ssize_t
lua.lua_close.argtypes = [ctypes.c_void_p]


def run(source=None, path=None, arguments=None):
    # A new VM per suite preserves the process-per-suite module/global isolation.
    state = lua.luaL_newstate()
    if not state:
        raise RuntimeError('Cannot allocate an isolated LuaJIT state')
    try:
        lua.luaL_openlibs(state)
        argv = ','.join('[' + str(i) + ']=' + json.dumps(value, ensure_ascii=False) for i, value in enumerate(arguments or []))
        setup = ('arg={' + argv + '};package.searchers=package.searchers or package.loaders;' + '''
local exitToken={};_RETRO_QA_EXIT_TOKEN=exitToken
os.exit=function(status)
  local code
  if status==nil or status==true then code=0
  elseif status==false then code=1
  elseif type(status)=='number' and status%1==0 then code=status
  else error('Invalid suite exit status',2) end
  _RETRO_QA_EXIT_CODE=code
  error(exitToken,0)
end
''').encode()
        code = lua.luaL_loadstring(state, setup)
        if not code:
            code = lua.lua_pcall(state, 0, 0, 0)
        if code:
            error = lua.lua_tolstring(state, -1, None)
            raise RuntimeError('Lua suite setup failed: ' + (error.decode(errors='replace') if error else 'unknown error'))
        lua.lua_getfield(state, -10002, b'_RETRO_QA_EXIT_TOKEN')
        exit_token = lua.lua_topointer(state, -1)
        lua.lua_settop(state, 0)
        code = lua.luaL_loadstring(state, source.encode()) if source is not None else lua.luaL_loadfile(state, os.fsencode(path))
        if not code:
            code = lua.lua_pcall(state, 0, -1, 0)
        if code:
            error = lua.lua_tolstring(state, -1, None)
            if exit_token and lua.lua_topointer(state, -1) == exit_token:
                lua.lua_getfield(state, -10002, b'_RETRO_QA_EXIT_CODE')
                status = lua.lua_tointeger(state, -1)
                if status == 0:
                    return
                raise RuntimeError('Suite requested exit status ' + str(status))
            raise RuntimeError(error.decode(errors='replace') if error else 'Unknown Lua failure')
    finally:
        lua.lua_close(state)


if args.syntax:
    run(source='\n'.join('assert(loadfile(' + json.dumps(path, ensure_ascii=False) + '))' for path in args.syntax))
completed, failures = 0, []
for path in args.suite:
    argv = [path]
    if Path(path).name == 'bank_interop.lua' and args.legacy_bank_source:
        argv.append(args.legacy_bank_source)
    if Path(path).name == 'controller_rumble_module.lua' and args.rumble_source:
        argv.append(args.rumble_source)
    try:
        run(path=path, arguments=argv)
    except RuntimeError as error:
        if not args.keep_going:
            raise
        failures.append(path)
        print('FAILED Lua suite: ' + path + ': ' + str(error), file=sys.stderr, flush=True)
    else:
        completed += 1
        print('Completed Lua suite: ' + path, flush=True)
if args.suite:
    print('Lua suites completed: ' + str(completed) + '/' + str(len(args.suite)), flush=True)
if failures:
    raise SystemExit(1)
