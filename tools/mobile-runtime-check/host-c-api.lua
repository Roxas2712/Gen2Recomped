-- Exercise high-index C closures through the app's actual exported Lua API.
return function(capacity, platform)
  if jit and jit.status() then jit.off(true, true) end
  local ffi = require('ffi')
  ffi.cdef[[
    typedef struct lua_State lua_State;
    typedef int (*gen2_lua_CFunction)(lua_State *);
    lua_State *luaL_newstate(void);
    void lua_close(lua_State *);
    int lua_checkstack(lua_State *, int);
    void lua_pushnumber(lua_State *, double);
    double lua_tonumber(lua_State *, int);
    void lua_pushcclosure(lua_State *, gen2_lua_CFunction, int);
    int lua_pcall(lua_State *, int, int, int);
    void lua_settop(lua_State *, int);
    int lua_gc(lua_State *, int, int);
    void lua_pushvalue(lua_State *, int);
  ]]
  local api = platform == 'android' and ffi.load('love') or ffi.C
  local state = assert(api.luaL_newstate())
  local callback
  local ok, why = pcall(function()
    callback = ffi.cast('gen2_lua_CFunction', function(inner)
      local total = 0
      for i = 1, capacity do total = total + api.lua_tonumber(inner, -10002-i) end
      api.lua_pushnumber(inner, total)
      return 1
    end)
    assert(api.lua_checkstack(state, capacity+4) ~= 0)
    for i = 1, capacity do api.lua_pushnumber(state, i) end
    api.lua_pushcclosure(state, callback, capacity)
    for round = 1, 1000 do
      api.lua_pushvalue(state, 1)
      assert(api.lua_pcall(state, 0, 1, 0) == 0, 'actual host C closure failed')
      assert(api.lua_tonumber(state, -1) == capacity*(capacity+1)/2)
      api.lua_settop(state, 1)
      if round%251 == 0 then api.lua_gc(state, 2, 0) end
    end
  end)
  api.lua_close(state)
  if callback then callback:free() end
  assert(ok, why)
end
