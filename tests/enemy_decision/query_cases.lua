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
  for _, spec in ipairs({
    { name = "has-observed-move", query = "if_has_move", member = 76 },
    { name = "has-unobserved-move", query = "if_has_move", member = 76, noHistory = true },
    { name = "lacks-unobserved-move", query = "if_doesnt_have_move", member = 76, noHistory = true },
    { name = "user-has-move", query = "if_has_move", which = 1, member = 33 },
    { name = "user-has-zero-pp-move", query = "if_has_move", which = 1, member = 76, zeroPP = true },
    { name = "has-observed-effect", query = "if_has_move_with_effect", member = 151 },
    { name = "has-unobserved-effect", query = "if_has_move_with_effect", member = 151, noHistory = true },
    { name = "has-zero-effect-unobserved", query = "if_has_move_with_effect", member = 0, noHistory = true },
    {
      name = "lacks-unobserved-effect",
      query = "if_doesnt_have_move_with_effect",
      member = 151,
      noHistory = true,
    },
    { name = "partner-positive-move", query = "if_has_move", which = 3, member = 19, double = true },
    { name = "partner-negative-move", query = "if_doesnt_have_move", which = 3, member = 19, double = true },
    {
      name = "partner-effect-uses-user",
      query = "if_has_move_with_effect",
      which = 3,
      member = 155,
      double = true,
    },
    { name = "absent-partner-move", query = "if_has_move", which = 3, member = 19 },
    {
      name = "fainted-partner-move",
      query = "if_has_move",
      which = 3,
      member = 19,
      double = true,
      fainted = true,
    },
    { name = "produced-observed-move", query = "if_has_move", member = 33, produce = "hit" },
    { name = "produced-observed-effect", query = "if_has_move_with_effect", member = 0, produce = "hit" },
  }) do
    specs[#specs + 1] = spec
  end
  for _, query in ipairs({ "if_target_taunted", "if_target_not_taunted" }) do
    for _, timer in ipairs({ 0, 1, 2 }) do
      specs[#specs + 1] = { name = query .. "-timer-" .. timer, query = query, taunt = timer }
    end
    specs[#specs + 1] = { name = query .. "-double", query = query, taunt = 2, double = true }
    specs[#specs + 1] = { name = query .. "-produced", query = query, produce = "taunt" }
  end
  local em = require("src.core.GameVersion").get() == "emerald"
  for _, spec in ipairs({
    { name = "held-own-metadata", query = "get_hold_effect", which = 1, held = 196, holder = 1, value = 39 },
    { name = "held-hidden-target", query = "get_hold_effect", held = 196, value = 0 },
    {
      name = "held-band-observed",
      query = "get_hold_effect",
      held = 196,
      observe = "band",
      value = em and 22 or 39,
    },
    {
      name = "held-band-failed",
      query = "get_hold_effect",
      held = 196,
      observe = "band",
      roll = 99,
      value = 0,
    },
    {
      name = "held-leftovers-observed",
      query = "get_hold_effect",
      held = 200,
      observe = "heal",
      value = em and 0 or 43,
    },
    {
      name = "held-leftovers-full",
      query = "get_hold_effect",
      held = 200,
      observe = "heal",
      full = true,
      value = 0,
    },
    {
      name = "held-target-effect-byte",
      query = "if_holds_item",
      held = 196,
      observe = "band",
      heldOperand = 39,
    },
    {
      name = "held-target-not-inventory",
      query = "if_holds_item",
      held = 196,
      observe = "band",
      heldOperand = 196,
      miss = true,
    },
    {
      name = "held-target-byte-or",
      query = "if_holds_item",
      held = 196,
      observe = "band",
      heldOperand = 0x0126,
    },
    {
      name = "held-own-physical-id",
      query = "if_holds_item",
      which = 1,
      holder = 1,
      held = 196,
      heldOperand = 196,
    },
    {
      name = "held-own-retail-or",
      query = "if_holds_item",
      which = 1,
      holder = 1,
      held = 0x1234,
      heldOperand = 0x1234,
      miss = true,
    },
    {
      name = "held-partner-physical-id",
      query = "if_holds_item",
      which = 3,
      holder = 3,
      held = 196,
      heldOperand = 196,
      double = true,
    },
  }) do
    specs[#specs + 1] = spec
  end
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
    if spec.member ~= nil then
      if spec.zeroPP then
        if native then
          user.mon.pp[2] = 0
        else
          user.curMoves[2].pp = 0
        end
      end
      if spec.double then
        local partner = at(3)
        if native then
          partner.mon.moves, partner.mon.pp = { 19 }, { 10 }
        else
          partner.curMoves = { { id = f.ids.FLY, pp = 10 } }
          partner.mon.moves = partner.curMoves
        end
        if spec.fainted then
          partner.mon.hp = 0
        end
      end
    end
    if spec.taunt ~= nil then
      if native then
        target.expTauntedTurns = spec.taunt
      else
        target.tauntTurns = spec.taunt
      end
    end
    local restore = function() end
    local observationDraws, itemHistory = {}, false
    if spec.held then
      local records = native and f.data.gen3Items._byId or f.data.items
      local changes = {}
      for _, row in ipairs({ { 39, 22 }, { 43, 0 }, { spec.held, spec.held == 200 and 43 or 39 } }) do
        local id, effect = row[1], row[2]
        local key = native and id or "ITEM_" .. id
        changes[#changes + 1] = { key = key, old = records[key] }
        records[key] = {
          index = id,
          name = "TEST HELD ITEM",
          pocket = "ITEMS",
          gen3HoldEffect = effect,
          holdEffect = native and effect
            or ({ [0] = "NONE", [22] = "EVASION_UP", [39] = "FOCUS_BAND", [43] = "LEFTOVERS" })[effect],
          holdEffectParam = 10,
        }
      end
      local holder = at(spec.holder or 0)
      holder.mon.item = native and spec.held or "ITEM_" .. spec.held
      if native then
        holder.item = spec.held
      else
        holder.items = records
      end
      holder.mon.hp, holder.mon.maxHp = spec.full and 100 or 90, 100
      holder.mon.stats = holder.mon.stats or {}
      holder.mon.stats.hp = 100
      b.rng = function(lo, hi)
        observationDraws[#observationDraws + 1] = { lo, hi }
        return spec.roll or lo or 0
      end
      if spec.observe == "heal" then
        if native then
          require("src.core.game3.battle.held_items").normal(
            require("src.core.game3.battle.adapter").new(b),
            holder
          )
        else
          b:holdItemTrigger(holder, "turn")
        end
      elseif spec.observe == "band" then
        if native then
          local Adapter = require("src.core.game3.battle.adapter")
          local M = require("src.core.game3.battle.engine").newContext(
            at(1),
            holder,
            33,
            1,
            Adapter.new(b),
            b,
            {},
            { hits = {} },
            {}
          )
          require("src.core.game3.battle.effects.hit").applySetDamage(M, 5)
        else
          b:applyDamage(holder, 5, true)
        end
      end
      itemHistory = copy(b._aiHistory and b._aiHistory.itemEffects or {})
      local expected = spec.observe == "band" and not spec.roll and 39
        or spec.observe == "heal" and not spec.full and 43
        or 0
      T.eq(itemHistory[0] or 0, expected, spec.name .. " actual producer records native byte")
      T.same(
        observationDraws,
        spec.observe == "band" and { { 0, 99 } } or {},
        spec.name .. " producer RNG ABI"
      )
      restore = function()
        for i = #changes, 1, -1 do
          records[changes[i].key] = changes[i].old
        end
      end
    end
    if spec.produce then
      local name, number =
        spec.produce == "taunt" and "TAUNT" or spec.produce == "protect" and "PROTECT" or "TACKLE",
        spec.produce == "taunt" and 269 or spec.produce == "protect" and 182 or 33
      local raw, key =
        native and require("src.core.game3.battle.moves")._rom or f.data.moves,
        spec.produce == "taunt" and "MOVE_269" or spec.produce == "protect" and "MOVE_182" or f.ids.TACKLE
      local old = native and raw[number] or raw[key]
      local names = native and require("src.core.game3.battle.moves").BY_NUM
      local oldName = names and names[number]
      if native then
        raw[number] = (spec.produce == "protect" or spec.produce == "taunt")
            and {
              effect = spec.produce == "taunt" and 175 or 111,
              power = 0,
              type = 0,
              accuracy = spec.produce == "taunt" and 100 or 0,
              pp = 10,
              target = spec.produce == "taunt" and 0 or 16,
              priority = spec.produce == "taunt" and 0 or 3,
              flags = 0,
            }
          or copy(old)
        if spec.produce == "flash" then
          raw[number].type = 10
        end
        names[number] = name
      else
        raw[key] = (spec.produce == "protect" or spec.produce == "taunt")
            and {
              id = key,
              index = number,
              name = name,
              effect = spec.produce == "taunt" and "TAUNT_EFFECT" or "PROTECT_EFFECT",
              gen3Effect = spec.produce == "taunt" and 175 or 111,
              power = 0,
              type = "NORMAL",
              pp = 10,
              target = spec.produce == "taunt" and 0 or 16,
              priority = spec.produce == "taunt" and 0 or 3,
            }
          or copy(old)
        if spec.produce == "flash" then
          raw[key].type = "FIRE"
        end
        if spec.produce == "taunt" then
          raw[key].accuracy = 100
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
        (spec.produce == "protect" or spec.produce == "taunt") and user or target,
        spec.produce == "taunt" and target or user
      if spec.produce == "flash" then
        if native then
          user.ability, user.mon.ability = 18, 18
        else
          user.abilityOverride = "FLASH_FIRE"
        end
      end
      if spec.produce == "taunt" then
        b.rng = function(lo)
          return lo
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
      if spec.produce == "taunt" then
        T.eq(
          native and target.expTauntedTurns or target.tauntTurns,
          2,
          "actual Taunt move produces two-tick timer"
        )
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
    local taunt = spec.query == "if_target_taunted" or spec.query == "if_target_not_taunted"
    local branch = spec.query == "if_flash_fired" or spec.member ~= nil or spec.heldOperand ~= nil or taunt
    if native then
      b.aiClass, b.aiFlags = "PORTABLE_SCORE_A", 1
      local ops = {}
      if spec.query:match("^get_move_") then
        ops[#ops + 1] = spec.considered and { op = "get_considered_move" }
          or { op = "get_last_used_move", battler = spec.which or 0 }
      end
      ops[#ops + 1] = {
        op = spec.query,
        battler = spec.which or 0,
        type = spec.typ,
        move = not spec.query:find("with_effect") and spec.member or nil,
        effect = spec.query:find("with_effect") and spec.member or nil,
        item = spec.heldOperand,
        target = branch and "bonus" or nil,
      }
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
        args = taunt and { 10 }
          or spec.heldOperand ~= nil and { spec.which or 0, spec.heldOperand, 10 }
          or spec.member ~= nil and { spec.which or 0, spec.member, 10 }
          or branch and {
            spec.which or 0,
            10,
          }
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
    if spec.held then
      -- Emerald's loaded per-target doubles program returns before custom
      -- layers in both native engines; the standalone VM matrix covers its
      -- item branch. Keep this bypass observable rather than claiming a call.
      local expectedCalls = em and spec.double and 0 or 2
      T.eq(#f.e.scoring.calls, expectedCalls, spec.name .. " native public-scoring delivery policy")
      for _, call in ipairs(f.e.scoring.calls) do
        T.eq(
          call.before,
          spec.miss and 100 or 105,
          spec.name .. " public scorer receives native query result"
        )
      end
      T.same(
        b._aiHistory and b._aiHistory.itemEffects or {},
        itemHistory,
        spec.name .. " scoring does not mutate item history"
      )
    end
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
      itemHistory = itemHistory,
      observationRng = observationDraws,
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
