// Native C API probe compiled only into owned QA hosts, never the released app.
// Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
extern "C" {
#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"
}
static int probe_capacity;
static int captured_sum(lua_State *state)
{
  lua_Number total=0;
  for (int i=1;i<=probe_capacity;++i) total+=lua_tonumber(state,lua_upvalueindex(i));
  lua_pushnumber(state,total);
  return 1;
}
extern "C" __attribute__((visibility("default"),used))
int roxas_runtime_capi_check(int capacity)
{
  if (capacity<1 || capacity>120) return 1;
  lua_State *state=luaL_newstate();
  if (!state) return 2;
  probe_capacity=capacity;
  if (!lua_checkstack(state,capacity+4)) {lua_close(state);return 3;}
  for (int i=1;i<=capacity;++i) lua_pushnumber(state,i);
  lua_pushcclosure(state,captured_sum,capacity);
  for (int round=0;round<10000;++round) {
    lua_pushvalue(state,1);
    if (lua_pcall(state,0,1,0)) {lua_close(state);return 4;}
    if (lua_tonumber(state,-1)!=capacity*(capacity+1)/2) {lua_close(state);return 5;}
    lua_settop(state,1);
    if (round%251==0) lua_gc(state,LUA_GCCOLLECT,0);
  }
  lua_close(state);
  return 0;
}
