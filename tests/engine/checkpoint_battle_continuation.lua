-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
local T = require("tests.harness")
love = require("tests.love_stub")
local rng = 714821
love.math.random = function(a, b)
  rng = (rng * 48271) % 2147483647
  if not a then
    return rng / 2147483647
  end
  if not b then
    a, b = 1, a
  end
  return a + (rng % (b - a + 1))
end
love.math.getRandomState = function()
  return tostring(rng)
end
love.math.setRandomState = function(v)
  rng = assert(tonumber(v))
end
love.math.newRandomGenerator = function()
  return {
    setState = function(_, v)
      assert(tonumber(v))
    end,
  }
end
local Fixture = require("tests.checkpoint_fixture")
local Native = require("src.battle.BattleState")
local B = require("src.core.CheckpointBattle")
local Serializer = require("src.core.SaveSerializer")
local function copy(v)
  return assert(Serializer.decode(Serializer.encode(v)))
end
for _, edition in ipairs({ "red", "gold", "firered", "emerald", "platinum", "heartgold", "black" }) do
  for _, kind in ipairs({ "wild", "trainer" }) do
    local f = Fixture.boot(edition)
    local game, world, stack = f.game, f.world, f.stack
    game.save.options.battleAnimations = false
    local battle = kind == "wild" and Native.newWild(game, "FIXMON_B", 15)
      or Native.newTrainer(game, "OPP_FIX_YOUNGSTER", 1)
    battle.phase, battle.queue, battle.introSlide = "menu", {}, 0
    battle.player.mon.hp, battle.player.mon.stats.hp, battle.player.shownHP = 400, 400, 400
    battle.enemy.mon.hp, battle.enemy.mon.stats.hp, battle.enemy.shownHP = 400, 400, 400
    battle.player.stages.attack = 2
    battle.field.tokens.owned = { turns = 3 }
    battle.sides[1].tokens.owned = { turns = 2 }
    stack.states = { world, battle }
    local cp, code, detail = f.checkpoints:capture(game)
    T.check(
      cp ~= nil,
      edition .. "/" .. kind .. " captures native decision: " .. tostring(code) .. " " .. tostring(detail)
    )
    if not cp then
      local ok, why = pcall(B.capture, game, battle, copy)
      print("BATTLE_DIAG", ok, why)
    else
      local bytes = Serializer.encode(cp)
      T.eq(cp.kind, "battle", "semantic checkpoint kind")
      battle.player.stages.attack = -2
      local ok, why, detail = f.checkpoints:restore(game, cp)
      T.check(ok, "restores native decision: " .. tostring(why) .. " " .. tostring(detail))
      if ok then
        local fresh = stack:top()
        T.check(fresh ~= battle, "fresh native battle controller")
        T.eq(fresh.player.mon, game.save.party[1], "party Pokemon identity rebound")
        T.eq(fresh.player.curStats, game.save.party[1].stats, "native stat alias rebound")
        T.eq(fresh.player.stages.attack, 2, "volatile stages restored")
        T.eq(fresh.field.sides, fresh.sides, "native field side alias preserved")
        T.eq(fresh.field.tokens.owned.turns, 3, "field tokens restored")
        T.eq(Serializer.encode(assert(f.checkpoints:capture(game))), bytes, "full battle recapture matches")
        T.eq(Serializer.encode(cp), bytes, "caller battle payload detached")
        local function turn()
        local b=stack:top()
        game.input.wasPressed=function(_,key)return key=='a'end
        game.input.pressed=game.input.wasPressed
        b:chooseMenu('fight');b:chooseMove(1)
        local ticks=0
        repeat
          b:update(1/60);ticks=ticks+1
        until (b.phase=='menu' and not b.current and #b.queue==0) or ticks>=4000
        T.check(ticks<4000 and b.phase=='menu', 'actual native turn reaches its next decision')
        return Serializer.encode(assert(f.checkpoints:capture(game)))
      end
      local expected=turn()
      T.check(f.checkpoints:restore(game,cp),'rewind before comparing native turn continuation')
      T.check(turn()==expected,'same player intent reproduces the complete next native decision')
      T.check(f.checkpoints:restore(game,cp),'restore original decision after the continuation proof')
      fresh=stack:top()
      local originalRng = fresh.rng
        fresh.rng = function()
          return 1
        end
        T.eq(f.checkpoints:inspect(game).reason, "unsupported_battle", "opaque RNG refused")
        fresh.rng = originalRng
        fresh.onFinish = function() end
        T.eq(f.checkpoints:inspect(game).reason, "unsupported_battle", "opaque completion refused")
        fresh.onFinish = nil
        fresh.phase = "messages"
        T.eq(f.checkpoints:inspect(game).reason, "unsupported_battle", "active message phase refused")
        fresh.phase = "menu"
        local before, oldWorld, oldBattle = game.save, world.player, fresh
        local apply = B.apply
        B.apply = function(...)
          apply(...)
          error("intentional battle rebuild failure")
        end
        ok, why = f.checkpoints:restore(game, cp)
        B.apply = apply
        T.eq(ok, false, "failed battle apply refused")
        T.eq(why, "restore_failed", "failed battle apply rolls back")
        T.eq(game.save, before, "battle rollback retains original save")
        T.eq(world.player, oldWorld, "battle rollback retains original field")
        T.eq(stack:top(), oldBattle, "battle rollback retains original controller")
        stack.states = { { screenId = "TitleState" } }
        T.check(f.checkpoints:resume(game, cp), "title reconstructs native battle decision")
        T.eq(Serializer.encode(assert(f.checkpoints:capture(game))), bytes, "title battle continuation recaptures")
      end
    end
    f.close()
  end
end
T.finish("Native checkpoint battle continuation")
