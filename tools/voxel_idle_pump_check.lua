-- Run:  luajit tools/voxel_idle_pump_check.lua
--
-- V9 -- THE VOXEL MESHER TAKES THE ENGINE'S MEASURED IDLE SLICE.
--
-- Source-level: the in-frame pump and the idle pump share one job loop
-- (runSlice), the idle pump adds what it spent to lastSpend so the
-- in-frame headroom estimate stays honest, the service has the shape
-- IdleStream expects, and main.lua registers it behind a pcall so a host
-- without the hook is unaffected.  Behavioural: a stand-in service with
-- the same shape goes through IdleStream and is offered the slice only
-- while it reports work.
package.path = './?.lua;./?/init.lua;' .. package.path
local PASS, FAIL = 0, 0
local function check(cond, label)
  if cond then PASS = PASS + 1 else FAIL = FAIL + 1; print('FAIL: ' .. label) end
end

local src = assert(io.open('mods/DRAMATIC_SHAPE/lib/ChunkMesher.lua')):read('*a')
check(src:find('local runSlice\nfunction ChunkMesher.pump(', 1, true) ~= nil, 'the job loop is declared ahead of pump')
check(src:find('lastSpend = runSlice(pick, started + slice, foregroundOnly, started)', 1, true) ~= nil,
      'the in-frame pump runs the shared loop with its estimated slice')
check(src:find('function ChunkMesher.pumpIdle(seconds)', 1, true) ~= nil, 'pumpIdle exists')
check(src:find('local spent = runSlice(pick, started + seconds, ChunkMesher.foregroundOnly, started)\n  lastSpend = lastSpend + spent', 1, true) ~= nil,
      'the idle pump runs the shared loop with the measured slice and adds it to lastSpend')
check(src:find('busy = function() return ChunkMesher.idlePump and #jobs > 0 end', 1, true) ~= nil, 'busy = a job is queued and the switch is on')
check(src:find('step = function(seconds) return ChunkMesher.pumpIdle(seconds) end', 1, true) ~= nil, 'step = pumpIdle')
check(src:find('ChunkMesher.idlePump = true', 1, true) ~= nil, 'the switch defaults on')
check(src:find('return clock() - started   -- slice spent mid-build', 1, true) ~= nil, 'a suspended build returns the spend')
-- the loop body is the historical one: resume, finish, deadline check
check(src:find('Budget.begin(pick.co, deadline - clock(), pick.resources)', 1, true) ~= nil, 'the slice budget is still handed to the build coroutine')
check(src:find('if clock() >= deadline or #jobs == 0 then\n      return clock() - started', 1, true) ~= nil, 'the deadline ends the loop as before')

local main = assert(io.open('mods/DRAMATIC_SHAPE/main.lua')):read('*a')
check(main:find('IdleStream.register(ChunkMesher.idleService())', 1, true) ~= nil, 'main.lua registers the service')
check(main:find('pcall(function()\n  local IdleStream = package.loaded["src.core.IdleStream"]', 1, true) ~= nil,
      'registration is behind a pcall and looks the hook up first')

check(main:find('V.idleServices.sheets = IdleStream.register({', 1, true) ~= nil, 'the engine-sheet prewarm is registered and held')
check(main:find('V.idleServices.prebake = IdleStream.register({', 1, true) ~= nil, 'the region prebake is registered and held')
check(main:find('V.idleSheets.state, V.idleSheets.data = ow, Game.data', 1, true) ~= nil, 'the update hook remembers what the sheet pump may resume')
check(main:find('V.idleSheets.state, V.idleSheets.data = nil, nil', 1, true) ~= nil, '...and forgets it off the overworld')
check(main:find("and not (type(ChunkMesher.pending) == \"function\" and ChunkMesher.pending() > 0)", 1, true) ~= nil, 'prebake yields to queued meshes')

-- behavioural: the same shape through IdleStream
package.loaded['src.core.game3.asset_stream'] = nil
local IdleStream = require('src.core.IdleStream')
local Performance = require('src.core.Performance')
Performance.tier = 'high'
local jobs, offered = 0, {}
local service = {
  busy = function() return jobs > 0 end,
  step = function(seconds) offered[#offered + 1] = seconds; jobs = jobs - 1; return seconds end,
}
IdleStream.register(service)
local timer = { now = 0 }
function timer.getTime() return timer.now end
check(not IdleStream.busy(), 'no jobs: the pump is quiet')
jobs = 2
check(IdleStream.busy(), 'a queued job makes the pump busy')
IdleStream.run(timer, 0.010)
check(#offered == 1 and math.abs(offered[1] - 0.006) < 1e-9, 'the service got the HIGH cap (6 ms) once per run')
Performance.tier = 'low'
IdleStream.run(timer, 0.010)
check(#offered == 2 and math.abs(offered[2] - 0.002) < 1e-9, 'LOW offers 2 ms')
check(not IdleStream.busy(), 'jobs drained: quiet again')
IdleStream.unregister(service)
Performance.tier = 'high'

-- Execute the actual mesher pump with no queued geometry. Its early return
-- must still publish the current foreground policy to the idle pump.
do
  local mesher = assert(loadfile('mods/DRAMATIC_SHAPE/lib/ChunkMesher.lua'))({
    require=function(name)
      if name=='RetireQueue' then return {new=function()return {pump=function()end}end} end
      return {}
    end,
  })
  mesher.pump(false,true)
  check(mesher.foregroundOnly==true,'empty regular pump publishes foreground-only policy')
  mesher.pump(false,false)
  check(mesher.foregroundOnly==false,'empty regular pump clears foreground-only policy')
end

print(('voxel_idle_pump_check: %d passed, %d failed'):format(PASS, FAIL))
if FAIL > 0 then os.exit(1) end
