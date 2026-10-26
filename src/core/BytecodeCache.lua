-- C1 -- GENERATED DATA AS BYTECODE, NEXT TO ITS SOURCE.
--
-- Every module the importers write under data/generated (and the per-version
-- data/generated_* trees) is a Lua source file that `require` parses again on
-- every boot: the Gen 3/4 caches run to a couple of megabytes each (map
-- layouts, joint matrices, text tables), and parsing a megabyte of table
-- constructors is seconds of CPU on a handheld before the first frame.
--
-- LuaJIT compiles a chunk once and `string.dump` writes the result; loading
-- that back skips the parser entirely, five to ten times faster for data of
-- this shape.  So `LuaWriter.write` leaves a stripped dump beside each
-- source as `<name>.luac`, and a `package` searcher ahead of LÖVE's own tries
-- the dump before the source.  The source stays authoritative:
--
--   * a dump older than its source is ignored (the modtime says so);
--   * a dump the running VM cannot load -- another LuaJIT, plain Lua, a
--     truncated file -- fails `load` and the source is used, once per boot
--     with a log line;
--   * `Performance.bytecodeCache = false` or POKEPORT_NO_BYTECODE=1 turns the
--     whole thing off, reader and writer.
--
-- Nothing else changes: the searcher answers exactly the module the source
-- would have (the dump IS that chunk), `package.loaded` behaves as before,
-- and a cache written without dumps loads as it always did.
local Performance = require("src.core.Performance")

local M = {}

M.SUFFIX = "c"          -- foo.lua -> foo.luac

local function enabled()
  if os.getenv and os.getenv("POKEPORT_NO_BYTECODE") == "1" then return false end
  return Performance.bytecodeCache ~= false
end
M.enabled = enabled

-- the compile-and-dump half, shared by the writer and the tests
function M.dump(source, chunkname)
  if not (string.dump and (loadstring or load)) then return nil, "no string.dump" end
  local chunk, err = (loadstring or load)(source, chunkname)
  if not chunk then return nil, err end
  local ok, bytes = pcall(string.dump, chunk, true)
  if not ok or type(bytes) ~= "string" or #bytes == 0 then return nil, bytes end
  return bytes
end

-- Called by LuaWriter after the source landed.  Never raises: a missing dump
-- is a slower boot, not a failed import.
function M.writeSidecar(path, source)
  if not enabled() then return false end
  if not path:match("%.lua$") then return false end
  local bytes = M.dump(source, "@" .. path)
  if not bytes then return false end
  local CacheFs = require("src.import.CacheFs")
  local ok = pcall(CacheFs.write, path .. M.SUFFIX, bytes)
  return ok and true or false
end

-- Is `luacPath` a usable stand-in for `luaPath`?  `info` is love.filesystem's
-- getInfo (or a shim's), so the modtime rule is the same on every platform.
local function fresh(info, luaPath, luacPath)
  local c = info(luacPath, "file")
  if not c then return false end
  local s = info(luaPath, "file")
  if s and s.modtime and c.modtime and c.modtime < s.modtime then return false end
  return true
end
M.fresh = fresh

local warned = {}
local function warnOnce(path, err)
  if warned[path] then return end
  warned[path] = true
  local ok, Logger = pcall(require, "src.core.Logger")
  if ok and Logger and Logger.warn then
    Logger.warn("bytecode cache: %s ignored (%s) -- loading the source", path, tostring(err))
  end
end

-- Load the dump for module path `luaPath`, or nil when the source should be
-- used.  `read(path)` returns the bytes; `info` as above.  Exposed so the
-- CacheFs shim (which reads the cache itself) can take the same decision.
function M.loadSidecar(luaPath, read, info)
  if not enabled() then return nil end
  local luacPath = luaPath .. M.SUFFIX
  if not fresh(info, luaPath, luacPath) then return nil end
  local bytes = read(luacPath)
  if type(bytes) ~= "string" or #bytes == 0 then return nil end
  local chunk, err = (loadstring or load)(bytes, "@" .. luacPath)
  if not chunk then warnOnce(luacPath, err); return nil end
  M.hits = (M.hits or 0) + 1
  return chunk
end

-- the searcher for the ordinary mounted cache: data.generated.<leaf> and the
-- per-version data.generated_<ver>.<leaf> trees
local installed = false
function M.install()
  if installed then return true end
  if not (love and love.filesystem and love.filesystem.getInfo) then return false end
  local searchers = package.searchers or package.loaders
  if not searchers then return false end
  installed = true
  table.insert(searchers, 1, function(name)
    local tree, leaf = name:match("^data%.(generated[%w_]*)%.(.+)$")
    if not tree then return nil end
    local luaPath = "data/" .. tree .. "/" .. leaf:gsub("%.", "/") .. ".lua"
    local chunk = M.loadSidecar(luaPath,
      function(p) return love.filesystem.read(p) end,
      function(p, kind) return love.filesystem.getInfo(p, kind) end)
    if chunk then return chunk end
    return nil        -- the next searcher loads the source as before
  end)
  return true
end

return M
