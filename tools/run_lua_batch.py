"""Run isolated LuaJIT states under one guarded QA process."""
# Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
import argparse
import ctypes
import json
import os
from pathlib import Path
from qa_storage import qa_source

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--syntax', action='append', default=[])
parser.add_argument('--suite', action='append', default=[])
parser.add_argument('--legacy-bank-source')
args = parser.parse_args()
library = Path(os.environ['RETRO_QA_LUA_LIBRARY'])
for path in [root, library]:
    qa_source(path)
if args.legacy_bank_source:
    qa_source(Path(args.legacy_bank_source))
lua = ctypes.CDLL(str(library))
lua.luaL_newstate.restype = ctypes.c_void_p
lua.luaL_openlibs.argtypes = [ctypes.c_void_p]
lua.luaL_loadfile.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
lua.luaL_loadstring.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
lua.lua_pcall.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int]
lua.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_void_p]
lua.lua_tolstring.restype = ctypes.c_char_p
lua.lua_close.argtypes = [ctypes.c_void_p]


def run(source=None, path=None, arguments=None):
    # A new VM per suite preserves the process-per-suite module/global isolation.
    state = lua.luaL_newstate()
    if not state:
        raise RuntimeError('Cannot allocate an isolated LuaJIT state')
    try:
        lua.luaL_openlibs(state)
        argv = ','.join('[' + str(i) + ']=' + json.dumps(value) for i, value in enumerate(arguments or []))
        setup = ('arg={' + argv + '};package.searchers=package.searchers or package.loaders').encode()
        code = lua.luaL_loadstring(state, setup)
        if not code:
            code = lua.lua_pcall(state, 0, 0, 0)
        if not code:
            code = lua.luaL_loadstring(state, source.encode()) if source is not None else lua.luaL_loadfile(state, os.fsencode(path))
        if not code:
            code = lua.lua_pcall(state, 0, -1, 0)
        if code:
            error = lua.lua_tolstring(state, -1, None)
            raise RuntimeError(error.decode(errors='replace') if error else 'Unknown Lua failure')
    finally:
        lua.lua_close(state)


if args.syntax:
    run(source='\n'.join('assert(loadfile(' + json.dumps(path) + '))' for path in args.syntax))
for path in args.suite:
    argv = [path]
    if Path(path).name == 'bank_interop.lua' and args.legacy_bank_source:
        argv.append(args.legacy_bank_source)
    run(path=path, arguments=argv)
