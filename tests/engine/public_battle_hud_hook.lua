package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local run = T.sdk.loadMods({ "mods/hud_probe" }, { fs = T.sdk.memfs({
  ["mods/hud_probe/manifest.json"] = '{"id":"hud_probe","name":"HUD probe","version":"1.0.0","api":2,"entry":"main.lua"}',
  ["mods/hud_probe/main.lua"] = [[
    local mod = ...
    mod.exports.calls = 0
    mod.hooks:wrap("battle.status_hud_visible", function(nextFn, battle)
      mod.exports.calls = mod.exports.calls + 1
      mod.exports.battle = battle
      mod.exports.native = nextFn(battle)
      return false
    end)
  ]],
}) })
T.eq(#run.errors, 0, "HUD owner loads through public API")
local battle = { data = {}, game = { data = {} } }
local Gen4 = require("src.battle.Gen4Battle")
local draws, draw = 0, love.graphics.draw
love.graphics.draw = function() draws = draws + 1 end
T.eq(Gen4.drawHealthboxes(battle), true, "owned HUD prevents fallback native panels")
T.eq(draws, 0, "hidden native HUD performs no draw")
local exports = run.loader.exports.hud_probe
T.eq(exports.calls, 1, "native Gen4 healthbox entry consults the public hook")
T.eq(exports.battle, battle, "hook receives the actual battle")
T.eq(exports.native, true, "unwrapped native visibility defaults to true")
run.loader.hooks:removeOwner("hud_probe")
T.eq(Gen4.drawHealthboxes(battle), false, "without owner, unavailable native art returns to ordinary fallback")
love.graphics.draw = draw
run.release()
T.finish("Public battle HUD ownership hook")
