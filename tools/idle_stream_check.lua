-- Check for the idle-time asset stream pump (src/core/IdleStream.lua, W0).
--   luajit tools/idle_stream_check.lua
-- A stub asset_stream records the slices it is offered.  The pump offers
-- nothing when no job is queued, nothing on a slice too small to enter a
-- coroutine, the idle time minus the margin when that is less than the
-- tier's cap, the cap otherwise (HIGH 6 ms, BALANCED 3 ms, LOW 2 ms),
-- nothing with the switch off, and the GC budget runs first in the chain.
-- Then the real asset_stream's busy()/update(budget) are exercised with
-- stub services.

package.path = "./?.lua;./?/init.lua;" .. package.path
love = nil

local n = 0
local function eq(a, b, what)
  n = n + 1
  if a ~= b then error(("%s: got %s, want %s"):format(what, tostring(a), tostring(b)), 2) end
end
local function near(a, b, what)
  n = n + 1
  if math.abs(a - b) > 1e-9 then error(("%s: got %.6f, want %.6f"):format(what, a, b), 2) end
end

local offered, queued = {}, true
package.loaded["src.core.game3.asset_stream"] = {
  busy = function() return queued end,
  update = function(budget) offered[#offered + 1] = budget end,
}
local IdleStream = require("src.core.IdleStream")
local Performance = require("src.core.Performance")
local timer = { now = 0 }
function timer.getTime() return timer.now end

Performance.tier = "high"
-- 1. plenty of idle time: the HIGH cap
IdleStream.run(timer, 0.012)
near(offered[1], 0.006, "HIGH: capped at 6 ms")
-- 2. less idle time than the cap: idle minus margin
IdleStream.run(timer, 0.004)
near(offered[2], 0.004 - IdleStream.MARGIN_SECONDS, "a short idle offers idle minus margin")
-- 3. too small a slice
eq(IdleStream.run(timer, 0.0005), 0, "a slice under MIN is not offered")
eq(#offered, 2, "...and update was not called")
-- 4. nothing queued
queued = false
eq(IdleStream.run(timer, 0.012), 0, "no queued job, no slice")
queued = true
-- 5. tiers
Performance.tier = "balanced"
IdleStream.run(timer, 0.012); near(offered[#offered], 0.003, "BALANCED: 3 ms")
Performance.tier = "low"
IdleStream.run(timer, 0.012); near(offered[#offered], 0.002, "LOW: 2 ms")
Performance.tier = "high"
-- 6. switch
Performance.idleStream = false
eq(IdleStream.run(timer, 0.012), 0, "idleStream=false offers nothing")
Performance.idleStream = true
-- 7. the chain runs the GC budget first
local order = {}
local chain = IdleStream.idle(function() order[#order + 1] = "gc" end)
package.loaded["src.core.game3.asset_stream"].update = function() order[#order + 1] = "stream" end
chain(timer, 0.012)
eq(table.concat(order, ","), "gc,stream", "GC budget runs before the stream")
-- 8. no stream module loaded at all: nothing happens, nothing is required
package.loaded["src.core.game3.asset_stream"] = nil
eq(IdleStream.run(timer, 0.012), 0, "no stream loaded, no slice")
eq(package.loaded["src.core.game3.asset_stream"], nil, "...and it was not loaded by the pump")

-- 9. the real stream: busy() and update(budget)
local S = require("src.core.game3.asset_stream")
local jobs, steps = {}, {}
S.register({ pending = function() return jobs end, step = function(_, budget) steps[#steps + 1] = budget end })
S.register({ poll = function() end })
eq(S.busy(), false, "no jobs: not busy")
jobs.a = { priority = 1 }
eq(S.busy(), true, "a queued job: busy")
S.update(0.005)
near(steps[1], 0.005, "update(budget) hands the caller's slice to the service")
S.update()
near(steps[2], S.BUDGET, "update() keeps the historical default")

print(("idle_stream_check: %d checks ok"):format(n))
