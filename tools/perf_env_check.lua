-- Check for Performance.applyEnvironment (POKEPORT_PERF).
--   luajit tools/perf_env_check.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
local P = require("src.core.Performance")
local n = 0
local function eq(a, b, what)
  n = n + 1
  if a ~= b then error(("%s: got %s, want %s"):format(what, tostring(a), tostring(b)), 2) end
end

local saved = {}
for k, v in pairs(P) do if type(v) == "boolean" then saved[k] = v end end

local applied = P.applyEnvironment("gen3PaletteIndex=0, bytecodeCache=false")
eq(P.gen3PaletteIndex, false, "name=0 turns a switch off")
eq(P.bytecodeCache, false, "name=false turns a switch off")
eq(applied.gen3PaletteIndex, false, "applied map reports it")
eq(P.gcBudget, saved.gcBudget, "an unnamed switch is untouched")

applied = P.applyEnvironment("all=0")
for k, v in pairs(saved) do
  if k ~= "saver" then eq(P[k], false, "all=0 turns off " .. k) end
end
applied = P.applyEnvironment("all=0,gcBudget=1")
eq(P.gcBudget, true, "a later item overrides all=")
eq(P.hotPathHoist, false, "...and only that one")

applied = P.applyEnvironment("tier=0,nonsense=1,GC_PAUSE=0,=1")
eq(P.tier, "high", "a non-boolean field is never written")
eq(P.GC_PAUSE, 120, "a number field is never written")
eq(next(applied), nil, "nothing applied for garbage")
eq(next(P.applyEnvironment("")), nil, "empty spec applies nothing")
eq(next(P.applyEnvironment(nil)), nil, "nil spec (no env) applies nothing")
P.gcBudget = true
eq(next(P.applyEnvironment("gcBudget=treu")), nil, "misspelled booleans are ignored")
eq(P.gcBudget, true, "invalid boolean cannot switch a feature off")
P.applyEnvironment("gcBudget=FALSE")
eq(P.gcBudget, false, "case-insensitive boolean")

for k, v in pairs(saved) do P[k] = v end
print(("perf_env_check: %d checks ok"):format(n))
