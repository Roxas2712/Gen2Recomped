-- Run:  luajit tools/bytecode_cache_check.lua
--
-- C1 -- GENERATED MODULES FROM THEIR BYTECODE SIDECARS.
--
-- The dump must be the chunk the source is (same table back), it must be
-- ignored when older than its source or unreadable by this VM, the writer
-- must leave it beside the source under the cache writer, and the searcher
-- must hand `require` the dump ahead of the source for data.generated.* and
-- the per-version data.generated_*.* trees.  No LÖVE, ROM or window: the
-- filesystem is a table.

package.path = './?.lua;./?/init.lua;' .. package.path

local PASS, FAIL = 0, 0
local function check(cond, label)
  if cond then PASS = PASS + 1 else FAIL = FAIL + 1; print('FAIL: ' .. label) end
end
local function deepEqual(a, b)
  if type(a) ~= type(b) then return false end
  if type(a) ~= 'table' then return a == b end
  for k, v in pairs(a) do if not deepEqual(v, b[k]) then return false end end
  for k in pairs(b) do if a[k] == nil then return false end end
  return true
end

-- a filesystem in a table, with modtimes
local files, times, clock = {}, {}, 100
local function write(path, bytes) clock = clock + 1; files[path] = bytes; times[path] = clock; return true end
local function read(path) return files[path] end
local function info(path, kind)
  if files[path] == nil then return nil end
  return { type = 'file', size = #files[path], modtime = times[path] }
end
package.loaded['src.import.CacheFs'] = { write = write, read = read }
love = { filesystem = { read = read, getInfo = info } }

local Performance = require('src.core.Performance')
check(Performance.bytecodeCache == true, 'C1 is on by default')
local B = require('src.core.BytecodeCache')
local LuaWriter = require('src.import.LuaWriter')

-- ------------------------------------------------------- 1. dump round trip
local value = { constants = { A = 1, B = 'two', C = { 3, 4, 5 } }, list = {}, text = { 'x', 'y' } }
for i = 1, 500 do value.list[i] = { id = i, name = 'entry' .. i, flags = { i % 2 == 0, i % 3 == 0 } } end
local source = LuaWriter.encodeSplit(value)
local bytes, err = B.dump(source, '@probe.lua')
check(bytes ~= nil, 'string.dump of the encoded source succeeds (' .. tostring(err) .. ')')
check(bytes and bytes:sub(1, 1) == '\27', 'the dump is a binary chunk')
check(bytes and #bytes < #source, 'the stripped dump is smaller than the source')
local chunk = bytes and (loadstring or load)(bytes, '@probe.luac')
check(chunk ~= nil, 'this VM loads the dump back')
check(chunk and deepEqual(chunk(), value), 'the dump evaluates to the same table as the source')
check(deepEqual((loadstring or load)(source)(), value), '(and the source still does)')

-- ------------------------------------------------- 2. the writer's sidecar
LuaWriter.write('data/generated/probe.lua', value)
check(files['data/generated/probe.lua'] == source, 'the source is written as before')
check(files['data/generated/probe.luac'] ~= nil, 'a .luac sidecar is written beside it')
check(times['data/generated/probe.luac'] > times['data/generated/probe.lua'], 'the sidecar is newer than its source')
check(deepEqual((loadstring or load)(files['data/generated/probe.luac'])(), value), 'the sidecar is the module')

-- ---------------------------------------------------- 3. loadSidecar rules
do
  local c = B.loadSidecar('data/generated/probe.lua', read, info)
  check(c ~= nil and deepEqual(c(), value), 'a fresh sidecar is loaded')
  -- the source is rewritten later: the sidecar is now stale
  write('data/generated/probe.lua', source)
  check(B.loadSidecar('data/generated/probe.lua', read, info) == nil, 'a sidecar older than its source is ignored')
  -- rewritten through the writer: fresh again
  LuaWriter.write('data/generated/probe.lua', value)
  check(B.loadSidecar('data/generated/probe.lua', read, info) ~= nil, 'the writer restores a fresh sidecar')
  -- a sidecar this VM cannot load: the source is used, no error raised
  write('data/generated/broken.lua', 'return { ok = true }')
  write('data/generated/broken.luac', '\27LJ\2garbage')
  local okCall, result = pcall(B.loadSidecar, 'data/generated/broken.lua', read, info)
  check(okCall and result == nil, 'an unloadable sidecar is ignored without raising')
  check(B.loadSidecar('data/generated/missing.lua', read, info) == nil, 'no sidecar, no answer')
  -- the switch
  Performance.bytecodeCache = false
  check(B.loadSidecar('data/generated/probe.lua', read, info) == nil, 'the flag turns the reader off')
  check(B.writeSidecar('data/generated/off.lua', 'return 1') == false, 'and the writer')
  Performance.bytecodeCache = true
end

-- ------------------------------------------------------- 4. the searcher
do
  check(B.install() == true, 'the searcher installs against love.filesystem')
  check(B.install() == true, 'installing twice is a no-op')
  package.loaded['data.generated.probe'] = nil
  local before = B.hits or 0
  local loaded = require('data.generated.probe')
  check(deepEqual(loaded, value), 'require answers the module from the sidecar')
  check((B.hits or 0) == before + 1, 'and it was the sidecar that answered')
  -- a per-version tree takes the same path
  LuaWriter.write('data/generated_gen2_gold/probe2.lua', { gold = true })
  package.loaded['data.generated_gen2_gold.probe2'] = nil
  local gold = require('data.generated_gen2_gold.probe2')
  check(gold and gold.gold == true, 'data.generated_<version>.* is served from its sidecar too')
  -- a module without a sidecar falls through to the next searcher (which, with
  -- no file to find, reports the module missing -- the searcher adds no error)
  package.loaded['data.generated.nothing'] = nil
  local okR, msg = pcall(require, 'data.generated.nothing')
  check(not okR and tostring(msg):find("module 'data.generated.nothing' not found", 1, true) ~= nil,
        'a module with no sidecar is left to the ordinary searchers')
end

print(('%d checks, %d failed'):format(PASS + FAIL, FAIL))
if FAIL > 0 then os.exit(1) end
