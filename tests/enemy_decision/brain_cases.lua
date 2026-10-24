-- Unchanged public brain function, native opponent producer and callback data.
return function(f, backend)
  local T, rows, native = f.T, {}, backend == "gen1"
  local registry
  if native then
    registry = require("src.core.game3.battle.mod_registries")
    registry.bind(f.data)
  else
    f.game.mods = f.result.loader
  end
  local brain = f.e.brain
  if native then
    require("src.core.game3.items_data")._byId[540] =
      { name = "CHOICE BAND", holdEffect = 29, holdEffectParam = 0 }
  else
    f.data.items.ITEM_540 = { id = "ITEM_540", index = 540, name = "CHOICE BAND", holdEffect = "CHOICE_BAND" }
  end
  for _, spec in ipairs({
    { name = "numeric", pick = 2, expected = 2 },
    { name = "table", pick = { slot = 2 }, expected = 2 },
    { name = "string", pick = "2", expected = 2 },
    { name = "false", pick = false, expected = 1 },
    { name = "nil", expected = 1 },
    { name = "fraction", pick = 1.5, expected = 1 },
    { name = "out-of-range", pick = 5, expected = 1 },
    { name = "empty-table", pick = {}, expected = 1 },
    { name = "error", mode = "error", expected = 1 },
    { name = "zero-pp", mode = "first-usable", zeroPP = true, expected = 1 },
    { name = "disabled", mode = "first-usable", disabled = true, expected = 1 },
    { name = "disabled-selected", pick = 2, disabled = true, expected = 1 },
    { name = "disabled-first", pick = 1, disabledFirst = true, expected = 2 },
    { name = "taunted", mode = "first-usable", taunt = true, expected = 1 },
    { name = "tormented", mode = "first-usable", torment = true, expected = 1 },
    { name = "encored", mode = "first-usable", encore = true, expected = 2 },
    { name = "encore-item", encore = true, stock = true, noBrain = true, expectedItem = true },
    { name = "imprisoned", mode = "first-usable", imprison = true, expected = 2 },
    { name = "choice-locked", mode = "first-usable", choice = true, expected = 2 },
    { name = "all-zero-pp", allZero = true, noBrain = true, struggle = true },
    { name = "right-opponent", pick = 2, double = true, id = 3, expected = 2 },
    { name = "layer-is-not-brain", layer = true, noBrain = true, expected = 1 },
    { name = "native-item-precedes-brain", stock = true, noBrain = true, expectedItem = true },
    { name = "native-switch-precedes-brain", switch = true, noBrain = true, expectedSwitch = true },
    { name = "locked-move-skips-brain", locked = true, noBrain = true, expected = 1 },
  }) do
    local b = f.freshDecision(spec.stock and { f.item("POTION") } or {}, spec.double)
    local id = spec.id or 1
    local who = native and require("src.core.game3.battle.state").battler(b, id) or b:battlerAt(id)
    local statusMove = native and require("src.core.game3.battle.moves")._rom[76]
      or f.data.moves[f.ids.SOLARBEAM]
    local oldPower = statusMove.power
    if spec.taunt then
      statusMove.power = 0
    end
    if native then
      b.aiClass = spec.layer and "PORTABLE_LAYER_WITH_BRAIN" or "PORTABLE_NATIVE_BRAIN"
      who.mon.moves, who.mon.pp = { 33, 76 }, { 10, 10 }
      if spec.zeroPP then
        who.mon.pp[2] = 0
      end
      if spec.allZero then
        who.mon.pp = { 0, 0 }
      end
      if spec.disabled then
        who.expDisabledMove = 76
      end
      if spec.disabledFirst then
        who.expDisabledMove = 33
      end
      if spec.taunt then
        who.expTauntedTurns = 2
      end
      if spec.torment then
        who.expTormented, who.lastMoveId = true, 76
      end
      if spec.encore then
        who.expEncoreTurns, who.expEncoreMove = 2, 76
      end
      if spec.imprison then
        b.player.expImprison = true
      end
      if spec.choice then
        who.item, who.choicedMove = 540, 76
      end
      if spec.switch then
        who.perishSong, who.expPerishTurns = true, 0
      end
      if spec.locked then
        who.expLockedMove, who.expLockedSlot = 33, 1
      end
      if spec.recharge then
        who.expMustRecharge = true
      end
    else
      b.trainer.aiClass = spec.layer and "PORTABLE_LAYER_WITH_BRAIN" or "PORTABLE_NATIVE_BRAIN"
      who.mon.moves = { { id = f.ids.TACKLE, pp = 10 }, { id = f.ids.SOLARBEAM, pp = 10 } }
      who.curMoves = who.mon.moves
      if spec.zeroPP then
        who.curMoves[2].pp = 0
      end
      if spec.allZero then
        who.curMoves[1].pp, who.curMoves[2].pp = 0, 0
      end
      if spec.disabled then
        who.disabledSlot = 2
      end
      if spec.disabledFirst then
        who.disabledSlot = 1
      end
      if spec.taunt then
        who.tauntTurns = 2
      end
      if spec.torment then
        who.tormented, who.lastMove = true, f.ids.SOLARBEAM
      end
      if spec.encore then
        who.encoreTurns, who.encoreMove = 2, f.ids.SOLARBEAM
      end
      if spec.imprison then
        b.player.imprison = true
      end
      if spec.choice then
        who.mon.item, who.choicedMove = "ITEM_540", f.ids.SOLARBEAM
      end
      if spec.switch then
        who.perishTurns = 0
      end
      if spec.locked then
        who.charging, who.chargeReady = who.curMoves[1], true
      end
      if spec.recharge then
        who.mustRecharge = true
      end
    end
    if spec.stock then
      who.mon.hp = 1
    end
    local draws = {}
    b.rng = function(lo, hi)
      draws[#draws + 1] = { lo, hi }
      return lo or 0
    end
    brain.calls, brain.seen, brain.lastView = 0, {}, nil
    brain.pick, brain.mode = spec.pick, spec.mode or "pick"
    f.e.state.mode = (spec.stock or spec.switch) and "delegate" or "suppress"
    local ok, action = pcall(function()
      if native then
        return require("src.core.game3.battle.commands").enemyAction(b, id)
      end
      return b:enemyAction(who)
    end)
    T.eq(ok, true, "native brain failure is contained by opponent controller")
    local kind = type(action) == "table" and (f.kind(action) or "move") or false
    local slot
    if type(action) == "table" then
      if kind == "switch" then
        slot = native and action.slot or action.index
      elseif native then
        slot = action.slot
      else
        for i, move in ipairs(who.curMoves) do
          if action == move or action.id == move.id then
            slot = i
            break
          end
        end
      end
    end
    T.eq(brain.calls, spec.noBrain and 0 or 1, spec.name .. " brain invocation count")
    if spec.expected then
      T.eq(slot or kind == "recharge" and 1, spec.expected, spec.name .. " native selected slot")
    end
    if spec.expectedItem then
      T.eq(kind, "item", "native item runs before brain")
    end
    if spec.expectedSwitch then
      T.eq(kind, "switch", "native switch runs before brain")
    end
    if brain.calls > 0 then
      T.eq(brain.lastView.battle, b, "brain receives exact native battle")
      T.eq(brain.lastView.user, who, "brain receives exact native user")
      T.eq(brain.lastView.data, f.data, "brain receives current mod data")
      T.eq(brain.lastView.rng, b.rng, "brain receives native RNG function")
    end
    rows[#rows + 1] = {
      brain = spec.name,
      calls = brain.calls,
      hookCalls = f.e.state.calls,
      kind = kind,
      slot = slot or false,
      views = brain.seen,
      rng = draws,
    }
    statusMove.power = oldPower
  end
  if registry then
    registry.bind(nil)
  end
  return rows
end
