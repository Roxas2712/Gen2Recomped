package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local Version = require("src.core.GameVersion")
local Font = require("src.render.Font")
local Renderer = require("src.render.Renderer")
local SS = require("src.render.SuperSample")
local visibility = dofile("tests/screen_visibility/fixture.lua")
local oldFit, oldPixel, oldOverride = Renderer.fitScale, Renderer.pixelSize, Renderer.uiOverride
Renderer.fitScale = function()
  return 2
end
Renderer.pixelSize = function()
  return 512, 384
end
local g = love.graphics
local oldGet, oldIntersect = g.getScissor, g.intersectScissor
g.getScissor = g.getScissor or function()
  return nil
end
g.intersectScissor = g.intersectScissor or function() end
for _, version in ipairs({ "platinum", "heartgold", "black" }) do
  local f = visibility.new(".", "gen2", version, 3, "unified")
  f.game.renderer = Renderer
  f.game.save.options.secondScreenMode = "off"
  local panel = f.state("Panel", true)
  panel.uiSize = function()
    return 256, 192
  end
  -- Palette providers on a native sized surface return zone records, not
  -- the string sentinels the generic routing fixture uses without offsets.
  panel.sgbPalettes = function()
    return {}
  end
  f.menu.sgbPalettes = function()
    return {}
  end
  f.overlay.sgbPalettes = function()
    return {}
  end
  f.menu.isOpaque = false
  f.exports.hide("BagMenu", true)
  local drawnInside, beforeHd = 0, Font.hd
  local draw = panel.draw
  panel.draw = function(self)
    T.check(SS.active and Font.hd, "visible state runs in the native supersampling pass")
    T.eq(g.getCanvas(), SS.canvas, "native high-resolution canvas owns drawing")
    drawnInside = drawnInside + 1
    return draw(self)
  end
  T.same(
    f.frame({ panel, f.menu, f.overlay }),
    { "Panel", "TextBox" },
    "portable visibility still hides only the requested overlay inside the new pass"
  )
  T.eq(drawnInside, 1, "native supersampling invokes a visible state once")
  T.eq(SS.canvas:getWidth(), 512, "supersampled width follows display scale")
  T.eq(SS.canvas:getHeight(), 384, "supersampled height follows display scale")
  T.eq(Font.hd, beforeHd, "font mode is restored after composition")
  T.eq(SS.active, false, "native pass is retired after composition")
  T.eq(#f.stack.states, 3, "render filtering never changes the state stack")
  f.close()
end
Renderer.fitScale, Renderer.pixelSize, Renderer.uiOverride = oldFit, oldPixel, oldOverride
g.getScissor, g.intersectScissor = oldGet, oldIntersect

local trainers = dofile("tests/trainer_preparation/fixture.lua")
for _, version in ipairs({ "red", "heartgold" }) do
  for _, case in ipairs({ { false, "win", "lose" }, { true, "win", "win" }, { true, "run", "lose" } }) do
    local f = trainers.new(".", "gen2", version, 3, "unified")
    local party = f.game.save.party
    f.start()
    f.exports.continue({ playerPartyIndices = { 2 } })
    local battle = assert(f.battle())
    party[2].hp = 0
    T.check(party[1].hp > 0, "excluded party member stays healthy")
    battle.result = case[2]
    battle.ally = case[1] and { mon = { hp = 30 } } or nil
    local callback, ended, count = nil, nil, 0
    battle.onFinish = function(result)
      callback = result
      count = count + 1
    end
    local off = f.result.loader.events:on("battle.ended", function(event)
      ended = event.result
    end)
    local world = { name = "native-test-world" }
    f.game.stack.states = { world, battle }
    battle:finish()
    for _ = 1, 90 do
      local state = f.game.stack:top()
      if state == world then
        break
      end
      state:update(1 / 60)
    end
    T.eq(battle.result, case[3], "native finish preserves scoped exhaustion and partner-win policy")
    T.eq(ended, case[3], "native ended event observes the composed result")
    T.eq(callback, case[3], "native return transition delivers the composed result")
    T.eq(count, 1, "native completion callback runs exactly once")
    T.eq(f.game.stack:top(), world, "battle teardown returns to the original world state")
    T.eq(f.game.save.party, party, "native finish preserves the saved party table")
    T.eq(battle:playerPartyView()[1], party[2], "battle scope preserves the selected party reference")
    off()
    f.close()
  end
end
T.finish("October upstream visibility and party-scope composition")
