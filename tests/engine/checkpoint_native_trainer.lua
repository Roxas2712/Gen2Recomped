-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
local T = require("tests.harness")
love = require("tests.love_stub")
love.math.getRandomState = function()
  return "owned-native-trainer"
end
love.math.setRandomState = function() end
local F = require("tests.checkpoint_fixture")
local C = require("src.core.CheckpointCallbacks")
for _, edition in ipairs(require("src.core.GameVersion").ORDER) do
  local f = F.boot(edition)
  local game, world, stack = f.game, f.world, f.stack
  local npc = world.npcs[1]
  npc.def.trainerClass, npc.def.trainerParty = "OPP_FIX_YOUNGSTER", 1
  npc.frozen = true
  world.engaging = true
  local done = C.bind(function()
    npc.frozen = false
    world.engaging = false
  end, { npc = npc.id, clearEngaging = true })
  local push = world.pushBattle
  world.pushBattle = function(_, battle)
    stack.states[#stack.states + 1] = battle
  end
  world:engageTrainer(npc, done)
  local text = stack:top()
  stack.states = { world }
  text.onDone()
  world.pushBattle = push
  local battle = stack:top()
  battle.phase, battle.queue, battle.introSlide = "menu", {}, 0
  local cp, code, detail = f.checkpoints:capture(game)
  T.check(
    cp ~= nil,
    edition .. " detaches actual native trainer producer: " .. tostring(code) .. " " .. tostring(detail)
  )
  if cp then
    T.check(f.checkpoints:restore(game, cp), "native trainer controller reconstructs")
    local fresh = stack:top()
    stack.states = { world }
    fresh.onFinish("win")
    T.eq(game.save.defeatedTrainers[npc.id], true, "native trainer defeat flag continues")
    T.eq(world.npcs[1].frozen, false, "native trainer completion resolves reconstructed NPC")
    T.eq(world.engaging, false, "native trainer completion releases field input")
  end
  f.close()
end
T.finish("Native trainer checkpoint producer")
