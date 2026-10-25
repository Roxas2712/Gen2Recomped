"""Run a Lua check using the LuaJIT library bundled with the local LOVE install."""
import ctypes
import sys
import json
import os
from pathlib import Path
from qa_storage import qa_source

qa_source(Path(__file__).resolve().parents[1])
library = os.environ.get("RETRO_QA_LUA_LIBRARY", r"C:\Program Files\LOVE\lua51.dll")
qa_source(Path(library))

lua = ctypes.CDLL(library)
lua.luaL_newstate.restype = ctypes.c_void_p
lua.luaL_openlibs.argtypes = [ctypes.c_void_p]
lua.luaL_loadfile.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
lua.luaL_loadstring.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
lua.lua_pcall.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int]
lua.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_void_p]
lua.lua_tolstring.restype = ctypes.c_char_p
lua.lua_close.argtypes = [ctypes.c_void_p]
state = lua.luaL_newstate()
lua.luaL_openlibs(state)
arguments = ','.join('[' + str(i) + ']=' + json.dumps(value) for i, value in enumerate(sys.argv[1:]))
lua.luaL_loadstring(state, ('arg = {' + arguments + '}; package.searchers = package.searchers or package.loaders').encode())
lua.lua_pcall(state, 0, 0, 0)
code = (lua.luaL_loadstring(state, sys.argv[2].encode()) if sys.argv[1] == '-e'
        else lua.luaL_loadfile(state, sys.argv[1].encode()))
if not code:
    code = lua.lua_pcall(state, 0, -1, 0)
if code:
    print(lua.lua_tolstring(state, -1, None).decode(errors="replace"))
lua.lua_close(state)
sys.exit(bool(code))
