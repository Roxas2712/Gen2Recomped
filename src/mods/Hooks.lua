local Logger = require("src.core.Logger")
local FrameProfile = require("src.core.FrameProfile")

local Hooks = {}
Hooks.__index = Hooks
local unpack = table.unpack or unpack

local function pack(...) return { n = select("#", ...), ... } end

-- errors raised below the chain (the vanilla function itself) must not be
-- attributed to a mod link or retried; they ride out wrapped under this key
-- so every guard re-raises instead of skipping
local PASS = {}

function Hooks.new()
  return setmetatable({ chains = {} }, Hooks)
end

-- owner is the wrapping mod id; failures are attributed to it
function Hooks:wrap(name, callback, priority, owner)
  assert(type(name) == "string" and name ~= "", "hook name is required")
  assert(type(callback) == "function", "hook callback must be a function")
  local chain = self.chains[name] or {}
  self.chains[name] = chain
  local entry = { callback = callback, priority = priority or 0, owner = owner }
  chain[#chain + 1] = entry
  table.sort(chain, function(a, b) return a.priority > b.priority end)
  return function()
    for i, candidate in ipairs(chain) do
      if candidate == entry then table.remove(chain, i) break end
    end
  end
end

-- each link runs under pcall: a throwing wrapper is logged and skipped and
-- the chain continues with the current arguments, so a broken mod degrades
-- to "not installed for this call" instead of breaking the pipeline.
-- vanilla must run at most once per call -- it has side effects -- so a link
-- that throws after its next() returned keeps the downstream results (its
-- post-processing is discarded) rather than re-walking the chain, and a link
-- that swallowed a vanilla error then threw propagates instead of retrying
-- WHICH REGISTRATION, not just which mod.
--
-- One mod wrapping the same seam nine times reads as one 46 ms line, and
-- "DRAMATIC_SHAPE is slow" is not something anybody can act on.  A callback
-- knows the file and line it was written at, so the label carries them and the
-- report names the nine places instead of the one mod.  Cached weakly on the
-- callback: debug.getinfo is not free and this runs inside the frame.
local siteCache = setmetatable({}, { __mode = "k" })

local function siteOf(entry)
  local fn = entry and entry.callback
  local hit = fn and siteCache[fn]
  if hit then return hit end
  local who = tostring(entry and entry.owner or "?")
  if type(fn) == "function" and debug and debug.getinfo then
    local ok, info = pcall(debug.getinfo, fn, "S")
    if ok and info and info.short_src then
      who = who .. " @ " .. info.short_src:gsub("^%./", "")
        .. ":" .. tostring(info.linedefined or 0)
    end
  end
  if fn then siteCache[fn] = who end
  return who
end

-- H1 -- THE SAME CHAIN, FEWER TABLES.
--
-- Pass pcall results as varargs, retaining argument and downstream packs
-- only where the existing fallback rules need them. Continuation state is
-- private to each call; timing storage is allocated only for measured links.
-- Hooks.lean (Performance.hookLean at load) selects the classic walk for
-- differential checks and rollback. Each mod still gets its own next closure.
Hooks.lean = true
do
  local ok, Performance = pcall(require, "src.core.Performance")
  if ok and type(Performance) == "table" and Performance.hookLean == false then
    Hooks.lean = false
  end
end

-- the error path of one link, shared by the vanilla-threw and link-threw
-- cases; receives the pcall result as varargs so success costs no table
local function afterLink(st, index, entry, started, ok, ...)
  if started then
    FrameProfile.add("      hook " .. tostring(st.name) .. " <- "
      .. siteOf(entry),
      (FrameProfile.now() - started) - st.below[index])
  end
  if ok then return ... end
  local err = ...
  if type(err) == "table" and err[PASS] ~= nil then error(err, 0) end
  if st.downstream[index] ~= nil then
    local d = st.downstream[index]
    Logger.warn("[%s] hook %s failed after next: %s -- downstream result kept",
      tostring(entry.owner or "?"), st.name, tostring(err))
    return unpack(d, 1, d.n)
  end
  if st.ranVanilla then
    Logger.warn("[%s] hook %s failed: %s -- vanilla already ran, not retried",
      tostring(entry.owner or "?"), st.name, tostring(err))
    error({ [PASS] = err }, 0)
  end
  Logger.warn("[%s] hook %s failed: %s -- link skipped",
    tostring(entry.owner or "?"), st.name, tostring(err))
  return st.run(st, index + 1)
end

local function afterVanilla(ok, ...)
  if ok then return ... end
  error({ [PASS] = (...) }, 0)
end

local function runLean(st, index)
  local chain = st.chain
  if index > #chain then
    st.ranVanilla = true
    local args = st.args
    return afterVanilla(pcall(st.vanilla, unpack(args, 1, args.n)))
  end
  local entry = chain[index]
  -- Shared arrays belong to this call, not to its registered entries. They
  -- retain nested/rewritten argument behavior without two tables per link.
  st.downstream[index] = nil
  local measuring = FrameProfile.enabled()
  if measuring then
    st.below = st.below or {}
    st.below[index] = 0
  end
  local function nextFn(...)
    local t0 = measuring and FrameProfile.now() or nil
    local d
    if select("#", ...) == 0 then
      d = pack(runLean(st, index + 1))
    else
      local saved = st.args
      st.args = pack(...)
      d = pack(runLean(st, index + 1))
      st.args = saved
    end
    st.downstream[index] = d
    if t0 then st.below[index] = st.below[index] + (FrameProfile.now() - t0) end
    return unpack(d, 1, d.n)
  end
  local started = measuring and FrameProfile.now() or nil
  local args = st.args
  local facade = package.loaded['src.core.Game3']
  if facade and facade._usesCallbacks and facade._usesCallbacks(entry.owner) then
    return afterLink(st, index, entry, started,
      pcall(facade._invokeHook, entry.owner, entry.callback, nextFn, unpack(args, 1, args.n)))
  end
  return afterLink(st, index, entry, started,
    pcall(entry.callback, nextFn, unpack(args, 1, args.n)))
end

local function afterChain(ok, ...)
  if ok then return ... end
  local err = ...
  if type(err) == "table" and err[PASS] ~= nil then error(err[PASS], 0) end
  error(err, 0)
end

function Hooks:callLean(name, vanilla, ...)
  local chain = self.chains[name]
  if not chain or #chain == 0 then return vanilla(...) end
  local st = { chain = chain, name = name, vanilla = vanilla,
               args = pack(...), downstream = {},
               ranVanilla = false, run = runLean }
  return afterChain(pcall(runLean, st, 1))
end

function Hooks:call(name, vanilla, ...)
  if Hooks.lean then return self:callLean(name, vanilla, ...) end
  return self:callClassic(name, vanilla, ...)
end

function Hooks:callClassic(name, vanilla, ...)
  local chain = self.chains[name]
  if not chain or #chain == 0 then return vanilla(...) end
  local args = pack(...)
  local ranVanilla = false
  local function run(index)
    if index > #chain then
      ranVanilla = true
      local res = pack(pcall(vanilla, unpack(args, 1, args.n)))
      if res[1] then return unpack(res, 2, res.n) end
      error({ [PASS] = res[2] }, 0)
    end
    local entry = chain[index]
    local downstream
    -- EACH LINK'S OWN TIME, which is the only number that means anything here.
    -- A link calls `next` into the rest of the chain, so its wall time
    -- includes every link below it and the vanilla at the bottom; timing the
    -- bracket alone would charge the outermost mod with the whole seam.  So
    -- the time spent inside `next` is accumulated separately and subtracted.
    -- Zero cost when the profiler is off: `now()` is not called at all.
    local measuring = FrameProfile.enabled()
    local below = 0
    local function nextFn(...)
      local t0 = measuring and FrameProfile.now() or nil
      if select("#", ...) == 0 then
        downstream = pack(run(index + 1))
      else
        local saved = args
        args = pack(...)
        downstream = pack(run(index + 1))
        args = saved
      end
      if t0 then below = below + (FrameProfile.now() - t0) end
      return unpack(downstream, 1, downstream.n)
    end
    local started = measuring and FrameProfile.now() or nil
    local facade = package.loaded['src.core.Game3']
    local res
    if facade and facade._usesCallbacks and facade._usesCallbacks(entry.owner) then
      res = pack(pcall(facade._invokeHook, entry.owner, entry.callback, nextFn, unpack(args, 1, args.n)))
    else
      res = pack(pcall(entry.callback, nextFn, unpack(args, 1, args.n)))
    end
    if started then
      FrameProfile.add("      hook " .. tostring(name) .. " <- "
        .. siteOf(entry),
        (FrameProfile.now() - started) - below)
    end
    if res[1] then return unpack(res, 2, res.n) end
    local err = res[2]
    if type(err) == "table" and err[PASS] ~= nil then error(err, 0) end
    if downstream ~= nil then
      Logger.warn("[%s] hook %s failed after next: %s -- downstream result kept",
        tostring(entry.owner or "?"), name, tostring(err))
      return unpack(downstream, 1, downstream.n)
    end
    if ranVanilla then
      Logger.warn("[%s] hook %s failed: %s -- vanilla already ran, not retried",
        tostring(entry.owner or "?"), name, tostring(err))
      error({ [PASS] = err }, 0)
    end
    Logger.warn("[%s] hook %s failed: %s -- link skipped",
      tostring(entry.owner or "?"), name, tostring(err))
    return run(index + 1)
  end
  local res = pack(pcall(run, 1))
  if res[1] then return unpack(res, 2, res.n) end
  local err = res[2]
  if type(err) == "table" and err[PASS] ~= nil then error(err[PASS], 0) end
  error(err, 0)
end

-- drops every wrap a mod made; used by entry-chunk rollback
function Hooks:removeOwner(owner)
  if owner == nil then return end
  for name, chain in pairs(self.chains) do
    for i = #chain, 1, -1 do
      if chain[i].owner == owner then table.remove(chain, i) end
    end
    if #chain == 0 then self.chains[name] = nil end
  end
end

-- deprecated no-op: wrapping stays legal for the life of the process
function Hooks:seal() end

return Hooks
