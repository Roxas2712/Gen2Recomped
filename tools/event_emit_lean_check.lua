-- Check for the lean event emit (src/mods/Events.lua, E1).
--   luajit tools/event_emit_lean_check.lua
-- A single listener that unsubscribes itself mid-emit, a listener that
-- unsubscribes a sibling, once(), a throwing listener, priority order and
-- the profiler label all behave as before; then the single-listener emit
-- is shown to allocate nothing per call.

package.path = "./?.lua;./?/init.lua;" .. package.path

local errors, labels = {}, {}
package.loaded["src.core.Logger"] = {
  error = function(fmt, ...) errors[#errors + 1] = string.format(fmt, ...) end,
  warn = function() end, info = function() end,
}
local profOn = false
local function noop() end -- FrameProfile.section shares this while disabled.
package.loaded["src.core.FrameProfile"] = {
  section = function(name)
    if profOn then labels[#labels + 1] = name end
    return noop
  end,
}
local Events = require("src.mods.Events")
local Performance = require('src.core.Performance')
local n = 0
local function eq(a, b, what)
  n = n + 1
  if a ~= b then error(("%s: got %s, want %s"):format(what, tostring(a), tostring(b)), 2) end
end

-- 1. one listener retiring itself mid-emit: runs once, never again
local e = Events.new()
local hits = 0
local off
off = e:on("tick", function() hits = hits + 1; off() end, 0, "m1")
e:emit("tick", {}); e:emit("tick", {})
eq(hits, 1, "self-retiring single listener fires once")
eq(e.listeners.tick, nil, "an emptied name drops its key")

-- 2. once() on a list of one
e = Events.new(); hits = 0
e:once("tick", function() hits = hits + 1 end, 0, "m1")
e:emit("tick"); e:emit("tick")
eq(hits, 1, "once() fires once")

-- 3. a listener that removes its sibling mid-emit: the sibling still gets
--    this emit (snapshot semantics), not the next
e = Events.new()
local order = {}
local offB
e:on("tick", function() order[#order + 1] = "a"; offB() end, 5, "a")
offB = e:on("tick", function() order[#order + 1] = "b" end, 1, "b")
e:emit("tick")
eq(table.concat(order), "ab", "sibling removed mid-emit still runs for this emit")
e:emit("tick")
eq(table.concat(order), "aba", "and not for the next")

-- 4. a throwing listener is logged and the rest run
e = Events.new(); order = {}
e:on("tick", function() error("bad") end, 9, "bad")
e:on("tick", function() order[#order + 1] = "ok" end, 1, "good")
e:emit("tick", {})
eq(#errors, 1, "throwing listener logged")
eq(order[1], "ok", "later listener still runs")

-- 5. profiler label unchanged in text
e = Events.new(); labels = {}; profOn = true
e:on("world.tick", function() end, 0, "DRAMATIC_SHAPE")
e:emit("world.tick", {}); e:emit("world.tick", {})
eq(labels[1], "  mod DRAMATIC_SHAPE: world.tick", "label text")
eq(labels[2], labels[1], "label is the same string each emit")
profOn = false

-- Compare the switch paths under reentrant registration, removal and owner
-- changes. Labels for owners with a changing __tostring must remain live.
local function trace(lean)
  Performance.eventLean=lean
  errors,labels={},{};profOn=true
  local bus,out=Events.new(),{}
  local offB
  bus:on('nested',function(value)
    out[#out+1]='a'..value
    if value==1 then
      offB()
      bus:on('nested',function(v)out[#out+1]='c'..v end,0,'new')
      bus:emit('nested',2)
    end
  end,10,'outer')
  offB=bus:on('nested',function(v)out[#out+1]='b'..v end,0,'removed')
  bus:emit('nested',1)
  bus.listeners.nested[1].owner='renamed'
  bus:emit('nested',3)
  local tag='first'
  local owner=setmetatable({},{__tostring=function()return tag end})
  bus:on('dynamic',function()end,0,owner)
  bus:emit('dynamic');tag='second';bus:emit('dynamic')
  profOn=false
  return table.concat(out,','),table.concat(labels,'|'),table.concat(errors,'|')
end
local ta,la,ea=trace(true)
local tb,lb,eb=trace(false)
eq(ta,tb,'reentrant event trace agrees with classic')
eq(la,lb,'owner/name labels agree with classic after mutation')
eq(ea,eb,'error attribution agrees with classic')
eq(ta,'a1,a2,c2,b1,a3,c3','outer dispatch retains its original snapshot')
Performance.eventLean=true

-- 6. a single-listener emit allocates nothing
-- Exclude JIT recorder metadata from this Lua-heap measurement: the warmup
-- and measured loops have different bytecode positions and may record new
-- traces even after the emitter itself is warm.
local jitWasOn=jit and jit.status()
if jitWasOn then jit.off() end
e = Events.new()
e:on("world.tick", function(p) return p end, 0, "m1")
local payload = {}
for _ = 1, 200 do e:emit("world.tick", payload) end
collectgarbage("collect"); collectgarbage("stop")
local before = collectgarbage("count")
for _ = 1, 10000 do e:emit("world.tick", payload) end
local used = collectgarbage("count") - before
Performance.eventLean=false
local classicBefore=collectgarbage('count')
for _=1,10000 do e:emit('world.tick',payload)end
local classicUsed=collectgarbage('count')-classicBefore
Performance.eventLean=true
collectgarbage("restart")
if jitWasOn then jit.on() end
n = n + 1
if used > 1 then error(("single-listener emit should not allocate: %.1f KB over 10000 emits"):format(used)) end
eq(classicUsed>used+100,true,'classic snapshot allocation is observable in the same probe')

print(("event_emit_lean_check: %d checks ok; 10000 single-listener emits, JIT off: lean %.1f KB, classic %.1f KB"):format(n, used,classicUsed))
