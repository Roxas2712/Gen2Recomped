-- Headless check for the frame pacer's spin window and background trickle.
--   luajit tools/frame_pacing_check.lua
-- Drives FrameCap.pace with a fake clock whose sleep() overshoots by a
-- scheduler-like 0.6 ms, the way a real 1 ms sleep does, and asserts that
-- the spin lands the frame on the deadline where the pure sleep misses it,
-- that the HIGH tier spins and LOW does not, and that an unfocused window
-- is paced to FrameCap.BACKGROUND regardless of vsync.

package.path = "./?.lua;./?/init.lua;" .. package.path
love = nil

local FrameCap = require("src.core.FrameCap")
local Performance = require("src.core.Performance")

-- Exercise each rollback explicitly below, independent of the caller's env.
Performance.framePacingSpin=true;Performance.backgroundPacing=true
local n = 0
local function eq(a, b, what)
  n = n + 1
  if a ~= b then error(("%s: got %s, want %s"):format(what, tostring(a), tostring(b)), 2) end
end
local function near(a, b, tol, what)
  n = n + 1
  if math.abs(a - b) > tol then
    error(("%s: got %.6f, want %.6f ±%.6f"):format(what, a, b, tol), 2)
  end
end

local OVERSHOOT = 0.0006
local POLL = 0.000001 -- a clock read costs a microsecond, so a spin advances
local function clock()
  local t = { now = 0, sleeps = 0 }
  t.getTime = function() t.now = t.now + POLL; return t.now end
  t.sleep = function(s) t.sleeps = t.sleeps + 1; t.now = t.now + s + OVERSHOOT end
  return t
end

local function runFrame(timer, window, presented)
  -- the "work" of the frame took 2 ms; the pacer owns the rest
  local start = timer.now
  timer.now = timer.now + 0.002
  local deadline = FrameCap.pace(timer, window, presented, start, nil)
  return timer.now - start, deadline
end

-- 1. spin on: the frame lands on the 60 fps deadline exactly
Performance.tier = "high"
FrameCap.apply(60)
FrameCap.focused = true
local t = clock()
local took = runFrame(t, nil, true)
near(took, 1 / 60, 3 * POLL, "HIGH: spin lands the frame on the deadline")
eq(FrameCap.spinSeconds(), FrameCap.SPIN_SECONDS, "HIGH spends the spin")

-- 2. spin off (LOW): the last sleep overshoots the deadline
Performance.tier = "low"
eq(FrameCap.spinSeconds(), 0, "LOW keeps the sleep")
t = clock()
took = runFrame(t, nil, true)
n = n + 1
if took <= 1 / 60 then error("LOW: a pure sleep should overshoot the deadline on this clock") end
near(took, 1 / 60, OVERSHOOT + 3 * POLL, "LOW: overshoot is one scheduler tick at most")

-- 3. the switch itself
Performance.tier = "high"
FrameCap.spinPacing = false
eq(FrameCap.spinSeconds(), 0, "spinPacing=false turns the spin off on HIGH")
FrameCap.spinPacing = true

-- 4. background: an unfocused window gets BACKGROUND fps, even with vsync
local window = {
  getVSync = function() return 1 end,
  getMode = function() return 1920, 1080, { refreshrate = 60 } end,
}
FrameCap.apply(144)
t = clock()
took = runFrame(t, window, true)
near(took, 0.002, 3 * POLL, "focused + vsync at 144 cap: the present paces, no sleep")
FrameCap.setFocus(false)
t = clock()
took = runFrame(t, window, true)
near(took, 1 / FrameCap.BACKGROUND, OVERSHOOT + 3 * POLL, "unfocused: paced to BACKGROUND even under vsync")
FrameCap.backgroundPacing = false
t = clock()
took = runFrame(t, window, true)
near(took, 0.002, 3 * POLL, "backgroundPacing=false: vsync paces again")
FrameCap.backgroundPacing = true
Performance.backgroundPacing=false
t=clock();took=runFrame(t,window,true)
near(took,.002,3*POLL,"performance background rollback restores vsync pacing")
Performance.backgroundPacing=true
FrameCap.setFocus(true)
eq(FrameCap.focused, true, "focus restored")

-- 5. a cap below BACKGROUND is never raised by the trickle
FrameCap.setFocus(false)
FrameCap.BACKGROUND = 1000
FrameCap.apply(30)
t = clock()
took = runFrame(t, nil, true)
near(took, 1 / 30, OVERSHOOT + 3 * POLL, "a 30 cap stays 30 in the background")
FrameCap.BACKGROUND = 20
FrameCap.setFocus(true)

Performance.framePacingSpin=false
eq(FrameCap.spinSeconds(),0,"performance spin rollback disables polling")
Performance.framePacingSpin=true
local budgetFlag=Performance.lowTierBudget
Performance.lowTierBudget=false;Performance.tier="low"
eq(FrameCap.spinSeconds(),0,"LOW does not start spinning when unrelated extra caps are disabled")
Performance.tier="high";Performance.saver=true
eq(FrameCap.spinSeconds(),0,"battery never spins, independently of extra-cap rollback")
Performance.saver=false;Performance.lowTierBudget=budgetFlag
local f=assert(io.open("main.lua"));local main=f:read("*a");f:close()
eq(main:find("if presented and FrameCap.focused ~= false",1,true)~=nil,true,"adaptive tier ignores intentional background pacing")
print(("frame_pacing_check: %d checks ok"):format(n))
