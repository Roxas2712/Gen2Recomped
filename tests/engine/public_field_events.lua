package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local V = require("src.core.GameVersion")
V.set("red") -- ROM-free engine fixture, no external checkout or game process.
local run = T.sdk.loadMods({ "mods/field_probe" }, { fs = T.sdk.memfs({
  ["mods/field_probe/manifest.json"] = '{"id":"field_probe","name":"Field probe","version":"1.0.0","api":2,"entry":"main.lua"}',
  ["mods/field_probe/main.lua"] = [[
    local mod = ...
    mod.exports.ticks, mod.exports.blocks, mod.exports.eggs = {}, {}, {}
    mod.exports.stopTicks = mod.events:on("world.tick", function(ev) table.insert(mod.exports.ticks, ev) end)
    mod.events:on("world.blocks_replaced", function(ev) table.insert(mod.exports.blocks, ev) end)
    mod.events:on("pokemon.egg_hatched", function(ev) table.insert(mod.exports.eggs, ev) end)
  ]],
}) })
T.eq(#run.errors, 0, "field observer loads through public API")
local exports = run.loader.exports.field_probe
local Game = require("src.core.Game")
local World = require("src.world.OverworldController")
Game.data, Game.save = run.data, require("src.core.SaveData").newGame()
Game.stack = { states = {} }
function Game.stack:push(state) self.states[#self.states + 1] = state end
function Game.stack:pop() return table.remove(self.states) end
function Game.stack:top() return self.states[#self.states] end
-- Enter the real state without importing or loading a map. The event driver
-- supplies resident geometry and isolates unrelated timed field mechanics.
local world = setmetatable({ setMap = function() end, refreshStandingOnWarp = function() end }, { __index = World })
world:enter("FIX_TOWN", 0, 0, "down")
local rebuilds = 0
local map = require("src.world.Map").new({ id = "FIX_TOWN", width = 2, height = 2,
  blocks = { 1, 2, 3, 4 } }, { blockTiles = 2, blockCells = 1 })
map.renderer = { rebuild = function() rebuilds = rebuilds + 1 end }
world.map = map
T.eq(world:replaceBlocks({ 1, 5, 6, 4, 999 }), true, "native bulk change applies within map bounds")
T.eq(#exports.blocks, 1, "one bulk change emits one event")
T.eq(exports.blocks[1].mapId, "FIX_TOWN", "bulk event identifies map")
T.eq(exports.blocks[1].count, 2, "bulk event counts actual changed cells")
T.eq(map:blockAt(1, 0), 5, "bulk event follows committed geometry")
T.eq(rebuilds, 1, "geometry redraw still occurs")
T.eq(world:replaceBlocks({ 1, 5, 6, 4 }), false, "identical replacement is a no-op")
T.eq(#exports.blocks, 1, "no event for unchanged blocks")
local noop = function() end
for _, name in ipairs({ "tickCrackedFloor", "tickPacifidlogLogs", "tickPcScreen", "tickGymDoorSlide",
  "tickGen3GateSwing", "tickLavaridgeLaunch", "drainPendingScripts", "noteCellChange",
  "tickCyclingChallenge", "watchStuckScript", "applyForcedBike", "checkSpecialPhoneCall", "checkBugContestClock" }) do
  world[name] = noop
end
world.runner = { isRunning = function() return true end, update = noop }
local boundary = {}
world.updateParallel = function() error(boundary) end -- stop immediately after the tested event boundary
local ok, reason = pcall(world.update, world, 1/60)
T.eq(ok, false, "driver reaches the post-tick boundary")
T.eq(reason, boundary, "the native update reached the event without another failure")
T.eq(#exports.ticks, 1, "one native update emits one fixed tick")
T.eq(exports.ticks[1].dt, 1/60, "tick supplies the fixed dt")
T.eq(exports.ticks[1].mapId, "FIX_TOWN", "tick identifies the resident map")
T.eq(exports.ticks[1].overworld, world, "tick supplies the real world")
T.eq(exports.ticks[1].scripted, true, "tick reports the native runner state")
-- Hot-path parity: without listeners the actual update never calls emit.
exports.stopTicks()
local Runtime = require("src.mods.Runtime")
local originalEmit, tickEmits = Runtime.emit, 0
Runtime.emit = function(name, ...)
  if name == "world.tick" then tickEmits = tickEmits + 1 end
  return originalEmit(name, ...)
end
local _, noListenerBoundary = pcall(world.update, world, 1/60)
Runtime.emit = originalEmit
T.eq(noListenerBoundary, boundary, "unsubscribed tick reaches the same native boundary")
T.eq(tickEmits, 0, "unsubscribed hot tick does not emit or build its payload")
local mon = require("src.pokemon.Pokemon").new(run.data, "FIXMON_A", 5)
mon.isEgg, mon.eggSteps, mon.eggCycles, mon.nickname = true, 9, 2, "EGG"
T.eq(world:hatchEgg(mon), true, "native hatch accepts the egg")
T.eq(mon.isEgg, nil, "native hatch clears egg flag")
T.eq(mon.eggSteps, nil, "native hatch clears egg steps")
T.eq(mon.eggCycles, nil, "native hatch clears egg cycles")
T.eq(#exports.eggs, 0, "hatch event waits for the message completion")
local box = Game.stack:top()
assert(box.onDone, "real native hatch message has a completion callback")()
T.eq(#exports.eggs, 1, "message completion emits one hatch event")
T.eq(exports.eggs[1].mon, mon, "hatch observer receives the normalized Pokemon")
run.release()
T.finish("Public field and egg events")
