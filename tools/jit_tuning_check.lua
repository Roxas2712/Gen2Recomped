-- Run:  luajit tools/jit_tuning_check.lua
--
-- J1 -- THE JIT'S TRACE LIMITS, RAISED ONCE.
package.path = './?.lua;./?/init.lua;' .. package.path
local PASS, FAIL = 0, 0
local function check(cond, label)
  if cond then PASS = PASS + 1 else FAIL = FAIL + 1; print('FAIL: ' .. label) end
end
local J = require('src.core.JitTuning')
local applied = J.apply()
check(type(applied) == 'table', 'under LuaJIT the limits are applied (' .. tostring(applied) .. ')')
check(J.apply() == applied, 'a second apply is a no-op')
local names = {}
for _, item in ipairs(J.DEFAULT) do names[item:match('^(%w+)=')] = tonumber(item:match('=(%d+)$')) end
check(names.maxtrace and names.maxtrace > 1000, 'maxtrace above the default 1000')
check(names.maxmcode and names.maxmcode > 512, 'maxmcode above the default 512 KB')
check(names.maxrecord and names.maxrecord > 4000, 'maxrecord above the default 4000')
check(names.maxside and names.maxside > 100, 'maxside above the default 100')
check(names.maxsnap and names.maxsnap > 500, 'maxsnap above the default 500')
-- Verify actual trace generation, not merely the enabled status flag.
local traceutil=require('jit.util')
jit.flush()
local acc = 0
for i = 1, 200000 do acc = acc + (i % 7) end
check(acc > 0 and jit.status(), 'the JIT is on after tuning')
check(traceutil.traceinfo(1)~=nil,'the numeric loop produces a compiled trace')
-- wiring
local main = assert(io.open('main.lua')):read('*a')
check(main:find('pcall(function() require("src.core.JitTuning").apply() end)', 1, true) ~= nil, 'main.lua applies it before any module')
local pos = main:find('require("src.core.JitTuning")', 1, true)
local firstOther = main:find('require("src%.render') or #main
check(pos < firstOther, 'and before the first engine module is required')
local worker = assert(io.open('src/core/chip_worker.lua')):read('*a')
check(worker:find('require("src.core.JitTuning").apply()', 1, true) ~= nil, 'the audio worker applies it too')
local builds=assert(io.open('src/core/build_worker.lua')):read('*a')
check(builds:find('require("src.core.JitTuning").apply()',1,true)~=nil,'pure build workers apply the same optional tuning')
-- the env switch
local J2 = dofile('src/core/JitTuning.lua')
local realGetenv = os.getenv
os.getenv = function(k) if k == 'POKEPORT_JIT_OPT' then return '0' end return realGetenv(k) end
check(J2.apply() == false, 'POKEPORT_JIT_OPT=0 leaves the defaults')
os.getenv = realGetenv
local J3 = dofile('src/core/JitTuning.lua')
os.getenv = function(k) if k == 'POKEPORT_JIT_OPT' then return 'maxtrace=2000,hotloop=100' end return realGetenv(k) end
local custom = J3.apply()
check(type(custom) == 'table' and custom[1] == 'maxtrace=2000' and custom[2] == 'hotloop=100', 'POKEPORT_JIT_OPT=k=v,k=v replaces the set')
os.getenv = realGetenv
print(('%d checks, %d failed'):format(PASS + FAIL, FAIL))
if FAIL > 0 then os.exit(1) end
