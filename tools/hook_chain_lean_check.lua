-- Differential check for the lean hook-chain walk (src/mods/Hooks.lua, H1).
--   luajit tools/hook_chain_lean_check.lua
-- Every case below -- pass-through, rewritten arguments, next() without
-- arguments, a link that throws before / after next, a vanilla that
-- throws, a link that swallows the vanilla error and then throws, a link
-- that never calls next, one that calls it twice, three links by priority,
-- a nested hook, the Gen 3 callback facade, and the profiler on -- runs
-- once through Hooks:callLean and once through Hooks:callClassic.  The
-- returns, the error raised, the vanilla call count, every Logger.warn
-- line and every FrameProfile.add label must be identical.  Then a quick
-- allocation count shows the lean walk is the lighter one.

package.path = "./?.lua;./?/init.lua;" .. package.path

-- stubs the module reaches for; both walks see the same ones
local warns, labels = {}, {}
package.loaded["src.core.Logger"] = {
  warn = function(fmt, ...) warns[#warns + 1] = string.format(fmt, ...) end,
  info = function() end, error = function() end,
}
local profOn = false
package.loaded["src.core.FrameProfile"] = {
  enabled = function() return profOn end,
  now = function() return os.clock() end,
  add = function(name) labels[#labels + 1] = name end,
}
local Hooks = require("src.mods.Hooks")
local unpack = table.unpack or unpack
local function pack(...) return { n = select("#", ...), ... } end

local n = 0
local function fail(msg) error(msg, 2) end
local function same(a, b, what)
  n = n + 1
  if type(a) == "table" and type(b) == "table" then
    if a.n ~= b.n then fail(what .. ": count " .. tostring(a.n) .. " vs " .. tostring(b.n)) end
    for i = 1, (a.n or #a) do
      if a[i] ~= b[i] then fail(what .. ": slot " .. i .. " " .. tostring(a[i]) .. " vs " .. tostring(b[i])) end
    end
    if not a.n then
      for i = 1, math.max(#a, #b) do
        if a[i] ~= b[i] then fail(what .. ": line " .. i .. "\n  " .. tostring(a[i]) .. "\n  " .. tostring(b[i])) end
      end
    end
  elseif a ~= b then
    fail(what .. ": " .. tostring(a) .. " vs " .. tostring(b))
  end
end

-- a case builds a chain on a fresh bus and returns what to call
local SENT = { tag = "sentinel" }
local cases = {}
local function case(name, build) cases[#cases + 1] = { name = name, build = build } end

case("pass-through, multiple returns with a nil hole", function(h, v)
  h:wrap("seam", function(nxt, a, b) return nxt(a, b) end, 0, "m1")
  return v(function(a, b) return a, nil, b, SENT end), 1, 2
end)
case("rewritten arguments", function(h, v)
  h:wrap("seam", function(nxt, a, b) return nxt(a * 2, b + 1) end, 0, "m1")
  return v(function(a, b) return a + b end), 10, 5
end)
case("next() with no arguments keeps the originals", function(h, v)
  h:wrap("seam", function(nxt, a) return nxt() end, 0, "m1")
  return v(function(a) return a end), SENT
end)
case("link throws before next: skipped, vanilla once", function(h, v)
  h:wrap("seam", function(nxt, a) error("boom") end, 0, "m1")
  return v(function(a) return a * 3 end), 7
end)
case("link throws after next: downstream kept", function(h, v)
  h:wrap("seam", function(nxt, a) local r = nxt(a + 1); error("late") end, 0, "m1")
  return v(function(a) return a, "tail" end), 1
end)
case("vanilla throws: propagates raw, not retried", function(h, v)
  h:wrap("seam", function(nxt, a) return nxt(a) end, 0, "m1")
  return v(function(a) error("vanilla-" .. tostring(a), 0) end), 4
end)
case("link swallows the vanilla error then throws", function(h, v)
  h:wrap("seam", function(nxt, a) pcall(nxt, a); error("after-swallow") end, 0, "m1")
  return v(function(a) error("vanilla-down", 0) end), 4
end)
case("link never calls next", function(h, v)
  h:wrap("seam", function(nxt, a) return "short", a end, 0, "m1")
  return v(function(a) return "vanilla" end), 9
end)
case("link calls next twice", function(h, v)
  h:wrap("seam", function(nxt, a) local x = nxt(a); local y = nxt(a + 1); return x + y end, 0, "m1")
  return v(function(a) return a * 10 end), 1
end)
case("three links by priority, middle one throws", function(h, v)
  h:wrap("seam", function(nxt, s) return nxt(s .. "a") end, 1, "low")
  h:wrap("seam", function(nxt, s) error("mid") end, 5, "mid")
  h:wrap("seam", function(nxt, s) return nxt(s .. "c") .. "C" end, 9, "high")
  return v(function(s) return s .. "|" end), ">"
end)
case("nested hook inside a link", function(h, v)
  h:wrap("inner", function(nxt, x) return nxt(x + 100) end, 0, "m2")
  h:wrap("seam", function(nxt, a)
    local inner = h:call("inner", function(x) return x * 2 end, a)
    return nxt(inner)
  end, 0, "m1")
  return v(function(a) return a - 1 end), 1
end)
case("Gen 3 callback facade routes the link", function(h, v)
  package.loaded["src.core.Game3"] = {
    _usesCallbacks = function(owner) return owner == "g3mod" end,
    _invokeHook = function(owner, cb, nxt, ...) return cb(nxt, "facade", ...) end,
  }
  h:wrap("seam", function(nxt, tag, a) return nxt(tag .. ":" .. a) end, 0, "g3mod")
  h:wrap("seam", function(nxt, a) return nxt(a) end, -1, "plain")
  return v(function(s) return s end), "x"
end)

case("profiler toggled inside a link", function(h,v)
  h:wrap('seam',function(nxt,...)
    local was=profOn;profOn=not was
    local result=pack(nxt(...))
    profOn=was
    return unpack(result,1,result.n)
  end,10,'toggle')
  h:wrap('seam',function(nxt,...)return nxt(...)end,0,'inside')
  return v(function(a)return a,nil,42 end),SENT
end)

local function runAll(lean)
  Hooks.lean = lean
  local out = {}
  for _, c in ipairs(cases) do
    package.loaded["src.core.Game3"] = nil
    warns, labels = {}, {}
    local h = Hooks.new()
    local calls = 0
    local vanilla
    local args = pack(c.build(h, function(f)
      vanilla = function(...) calls = calls + 1; return f(...) end
      return vanilla
    end))
    local res = pack(pcall(h.call, h, "seam", args[1], unpack(args, 2, args.n)))
    out[c.name] = { res = res, calls = calls, warns = warns,
                    labels = labels, err = (not res[1]) and tostring(res[2]) or nil }
  end
  package.loaded["src.core.Game3"] = nil
  return out
end

for _, prof in ipairs({ false, true }) do
  profOn = prof
  local lean, classic = runAll(true), runAll(false)
  for _, c in ipairs(cases) do
    local what = c.name .. (prof and " [profiler on]" or "")
    local a, b = lean[c.name], classic[c.name]
    same(a.res, b.res, what .. " returns")
    same(a.err, b.err, what .. " error")
    same(a.calls, b.calls, what .. " vanilla calls")
    same(a.warns, b.warns, what .. " warnings")
    same(a.labels, b.labels, what .. " profile labels")
    if prof and #a.labels == 0 and not a.err and a.calls > 0 then
      -- every case with a link that ran must have reported it
      local hasLink = true
      if hasLink then same(#a.labels > 0, true, what .. " profiled at least one link") end
    end
  end
end
profOn = false

-- the point of it: fewer allocations per call on the lean walk
local function allocs(lean)
  Hooks.lean = lean
  local h = Hooks.new()
  for i = 1, 9 do h:wrap("render.compose", function(nxt, ctx) return nxt(ctx) end, i, "mod" .. i) end
  local vanilla = function(ctx) return ctx end
  local ctx = {}
  for _ = 1, 200 do h:call("render.compose", vanilla, ctx) end
  collectgarbage("collect"); collectgarbage("stop")
  local before = collectgarbage("count")
  for _ = 1, 1000 do h:call("render.compose", vanilla, ctx) end
  local used = collectgarbage("count") - before
  collectgarbage("restart")
  return used
end
local leanKb, classicKb = allocs(true), allocs(false)
n = n + 1
if not (leanKb < classicKb * 0.7) then
  fail(("lean walk should allocate well under the classic one: %.0f KB vs %.0f KB"):format(leanKb, classicKb))
end

print(("hook_chain_lean_check: %d checks ok; 9-link seam x1000: lean %.0f KB, classic %.0f KB")
  :format(n, leanKb, classicKb))
