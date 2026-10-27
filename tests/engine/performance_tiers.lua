-- Graphics performance tier (src/core/Performance.lua): the AUTO device
-- heuristic, tier normalization/labels, per-tier caps, the option-row
-- cycle, and applyOptions recording the live tier.  Pure logic over
-- stubbed love/jit globals, so it needs no ROM and runs in the T2 tier.

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local Performance = require("src.core.Performance")

-- detect() reads the live `love` and `jit` globals; swap them per scenario
-- and restore afterward so nothing leaks between checks (or into luajit).
local realLove, realJit = love, jit

local function device(os, arch, cores)
  love = {
    system = {
      getOS = function() return os end,
      getProcessorCount = function() return cores end,
    },
  }
  jit = arch and { arch = arch } or nil
end

local function restore()
  love, jit = realLove, realJit
end

-- ---------------------------------------------------------------- detect
device("Linux", "arm64", 4)
T.eq(Performance.detect(), "low", "ARM64 Linux handheld -> low")

device("Linux", "arm", 2)
T.eq(Performance.detect(), "low", "32-bit ARM Linux handheld -> low")

device("Android", "arm64", 8)
T.eq(Performance.detect(), "balanced", "Android phone -> balanced (not low)")

device("iOS", "arm64", 6)
T.eq(Performance.detect(), "balanced", "iOS -> balanced")

device("OS X", "x64", 8)
T.eq(Performance.detect(), "high", "8-core desktop -> high")

device("OS X", "arm64", 8)
T.eq(Performance.detect(), "high", "Apple Silicon is a desktop, not an ARM handheld")
T.eq(Performance.resolve("auto"), "high", "Apple Silicon AUTO avoids the handheld cap")
Performance.applyOptions({ performance = "auto" })
T.eq(Performance.tier, "high", "Apple Silicon publishes the resolved desktop tier")
T.eq(Performance.resolve("low"), "low", "explicit low remains selectable on Apple Silicon")
T.eq(Performance.resolve("balanced"), "balanced", "explicit balanced remains selectable on Apple Silicon")

device("OS X", "arm64", 2)
T.eq(Performance.detect(), "balanced", "Apple Silicon retains the desktop core-count floor")

device("Windows", "x64", 2)
T.eq(Performance.detect(), "balanced", "dual-core desktop -> balanced")

device("Windows", "x86", 1)
T.eq(Performance.detect(), "balanced", "single-core desktop -> balanced")

-- No love, no jit (a plain-Lua tool/test): nothing looks weak -> high, so
-- tooling that runs applyOptions is never surprised by a clamp.
love, jit = nil, nil
T.eq(Performance.detect(), "high", "no love/jit -> high (no clamping)")
restore()

-- ---------------------------------------------------------------- resolve
T.eq(Performance.resolve("high"), "high", "resolve passes concrete high")
T.eq(Performance.resolve("balanced"), "balanced", "resolve passes balanced")
T.eq(Performance.resolve("low"), "low", "resolve passes low")

device("Linux", "arm64", 4)
T.eq(Performance.resolve("auto"), "low", "resolve auto -> detect (handheld)")
T.eq(Performance.resolve(nil), "low", "resolve nil -> detect")
T.eq(Performance.resolve("bogus"), "low", "resolve garbage -> detect")
restore()

-- --------------------------------------------------------------- normalize
T.eq(Performance.normalize("auto"), "auto", "normalize keeps auto")
T.eq(Performance.normalize("low"), "low", "normalize keeps low")
T.eq(Performance.normalize("xyz"), "auto", "normalize garbage -> auto")
T.eq(Performance.normalize(nil), "auto", "normalize nil -> auto")

-- ------------------------------------------------------------------- label
T.eq(Performance.label("low"), "LOW", "label low")
T.eq(Performance.label("balanced"), "BALANCED", "label balanced")
T.eq(Performance.label(nil), "AUTO", "label nil -> AUTO")

-- -------------------------------------------------------------------- caps
local hi, lo = Performance.CAPS.high, Performance.CAPS.low
T.check(hi.tilt and hi.gbcfx and hi.survey and not hi.fpsMax, "high caps: all on, no fps ceiling")
T.check((not lo.tilt) and (not lo.gbcfx) and (not lo.survey), "low caps: heavy extras off")
T.eq(lo.fpsMax, 60, "low caps: FPS ceiling of 60")
local bal = Performance.CAPS.balanced
T.check((not bal.tilt) and (not bal.gbcfx) and bal.survey and not bal.fpsMax,
  "balanced caps: no tilt/gbcfx, survey kept, no fps ceiling")

device("Linux", "arm64", 4)
T.eq(Performance.caps("auto"), Performance.CAPS.low, "caps(auto) resolves through detect")
restore()

-- ------------------------------------------------------------- applyOptions
local caps = Performance.applyOptions({ performance = "low" })
T.eq(caps, Performance.CAPS.low, "applyOptions returns the resolved caps")
T.eq(Performance.tier, "low", "applyOptions records the live tier")

Performance.applyOptions({ performance = "high" })
T.eq(Performance.tier, "high", "applyOptions high tier")

device("Linux", "arm64", 4)
Performance.applyOptions(nil)
T.eq(Performance.tier, "low", "applyOptions(nil) resolves auto to the device tier")
restore()

-- ------------------------------------------------------------------- cycle
T.eq(Performance.cycle("auto", 1), "high", "cycle auto -> high")
T.eq(Performance.cycle("high", 1), "balanced", "cycle high -> balanced")
T.eq(Performance.cycle("balanced", 1), "low", "cycle balanced -> low")
T.eq(Performance.cycle("low", 1), "adaptive", "cycle low -> adaptive (PREFER FPS)")
T.eq(Performance.cycle("adaptive", 1), "battery", "cycle adaptive -> battery (PREFER BATTERY)")
T.eq(Performance.cycle("battery", 1), "auto", "cycle battery wraps to auto")
T.eq(Performance.cycle("auto", -1), "battery", "cycle back auto -> battery")
T.eq(Performance.cycle("high", -1), "auto", "cycle back high -> auto")

-- ------------------------------------------------------ A2: PREFER BATTERY
do
  T.eq(Performance.resolve("battery"), "low", "PREFER BATTERY resolves to LOW for every tier reader")
  T.eq(Performance.label("battery"), "PREFER BATTERY", "label battery")
  T.eq(Performance.normalize("battery"), "battery", "normalize keeps battery")
  local caps = Performance.applyOptions({ performance = "battery" })
  T.eq(Performance.tier, "low", "applyOptions(battery) records LOW live")
  T.eq(Performance.saver, true, "applyOptions(battery) raises Performance.saver")
  T.eq(caps.fpsMax, 30, "battery caps: 30 fps ceiling")
  T.eq(caps.tilt, false, "battery caps inherit LOW: no tilt")
  T.eq(caps.survey, false, "battery caps inherit LOW: no survey zoom")
  T.eq(caps.pacingSpin, false, "battery caps: no pacer spin")
  T.eq(Performance.caps("battery").fpsMax,30,"caps(battery) agrees with applyOptions")
  Performance.CAPS.low._qualificationValue=17
  T.eq(Performance.caps("battery")._qualificationValue,17,"warm overlay sees live LOW cap changes")
  Performance.CAPS.low._qualificationValue=nil
  T.eq(Performance.caps("battery")._qualificationValue,nil,"warm overlay forgets removed LOW caps")
  local fps=Performance.BATTERY.fpsMax
  Performance.BATTERY.fpsMax=25
  T.eq(Performance.caps("battery").fpsMax,25,"warm overlay sees battery cap changes")
  Performance.BATTERY.fpsMax=fps
  T.eq(Performance.extraCap("fpsMax"), Performance.lowTierBudget and 30 or nil, "extraCap reads the battery overlay")
  T.eq(Performance.extraCap("gen3PaletteCycle"), Performance.lowTierBudget and "quarter" or nil, "extraCap: quarter palette tick")
  T.eq(Performance.CAPS.low.fpsMax, 60, "the LOW table itself is untouched by the overlay")
  Performance.applyOptions({ performance = "low" })
  T.eq(Performance.saver, false, "leaving battery clears Performance.saver")
  T.eq(Performance.extraCap("fpsMax"), Performance.lowTierBudget and 60 or nil, "extraCap is LOW's own again")
end

-- ---------------------------------------------------------- A1: PREFER FPS
do
  Performance.resetAdaptive()
  device("Windows", "x64", 8)
  T.eq(Performance.resolve("adaptive"), "high", "PREFER FPS starts where AUTO would")
  T.eq(Performance.label("adaptive"), "PREFER FPS", "label adaptive")
  local A = Performance.ADAPTIVE
  local budget, now = 1 / 60, 100
  local function run(seconds, missEvery)
    local stepped
    local frames = math.floor(seconds / budget)
    for i = 1, frames do
      local dt = (missEvery and i % missEvery == 0) and budget * 2 or budget
      now = now + dt
      stepped = Performance.observeFrame(dt, budget, now, "adaptive") or stepped
    end
    return stepped
  end
  T.eq(run(A.window * 2.2, 100), nil, "one miss in a hundred changes nothing")
  T.eq(run(A.window * 1.1, 5), nil, "one bad window does not step down yet")
  T.eq(run(A.window * 1.1, 5), "balanced", "a second bad window steps HIGH down to BALANCED")
  T.eq(Performance.tier, "balanced", "the live tier follows")
  T.eq(run(A.cooldown, 5), nil, "misses during the cooldown are not judged")
  run(A.window * 2.2, 5)
  T.eq(Performance.adaptiveTier(), "low", "sustained misses step on down to LOW")
  run(A.cooldown + 1, nil)
  T.eq(run(A.upAfter, nil), "balanced", "thirty quiet seconds step back up one tier")
  run(A.cooldown + 1, nil)
  T.eq(run(A.upAfter, nil), "high", "...and again, up to AUTO's own answer")
  T.eq(run(A.upAfter * 2, nil), nil, "never above the ceiling AUTO chose")
  T.eq(Performance.observeFrame(budget * 3, budget, now + 1, "high"), nil, "a fixed tier is never judged")
  -- Leaving PREFER FPS discards partial decision windows. Returning later
  -- starts at AUTO, rather than counting old misses towards a new step.
  Performance.applyOptions({performance="adaptive"})
  run(A.window * 2.2,5)
  T.eq(Performance.adaptiveTier(),"balanced","adaptive session has stepped down")
  Performance.applyOptions({performance="high"})
  Performance.applyOptions({performance="adaptive"})
  T.eq(Performance.adaptiveTier(),"high","re-entering adaptive starts from AUTO")
  T.eq(Performance.adaptiveState().frames,0,"old frame samples are discarded")
  local f=assert(io.open("main.lua"));local main=f:read("*a");f:close()
  T.check(main:find("if presented and Game and Game.save and Game.save.options and love.timer then",1,true),"only presented frames reach the adaptive observer")
  Performance.resetAdaptive()
  restore()
end

T.finish("performance_tiers")
