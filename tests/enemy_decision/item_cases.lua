local function run(f, root, backend)
  local T, rows = f.T, {}
  local copy = require("src.mods.Merge").deepCopy
  local function key(index)
    return backend == "gen1" and index or ("ITEM_%03d"):format(index)
  end
  local function install(index, bytes)
    if backend == "gen1" then
      require("src.core.game3.items_data")._byId[index] = {
        name = "CUSTOM TONIC",
        pocket = "ITEMS",
        effect = copy(bytes),
        price = 100,
      }
    else
      f.data.items[key(index)] = { id = key(index), index = index, name = "CUSTOM TONIC", price = 100 }
      f.data.constants.gen3ItemEffects[key(index)] =
        { bytes = copy(bytes), heal = true, amount = 255, cureAll = true }
    end
  end
  local function battler(b, id)
    if backend == "gen1" then
      return require("src.core.game3.battle.state").battler(b, id or 1)
    end
    return b:battlerAt(id or 1)
  end
  local function stock(b)
    local out = {}
    if backend == "gen1" then
      local h = require("src.core.game3.battle.ai_items").history(b)
      for i = 1, 4 do
        out[i] = h.items[i] or 0
      end
    else
      local h = require("src.battle.EnemyItems").history(b)
      for i = 1, 4 do
        local row = h.items[i]
        out[i] = row and not (b.gen3ItemsUsed or {})[row.slot] and f.data.items[row.key].index or 0
      end
    end
    return out
  end
  local function snapshot(b, id)
    local b1, b0 = battler(b, id), battler(b, 0)
    local side = backend == "gen1" and b.enemySide or b:sideOf(b1)
    return {
      hp = b1.mon.hp,
      status = b1.mon.status or false,
      confusion = (backend == "gen1" and b1.confusionTurns or b1.confusedTurns) or 0,
      nightmare = (backend == "gen1" and b1.expNightmare or b1.nightmare) or false,
      toxic = b1.toxicCounter or 0,
      infatuated = (backend == "gen1" and b1.expInfatuated or b1.infatuated) ~= nil,
      focus = b1.focusEnergy == true,
      attack = b1.stages.attack or 0,
      defense = b1.stages.defense or 0,
      speed = b1.stages.speed or 0,
      accuracy = b1.stages.accuracy or 0,
      spatk = b1.stages[backend == "gen1" and "spAtk" or "spatk"] or 0,
      mist = side and (backend == "gen1" and side.expMistTurns or side.mistTurns) or 0,
      playerHP = b0.mon.hp,
      playerAttack = b0.stages.attack or 0,
      leftHP = battler(b, 1).mon.hp,
      leftAttack = battler(b, 1).stages.attack or 0,
      stock = stock(b),
    }
  end
  local function prepare(spec)
    local b = f.freshDecision(spec.stock or { key(spec.index or 300) }, spec.double)
    local who = battler(b, spec.id)
    who.mon.hp, who.mon.status = spec.hp or 400, spec.status
    who.shownHP = who.mon.hp
    who.stages.attack = spec.stage or 0
    if backend == "gen1" then
      who.status, who.confusionTurns = spec.status, spec.confusion
      who.expNightmare, who.toxicCounter = spec.nightmare, spec.toxic
      who.expInfatuated = spec.infatuated and true or nil
      who.isFirstTurn = spec.age == nil and 2 or spec.age
      b.enemySide.expMistTurns = spec.mist
    else
      who.confusedTurns, who.nightmare, who.toxicCounter = spec.confusion, spec.nightmare, spec.toxic
      who.infatuated = spec.infatuated and b.player or nil
      who.turnsOut = spec.age and 2 - spec.age or 0
      b:sideOf(who).mistTurns = spec.mist
    end
    who.destinyBond = true
    who[backend == "gen1" and "expGrudge" or "grudge"] = true
    local party = backend == "gen1" and b.foeParty or b.enemyParty
    if spec.alive then
      for i = 2, #party do
        party[i].hp = i <= spec.alive and 400 or 0
      end
    end
    if spec.egg then
      party[2].isEgg = true
    end
    f.e.state.mode = spec.explicit and "override" or "delegate"
    f.e.state.decision = { kind = "item", item = spec.index or 300 }
    return b
  end
  local specs = {
    { name = "x-attack", bytes = { 1, 0, 0, 0, 0, 0 }, kind = 4, flags = 1, attack = 1 },
    { name = "x-multiple-stats-focus", bytes = { 33, 35, 66, 0, 0, 0 }, kind = 4, flags = 175, attack = 1 },
    {
      name = "x-capped-still-used",
      bytes = { 1, 0, 0, 0, 0, 0 },
      stage = 6,
      kind = 4,
      flags = 1,
      attack = 6,
    },
    { name = "x-last-first-turn", bytes = { 1, 0, 0, 0, 0, 0 }, age = 1, kind = 4, flags = 1, attack = 1 },
    { name = "x-later-turn", bytes = { 1, 0, 0, 0, 0, 0 }, age = 0 },
    {
      name = "x-explicit-later-turn",
      bytes = { 1, 0, 0, 0, 0, 0 },
      age = 0,
      explicit = true,
      kind = 4,
      flags = 0,
      attack = 1,
    },
    {
      name = "x-right-slot",
      double = true,
      id = 3,
      bytes = { 1, 0, 0, 0, 0, 0 },
      kind = 4,
      flags = 1,
      attack = 1,
    },
    { name = "guard-spec", bytes = { 0, 0, 0, 128, 0, 0 }, kind = 5, flags = 0, afterMist = 5 },
    { name = "guard-spec-existing", bytes = { 0, 0, 0, 128, 0, 0 }, mist = 3 },
    { name = "guard-spec-later-turn", bytes = { 0, 0, 0, 128, 0, 0 }, age = 0 },
    {
      name = "guard-spec-right-slot",
      bytes = { 0, 0, 0, 128, 0, 0 },
      double = true,
      id = 3,
      kind = 5,
      flags = 0,
      afterMist = 5,
    },
    {
      name = "sleep-cure",
      bytes = { 0, 0, 0, 32, 0, 0 },
      status = "SLP",
      nightmare = true,
      kind = 3,
      flags = 32,
    },
    { name = "toxic-cure", bytes = { 0, 0, 0, 16, 0, 0 }, status = "TOX", toxic = 8, kind = 3, flags = 16 },
    { name = "burn-cure", bytes = { 0, 0, 0, 8, 0, 0 }, status = "BRN", kind = 3, flags = 8 },
    { name = "freeze-cure", bytes = { 0, 0, 0, 4, 0, 0 }, status = "FRZ", kind = 3, flags = 4 },
    { name = "paralysis-cure", bytes = { 0, 0, 0, 2, 0, 0 }, status = "PAR", kind = 3, flags = 2 },
    { name = "confusion-cure", bytes = { 0, 0, 0, 1, 0, 0 }, confusion = 3, kind = 3, flags = 1 },
    {
      name = "combined-cures",
      bytes = { 0, 0, 0, 63, 0, 0 },
      status = "TOX",
      toxic = 6,
      confusion = 3,
      kind = 3,
      flags = 17,
    },
    { name = "cure-wrong-condition", bytes = { 0, 0, 0, 8, 0, 0 }, status = "PAR" },
    { name = "heal-strict-missing-equals", bytes = { 0, 0, 0, 0, 4, 0, 20 }, hp = 380 },
    {
      name = "heal-strict-missing-above",
      bytes = { 0, 0, 0, 0, 4, 0, 20 },
      hp = 379,
      kind = 2,
      flags = 0,
      afterHP = 399,
    },
    { name = "heal-zero-parameter", bytes = { 0, 0, 0, 0, 4, 0, 0 }, hp = 1 },
    { name = "heal-dead", bytes = { 0, 0, 0, 0, 4, 0, 20 }, hp = 0 },
    {
      name = "heal-full-sentinel",
      bytes = { 0, 0, 0, 0, 4, 0, 255 },
      hp = 1,
      kind = 2,
      flags = 0,
      afterHP = 400,
    },
    {
      name = "heal-half-sentinel",
      bytes = { 0, 0, 0, 0, 4, 0, 254 },
      hp = 1,
      kind = 2,
      flags = 0,
      afterHP = 201,
    },
    {
      name = "heal-level-sentinel",
      bytes = { 0, 0, 0, 0, 4, 0, 253 },
      hp = 1,
      kind = 2,
      flags = 0,
      afterHP = 1,
    },
    {
      name = "heal-ev-parameter-native-selection",
      bytes = { 0, 0, 0, 0, 7, 0, 99, 88, 20 },
      hp = 379,
    },
    {
      name = "heal-ev-pp-native-selection",
      bytes = { 0, 0, 0, 0, 31, 0, 99, 88, 20, 10 },
      hp = 379,
    },
    {
      name = "heal-ev-native-application",
      bytes = { 0, 0, 0, 0, 7, 0, 99, 88, 20 },
      hp = 1,
      kind = 2,
      flags = 0,
      afterHP = 100,
    },
    {
      name = "renamed-full-restore-quarter-boundary",
      index = 19,
      bytes = { 0, 0, 0, 63, 4, 0, 255 },
      hp = 100,
      status = "TOX",
    },
    {
      name = "renamed-full-restore-below-quarter",
      index = 19,
      bytes = { 0, 0, 0, 63, 4, 0, 255 },
      hp = 99,
      status = "TOX",
      kind = 1,
      flags = 0,
      afterHP = 400,
    },
    {
      name = "custom-full-heal-uses-raw-amount",
      bytes = { 0, 0, 0, 63, 4, 0, 255 },
      hp = 100,
      kind = 2,
      flags = 0,
      afterHP = 400,
    },
    {
      name = "full-restore-id-uses-modified-raw-effects",
      index = 19,
      bytes = { 1, 0, 0, 0, 0, 0 },
      hp = 99,
      kind = 1,
      flags = 0,
      afterHP = 99,
      attack = 1,
    },
    {
      name = "combined-heal-boost-mist",
      bytes = { 1, 0, 0, 128, 4, 0, 20 },
      hp = 1,
      kind = 2,
      flags = 0,
      afterHP = 21,
      attack = 1,
      afterMist = 5,
    },
    {
      name = "heal-selective-cure",
      bytes = { 0, 0, 0, 8, 4, 0, 20 },
      hp = 1,
      status = "PAR",
      kind = 2,
      flags = 0,
      afterHP = 21,
    },
    {
      name = "heal-all-cures-right",
      bytes = { 0, 0, 0, 63, 4, 0, 255 },
      hp = 1,
      status = "TOX",
      confusion = 2,
      toxic = 4,
      double = true,
      id = 3,
      kind = 2,
      flags = 0,
      afterHP = 400,
    },
    {
      name = "revive-explicit",
      bytes = { 0, 0, 0, 0, 68, 0, 254 },
      hp = 0,
      explicit = true,
      kind = 2,
      flags = 0,
      afterHP = 200,
    },
    {
      name = "revive-live-no-effect",
      bytes = { 0, 0, 0, 0, 68, 0, 254 },
      hp = 1,
      explicit = true,
      kind = 2,
      flags = 0,
      afterHP = 1,
    },
    { name = "infatuation-auto-unrecognized", bytes = { 128, 0, 0, 0, 0, 0 }, infatuated = true },
    {
      name = "infatuation-explicit",
      bytes = { 128, 0, 0, 0, 0, 0 },
      infatuated = true,
      explicit = true,
      kind = 6,
      flags = 0,
    },
    {
      name = "unrecognized-stops-stock",
      bytes = { 0, 0, 0, 0, 0, 0 },
      hp = 1,
      stock = { key(300), f.item("POTION") },
    },
    {
      name = "missing-effect-skips-stock",
      bytes = false,
      hp = 1,
      alive = 2,
      stock = { key(300), f.item("POTION") },
      kind = 2,
      flags = 0,
      afterHP = 21,
    },
    {
      name = "only-four-stock-slots",
      bytes = { 0, 0, 0, 0, 0, 0 },
      hp = 1,
      explicit = true,
      stock = { 0, 0, 0, 0, key(300) },
    },
    {
      name = "stock-compacts-holes",
      bytes = { 0, 0, 0, 0, 4, 0, 20 },
      hp = 1,
      stock = { 0, key(300), 0, key(300) },
      kind = 2,
      flags = 0,
      afterHP = 21,
    },
    {
      name = "duplicate-first-slot",
      bytes = { 0, 0, 0, 0, 4, 0, 20 },
      hp = 1,
      stock = { key(300), key(300) },
      kind = 2,
      flags = 0,
      afterHP = 21,
    },
  }
  for _, spec in ipairs(specs) do
    install(spec.index or 300, spec.bytes or nil)
    if spec.bytes == false and backend ~= "gen1" then
      f.data.constants.gen3ItemEffects[key(300)] = nil
    end
    local b = prepare(spec)
    local who = battler(b, spec.id)
    local action = f.query(spec.id)
    T.eq(action and action.aiItemType or false, spec.kind or false, spec.name .. " native item type")
    if action then
      T.eq(action.aiItemFlags, spec.flags, spec.name .. " native item flags")
      f.execute(action, spec.id)
      T.eq(who.destinyBond, nil, spec.name .. " clears Destiny Bond")
      T.eq(who[backend == "gen1" and "expGrudge" or "grudge"], nil, spec.name .. " clears Grudge")
    end
    local after = snapshot(b, spec.id)
    if spec.afterHP then
      T.eq(after.hp, spec.afterHP, spec.name .. " actual healing")
    end
    if spec.attack then
      T.eq(after.attack, spec.attack, spec.name .. " actual stat effect")
    end
    if spec.afterMist then
      T.eq(after.mist, spec.afterMist, spec.name .. " side-owned mist")
    end
    T.eq(after.playerHP, 400, spec.name .. " cannot heal the player")
    T.eq(after.playerAttack, 0, spec.name .. " cannot boost the player")
    if spec.id == 3 then
      T.eq(after.leftHP, 400, spec.name .. " cannot heal the other foe")
      T.eq(after.leftAttack, 0, spec.name .. " cannot boost the other foe")
    end
    rows[#rows + 1] = {
      mode = "raw-item",
      name = spec.name,
      kind = action and action.aiItemType or false,
      flags = action and action.aiItemFlags or 0,
      after = after,
    }
  end
  install(300, { 0, 0, 0, 0, 4, 0, 20 })
  do
    local alias = "RENAMED_TONIC_ALIAS"
    if backend == "gen1" then
      require("src.core.game3.items_data")._byName[alias] = 300
    else
      f.data.items[alias] = { id = alias, index = 300, name = "DISPLAY ALIAS" }
    end
    local b = prepare({ hp = 1, explicit = true })
    f.e.state.decision.item = alias
    local action = f.query()
    T.eq(f.kind(action), "item", "public alias resolves to stocked physical item")
    f.execute(action)
    T.eq(f.mon().hp, 21, "alias uses physical effect bytes")
    rows[#rows + 1] = { mode = "item-alias", after = snapshot(b) }
  end
  do
    install(301, { 0, 0, 0, 128, 0, 0 })
    local b = prepare({ double = true, index = 301 })
    f.execute(f.query())
    local move = backend == "gen1" and 45 or "MOVE_045"
    if backend == "gen1" then
      local Moves = require("src.core.game3.battle.moves")
      Moves._rom[45] = {
        power = 0,
        type = 0,
        effect = 18,
        pp = 10,
        accuracy = 100,
        flags = 51,
        target = 0,
        priority = 0,
      }
      Moves.BY_NUM[45], Moves._numByName.GROWL = "GROWL", 45
      f.data.gen3Pokemon._moveNames[45] = "GROWL"
    else
      f.data.moves[move] = {
        id = move,
        index = 45,
        name = "GROWL",
        power = 0,
        type = "NORMAL",
        effect = "ATTACK_DOWN1_EFFECT",
        pp = 10,
        accuracy = 100,
      }
    end
    local function growl(id)
      local user, target = battler(b, 0), battler(b, id)
      if backend == "gen1" then
        require("src.core.game3.battle.engine").resolveMove(
          user,
          target,
          move,
          nil,
          require("src.core.game3.battle.adapter").new(b),
          b,
          {},
          {}
        )
      else
        b:performMove(user, target, { id = move, pp = 10 })
      end
    end
    for turn = 0, 5 do
      if turn > 0 then
        if backend == "gen1" then
          require("src.core.game3.battle.residuals").collectEvents(
            require("src.core.game3.battle.adapter").new(b)
          )
        else
          require("src.battle.GbaItemSchedule").residuals(b)
        end
      end
      growl(1)
      growl(3)
      T.eq(battler(b, 1).stages.attack or 0, turn == 5 and -1 or 0, "Mist protects its user until expiry")
      T.eq(battler(b, 3).stages.attack or 0, turn == 5 and -1 or 0, "Mist protects partner until expiry")
      rows[#rows + 1] = { mode = "native-mist-lifetime", turn = turn, after = snapshot(b, 3) }
    end
  end
  do
    local b = prepare({ hp = 1, stock = { key(300), key(300) } })
    local first = f.query()
    T.eq(f.kind(first), "item", "first duplicate is available")
    local second = f.query()
    T.eq(second, nil, "second duplicate stays gated by the initial stock size")
    local party = backend == "gen1" and b.foeParty or b.enemyParty
    party[3].hp = 0
    local third = f.query()
    T.eq(f.kind(third), "item", "second duplicate unlocks after a bench faint")
    rows[#rows + 1] = { mode = "stock-unlock", stock = stock(b) }
  end
  do
    install(302, { 0, 0, 0, 32, 0, 0 })
    for _, egg in ipairs({ false, true }) do
      local b = prepare({ status = "SLP", egg = egg, stock = { key(300), key(302) } })
      local action = f.query()
      T.eq(f.kind(action), egg and "item" or false, "egg does not count as valid living trainer mon")
      if action then
        f.execute(action)
      end
      rows[#rows + 1] = { mode = "stock-egg-boundary", egg = egg, after = snapshot(b) }
    end
  end
  do
    local b = prepare({ double = true, hp = 1, explicit = true, stock = { key(300), key(300) } })
    f.mon(3).hp = 1
    local first = f.query(1)
    local second = f.query(3)
    local third = f.query(1)
    T.eq(f.kind(first), "item", "left foe reserves first physical stock")
    T.eq(f.kind(second), "item", "right foe reserves second physical stock")
    T.eq(third, nil, "both foes share one exhausted stock")
    f.execute(first, 1)
    f.execute(second, 3)
    T.eq(f.mon(1).hp, 21, "left physical stock heals left foe")
    T.eq(f.mon(3).hp, 21, "right physical stock heals right foe")
    rows[#rows + 1] = { mode = "shared-double-stock", left = snapshot(b, 1), right = snapshot(b, 3) }
  end
  do
    local b = prepare({ double = true, index = 301 })
    local who = battler(b, 1)
    if backend == "gen1" then
      local Moves = require("src.core.game3.battle.moves")
      Moves._rom[54] = {
        power = 0,
        type = 15,
        effect = 46,
        pp = 10,
        accuracy = 100,
        flags = 0,
        target = 16,
        priority = 0,
      }
      Moves.BY_NUM[54], Moves._numByName.MIST = "MIST", 54
      f.data.gen3Pokemon._moveNames[54] = "MIST"
      require("src.core.game3.battle.engine").resolveMove(
        who,
        who,
        54,
        nil,
        require("src.core.game3.battle.adapter").new(b),
        b,
        {},
        {}
      )
    else
      f.data.moves.MOVE_054 = {
        id = "MOVE_054",
        index = 54,
        name = "MIST",
        power = 0,
        type = "ICE",
        effect = "MIST_EFFECT",
        pp = 10,
        accuracy = 100,
      }
      b:performMove(who, who, { id = "MOVE_054", pp = 10 })
    end
    T.eq(f.query(), nil, "native Mist move prevents wasting a Guard Spec")
    T.eq(snapshot(b, 3).mist, 5, "native Mist move shares partner protection")
    rows[#rows + 1] = { mode = "native-mist-before-item", after = snapshot(b, 3) }
  end
  if backend ~= "gen1" then
    local record = f.data.constants.gen3ItemEffects[key(300)]
    record.bytes, record.heal, record.amount, record.cureAll = nil, true, 20, nil
    local b = prepare({ hp = 1 })
    local action = f.query()
    T.eq(f.kind(action), "item", "old medicine cache retains its represented heal semantics")
    f.execute(action)
    T.eq(f.mon().hp, 21, "old medicine cache can still heal")
    record.heal, record.amount, record.battle = nil, nil, true
    b = prepare({ explicit = true })
    T.eq(f.query(), nil, "old battle-only cache requires raw bytes instead of inventing stat bits")
    T.eq(stock(b)[1], 300, "missing raw effect cannot consume stocked item")
    record.bytes = { 0, 0, 0, 0, 4, 0 }
    T.eq(f.query(), nil, "truncated raw healing parameter is refused")
  end
  return rows
end
return run
