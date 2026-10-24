-- Unchanged public scoring callback, actual constructors and native query producers.
return function(f, backend)
  local native, T, rows = backend == "gen1", f.T, {}
  local copy = require("src.mods.Merge").deepCopy
  local State, Registry, AI, oldPack, Pokemon, oldBattleMoves
  if native then
    State, Registry, AI =
      require("src.core.game3.battle.state"),
      require("src.core.game3.battle.mod_registries"),
      require("src.core.game3.battle.ai")
    Registry.bind(f.data)
    oldPack = AI._pack
    Pokemon = require("src.core.game3.pokemon")
    oldBattleMoves = Pokemon._battleMoves
    Pokemon._battleMoves = copy(oldBattleMoves or {})
    Pokemon._battleMoves[0] = { type = 0, power = 0, effect = 0 }
  else
    f.game.mods = f.result.loader
  end
  local specs = {
    { name = "considered-type", query = "get_move_type_from_result", considered = true, value = 12 },
    { name = "considered-power", query = "get_move_power_from_result", considered = true, value = 120 },
    { name = "considered-effect", query = "get_move_effect_from_result", considered = true, value = 151 },
    { name = "target-last-type", query = "get_move_type_from_result", value = 12 },
    { name = "user-last-power", query = "get_move_power_from_result", which = 1, value = 70 },
    { name = "target-last-effect", query = "get_move_effect_from_result", value = 151 },
    { name = "none-type", query = "get_move_type_from_result", value = 0, noHistory = true },
    { name = "none-power", query = "get_move_power_from_result", value = 0, noHistory = true },
    { name = "none-effect", query = "get_move_effect_from_result", value = 0, noHistory = true },
    { name = "invalid-definition", query = "get_move_power_from_result", value = 0, invalid = true },
    { name = "protect-target", query = "get_protect_count", value = 3, count = 3 },
    { name = "protect-user", query = "get_protect_count", which = 1, value = 2, count = 2 },
    { name = "type-target", query = "is_of_type", value = 1, typ = 10 },
    { name = "type-user", query = "is_of_type", which = 1, value = 1, typ = 10 },
    { name = "type-partner", query = "is_of_type", which = 3, value = 1, typ = 10, double = true },
    { name = "flash-target", query = "if_flash_fired", flash = true },
    { name = "flash-user", query = "if_flash_fired", which = 1, flash = true },
    { name = "flash-partner", query = "if_flash_fired", which = 3, flash = true, double = true },
    { name = "flash-absent-partner", query = "if_flash_fired", which = 3, flash = true },
    { name = "produced-last-move", query = "get_move_power_from_result", value = 35, produce = "hit" },
    { name = "produced-flash-fire", query = "if_flash_fired", which = 1, produce = "flash" },
    { name = "produced-protection", query = "get_protect_count", which = 1, value = 1, produce = "protect" },
  }
  for _, spec in ipairs(specs) do
    local b = f.freshDecision({}, spec.double)
    local function at(id)
      return native and State.battler(b, id) or b:battlerAt(id)
    end
    local user, target = at(1), at(0)
    local oldProgram = f.data.constants.gen3BattleAI
    for id = 0, spec.double and 3 or 1 do
      local who = at(id)
      if native then
        who.mon.moves, who.mon.pp = { 33, 76 }, { 10, 10 }
        who.lastMove = id == 1 and 19 or 76
        if spec.noHistory then
          who.lastMove = nil
        end
        if spec.invalid then
          who.lastMove = 999
        end
        who.expProtectStreak = spec.count or 0
        who.expFlashFire = spec.flash
      else
        who.curMoves = { { id = f.ids.TACKLE, pp = 10 }, { id = f.ids.SOLARBEAM, pp = 10 } }
        who.mon.moves = who.curMoves
        who.lastMove = id == 1 and f.ids.FLY or f.ids.SOLARBEAM
        if spec.noHistory then
          who.lastMove = nil
        end
        if spec.invalid then
          who.lastMove = 999
        end
        who.protectRun = spec.count or 0
        who.flashFire = spec.flash
      end
    end
    local restore = function() end
    if spec.produce then
      local name, number =
        spec.produce == "protect" and "PROTECT" or "TACKLE", spec.produce == "protect" and 182 or 33
      local raw, key =
        native and require("src.core.game3.battle.moves")._rom or f.data.moves,
        spec.produce == "protect" and "MOVE_182" or f.ids.TACKLE
      local old = native and raw[number] or raw[key]
      local names = native and require("src.core.game3.battle.moves").BY_NUM
      local oldName = names and names[number]
      if native then
        raw[number] = spec.produce == "protect"
            and {
              effect = 111,
              power = 0,
              type = 0,
              accuracy = 0,
              pp = 10,
              target = 16,
              priority = 3,
              flags = 0,
            }
          or copy(old)
        if spec.produce == "flash" then
          raw[number].type = 10
        end
        names[number] = name
      else
        raw[key] = spec.produce == "protect"
            and {
              id = key,
              index = 182,
              name = "PROTECT",
              effect = "PROTECT_EFFECT",
              gen3Effect = 111,
              power = 0,
              type = "NORMAL",
              pp = 10,
              target = 16,
              priority = 3,
            }
          or copy(old)
        if spec.produce == "flash" then
          raw[key].type = "FIRE"
        end
      end
      restore = function()
        if native then
          raw[number], names[number] = old, oldName
        else
          raw[key] = old
        end
      end
      for id = 0, 1 do
        local who = at(id)
        who.mon.hp = 400
        if native then
          who.mon.attack, who.mon.defense, who.mon.speed, who.mon.spAtk, who.mon.spDef, who.ability, who.mon.ability =
            50, 50, 50, 50, 50, 0, 0
        else
          who.mon.stats =
            { hp = 400, attack = 50, defense = 50, speed = 50, special = 50, spatk = 50, spdef = 50 }
          who.curStats = who.mon.stats
          who.ability, who.mon.ability, who.abilityOverride = nil, nil, false
        end
      end
      local actor, victim =
        spec.produce == "protect" and user or target, spec.produce == "protect" and user or user
      if spec.produce == "flash" then
        if native then
          user.ability, user.mon.ability = 18, 18
        else
          user.abilityOverride = "FLASH_FIRE"
        end
      end
      if native then
        actor.mon.moves[1] = number
        require("src.core.game3.battle.engine").resolveMove(
          actor,
          victim,
          number,
          1,
          require("src.core.game3.battle.adapter").new(b),
          b,
          {},
          {}
        )
      else
        actor.curMoves[1] = { id = key, pp = 10 }
        actor.mon.moves = actor.curMoves
        b:performMove(actor, victim, actor.curMoves[1])
      end
      if spec.produce == "protect" then
        T.eq(native and user.expProtectStreak or user.protectRun, 1, "actual native Protect produces counter")
      end
      if spec.produce == "flash" then
        T.eq(native and user.expFlashFire or user.flashFire, true, "actual native hit produces Flash Fire")
      end
      if spec.produce == "hit" then
        T.eq(
          native and target.lastMove or target.lastMove == f.ids.TACKLE and 33,
          33,
          "actual native attack produces last move"
        )
      end
    end
    local branch = spec.query == "if_flash_fired"
    if native then
      b.aiClass, b.aiFlags = "PORTABLE_SCORE_A", 1
      local ops = {}
      if spec.query:match("^get_move_") then
        ops[#ops + 1] = spec.considered and { op = "get_considered_move" }
          or { op = "get_last_used_move", battler = spec.which or 0 }
      end
      ops[#ops + 1] =
        { op = spec.query, battler = spec.which or 0, type = spec.typ, target = branch and "bonus" or nil }
      if not branch then
        ops[#ops + 1] = { op = "if_equal", value = spec.value, target = "bonus" }
      end
      ops[#ops + 1] = { op = "end" }
      AI._pack = {
        table = { "main" },
        scripts = { main = ops, bonus = { { op = "score", delta = 5 }, {
          op = "end",
        } } },
      }
    else
      b.trainer.aiClass, b.trainer.aiFlags = "PORTABLE_SCORE_A", 1
      local ops = {}
      if spec.query:match("^get_move_") then
        ops[#ops + 1] = spec.considered and { name = "get_considered_move", args = {} }
          or { name = "get_last_used_bank_move", args = { spec.which or 0 } }
      end
      ops[#ops + 1] = {
        name = spec.query,
        args = branch and { spec.which or 0, 10 }
          or spec.query == "is_of_type" and { spec.which or 0, spec.typ }
          or { spec.which or 0 },
      }
      if not branch then
        ops[#ops + 1] = { name = "if_equal", args = { spec.value, 10 } }
      end
      ops[#ops + 1] = { name = "end", args = {} }
      for i, op in ipairs(ops) do
        op.next = i + 1
      end
      ops[10], ops[11] = { name = "score", args = { 5 }, next = 11 }, { name = "end", args = {} }
      f.data.constants.gen3BattleAI = { entries = { [0] = 1 }, code = ops }
    end
    f.e.scoring.calls, f.e.scoring.mode = {}, "nil"
    f.e.state.mode = "suppress"
    local draws = {}
    b.rng = function(lo, hi)
      draws[#draws + 1] = { lo, hi }
      return lo or 0
    end
    local ok, action = pcall(function()
      if native then
        return require("src.core.game3.battle.commands").enemyAction(b, 1)
      end
      return b:enemyAction(user)
    end)
    T.eq(ok, true, spec.name .. " actual native opponent query completes")
    local slot, targetId
    if native then
      slot, targetId = action and action.slot, action and action.target
    else
      for i, move in ipairs(user.curMoves) do
        if action == move then
          slot = i
        end
      end
      local selected = b.chosenTargets and b.chosenTargets[1]
      if selected then
        for i = 0, 3 do
          if selected == at(i) then
            targetId = i
          end
        end
      end
    end
    T.check(slot ~= nil, spec.name .. " returns a real selected move")
    rows[#rows + 1] = {
      query = spec.name,
      slot = slot or false,
      target = targetId or false,
      calls = f.e.scoring.calls,
      rng = draws,
      producedHp = spec.produce and user.mon.hp or false,
    }
    restore()
    f.data.constants.gen3BattleAI = oldProgram
  end
  if native then
    AI._pack = oldPack
    Registry.bind(nil)
    Pokemon._battleMoves = oldBattleMoves
  end
  return rows
end
