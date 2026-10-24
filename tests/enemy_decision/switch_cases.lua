-- Both engines use their real SDK/query/AI. Only cartridge/session data and
-- the deterministic RNG stream are supplied here; no decision code is mocked.
local function run(f, root, backend)
  local T, rows = f.T, {}
  local copy = require("src.mods.Merge").deepCopy
  local ids = {
    NORMAL = 0,
    FLYING = 2,
    POISON = 3,
    GROUND = 4,
    BUG = 6,
    GHOST = 7,
    STEEL = 8,
    FIRE = 10,
    WATER = 11,
    GRASS = 12,
    ELECTRIC = 13,
  }
  local abilities = {
    NONE = 0,
    VOLT_ABSORB = 10,
    WATER_ABSORB = 11,
    FLASH_FIRE = 18,
    SHADOW_TAG = 23,
    WONDER_GUARD = 25,
    LEVITATE = 26,
    NATURAL_CURE = 30,
    MAGNET_PULL = 42,
    ARENA_TRAP = 71,
  }
  local species =
    { { "CHARMANDER", 4 }, { "CHARMELEON", 5 }, { "PIDGEY", 16 }, { "MEW", 151 }, { "NIDORAN_F", 29 } }
  local extraMoves = {
    { "EMBER", 52, 40, "FIRE" },
    { "SURF", 57, 95, "WATER" },
    { "THUNDERBOLT", 85, 95, "ELECTRIC" },
    { "GROWTH", 74, 0, "GRASS" },
    { "SONICBOOM", 49, 1, "NORMAL" },
    { "STRUGGLE", 165, 50, "NORMAL" },
  }
  local moveIds = copy(f.ids)
  for _, row in ipairs(extraMoves) do
    local name, index, power, kind = unpack(row)
    if backend == "gen1" then
      local Moves = require("src.core.game3.battle.moves")
      Moves._rom[index] = {
        power = power,
        type = ids[kind],
        effect = 0,
        pp = 10,
        accuracy = 100,
        flags = 51,
        target = 0,
        priority = 0,
      }
      Moves.BY_NUM[index], Moves._numByName[name] = name, index
      f.data.gen3Pokemon._moveNames[index] = name
      moveIds[name] = index
    else
      local key = ("MOVE_%03d"):format(index)
      f.data.moves[key] = {
        id = key,
        index = index,
        name = name,
        type = kind,
        power = power,
        pp = 10,
        accuracy = 100,
        effect = "NO_ADDITIONAL_EFFECT",
      }
      moveIds[name] = key
    end
  end
  if backend == "gen1" then
    for name, key in pairs(f.ids) do
      moveIds[name] = require("src.core.game3.battle.moves").numForName(key)
    end
  else
    -- Relevant rows from the cartridge matchup data for the bounded species
    -- and moves used below, rather than the old three-type triangle fixture.
    local triples = {
      { "NORMAL", "GHOST", 0 },
      { "NORMAL", "STEEL", 5 },
      { "FIRE", "FIRE", 5 },
      { "FIRE", "WATER", 5 },
      { "FIRE", "GRASS", 20 },
      { "FIRE", "BUG", 20 },
      { "FIRE", "STEEL", 20 },
      { "WATER", "FIRE", 20 },
      { "WATER", "WATER", 5 },
      { "WATER", "GRASS", 5 },
      { "WATER", "GROUND", 20 },
      { "GRASS", "FIRE", 5 },
      { "GRASS", "WATER", 20 },
      { "GRASS", "GRASS", 5 },
      { "GRASS", "POISON", 5 },
      { "GRASS", "GROUND", 20 },
      { "GRASS", "FLYING", 5 },
      { "GRASS", "BUG", 5 },
      { "GRASS", "STEEL", 5 },
      { "ELECTRIC", "WATER", 20 },
      { "ELECTRIC", "ELECTRIC", 5 },
      { "ELECTRIC", "GRASS", 5 },
      { "ELECTRIC", "GROUND", 0 },
      { "ELECTRIC", "FLYING", 20 },
      { "GROUND", "FIRE", 20 },
      { "GROUND", "ELECTRIC", 20 },
      { "GROUND", "GRASS", 5 },
      { "GROUND", "POISON", 20 },
      { "GROUND", "FLYING", 0 },
      { "GROUND", "BUG", 5 },
      { "GROUND", "STEEL", 20 },
      { "FLYING", "ELECTRIC", 5 },
      { "FLYING", "GRASS", 20 },
      { "FLYING", "BUG", 20 },
      { "FLYING", "STEEL", 5 },
    }
    f.data.type_chart.matchups = {}
    for _, r in ipairs(triples) do
      f.data.type_chart.matchups[#f.data.type_chart.matchups + 1] =
        { attacker = r[1], defender = r[2], multiplier = r[3] }
    end
    require("src.battle.TypeChart").load(f.data)
  end
  local function battler(b, id)
    if backend == "gen1" then
      return require("src.core.game3.battle.state").battler(b, id)
    end
    return b:battlerAt(id)
  end
  local function setup(spec)
    local b = f.freshDecision({}, spec.double)
    local party = backend == "gen1" and b.foeParty or b.enemyParty
    local playerParty = backend == "gen1" and b.playerParty
      or { b.player.mon, spec.double and battler(b, 2).mon or nil }
    local configs =
      { spec.enemy or {}, spec.bench or {}, spec.third or {}, spec.player or {}, spec.ally or {} }
    for i, identity in ipairs(species) do
      local c, name, number = configs[i], identity[1], identity[2]
      local types = c.types or { "NORMAL" }
      local mon = i <= 3 and party[i] or playerParty[i - 3]
      if backend == "gen1" then
        f.data.gen3Pokemon._types[number] = { ids[types[1]], ids[types[2] or types[1]] }
        f.data.gen3Pokemon._abilities[number] = { abilities[c.ability or "NONE"], 0 }
      else
        local def = copy(f.data.pokemon.CHARMANDER)
        def.id, def.name, def.index, def.dex = name, name, number, number
        def.types, def.abilities = types, { c.ability or "NONE" }
        f.data.pokemon[name] = def
      end
      if mon then
        mon.species, mon.hp = backend == "gen1" and number or name, c.hp or 400
        mon.status, mon.isEgg = c.status, c.egg
        mon.moves = {}
        for _, move in ipairs(c.moves or { "TACKLE" }) do
          mon.moves[#mon.moves + 1] = backend == "gen1" and moveIds[move] or { id = moveIds[move], pp = 10 }
        end
        if backend == "gen1" then
          mon.ability, mon.maxHp = abilities[c.ability or "NONE"], 400
        end
      end
    end
    for id = 0, spec.double and 3 or 1 do
      local active = battler(b, id)
      local c = id == 0 and configs[4] or id == 1 and configs[1] or id == 2 and configs[5] or configs[2]
      if active then
        if backend == "gen1" then
          active.species, active.ability = active.mon.species, active.mon.ability
          active.type1, active.type2 = unpack(f.data.gen3Pokemon._types[active.mon.species])
          active.expTrapped, active.escapePrevention = c.trapped, c.escapePrevention
          active.expTrapTurns, active.expIngrain = c.boundTurns, c.ingrained
          active.perishSong, active.expPerishTurns = c.perish ~= nil, c.perish
          active.expLastLandedMove, active.expLastHitById = c.last and moveIds[c.last], c.hitBy
          active.status = c.status
        else
          active.def = f.data.pokemon[active.mon.species]
          active.curTypes, active.curMoves = active.def.types, active.mon.moves
          active.trapped, active.escapePrevention = c.trapped, c.escapePrevention
          active.boundTurns, active.ingrained, active.perishTurns = c.boundTurns, c.ingrained, c.perish
          active._gbaLastLandedMove, active._gbaLastHitById = c.last and moveIds[c.last], c.hitBy
        end
        active.stages = c.stages or {}
      end
    end
    local trace, seq = {}, 0
    b.rng = function(lo, hi)
      seq = seq + 1
      local value = spec.rolls and spec.rolls[seq]
      if value == nil then
        value = spec.high and hi or lo
      end
      T.eq(value >= lo and value <= hi, true, "RNG fixture stays inside native range")
      trace[#trace + 1] = { lo, hi, value }
      return value
    end
    f.e.state.mode = "delegate"
    return b, trace
  end
  local specs = {
    { name = "perish-zero", enemy = { perish = 0 }, expected = 2 },
    { name = "perish-one", enemy = { perish = 1 } },
    { name = "perish-trapped", enemy = { perish = 0, trapped = true } },
    { name = "perish-escape-prevention", enemy = { perish = 0, escapePrevention = true } },
    { name = "perish-bound", enemy = { perish = 0, boundTurns = 2 } },
    { name = "perish-ingrain", enemy = { perish = 0, ingrained = true } },
    { name = "perish-shadow-tag", enemy = { perish = 0 }, player = { ability = "SHADOW_TAG" } },
    {
      name = "perish-arena-trap-flying",
      enemy = { perish = 0, types = { "FLYING" } },
      player = { ability = "ARENA_TRAP" },
    },
    {
      name = "perish-magnet-pull",
      enemy = { perish = 0, types = { "STEEL" } },
      player = { ability = "MAGNET_PULL" },
    },
    { name = "perish-own-magnet-pull", enemy = { perish = 0, types = { "STEEL" }, ability = "MAGNET_PULL" } },
    { name = "perish-no-healthy-bench", enemy = { perish = 0 }, bench = { hp = 0 }, third = { hp = 0 } },
    { name = "perish-skip-egg", enemy = { perish = 0 }, bench = { egg = true }, expected = 3 },
    {
      name = "perish-super-candidate",
      enemy = { perish = 0 },
      player = { types = { "WATER" } },
      bench = { types = { "GRASS" } },
      third = { types = { "FIRE" }, moves = { "SOLARBEAM" } },
      expected = 3,
    },
    {
      name = "perish-status-candidate",
      enemy = { perish = 0 },
      player = { types = { "WATER" } },
      third = { moves = { "GROWTH" } },
      expected = 3,
    },
    {
      name = "perish-active-stab-fallback",
      enemy = { perish = 0, types = { "GROUND" } },
      third = { moves = { "DIG" } },
      expected = 3,
    },
    {
      name = "perish-fixed-damage-fallback",
      enemy = { perish = 0 },
      bench = { moves = { "SONICBOOM" } },
      third = { moves = { "TACKLE" } },
      expected = 3,
    },
    {
      name = "wonder-guard-switch",
      player = { types = { "WATER" }, ability = "WONDER_GUARD" },
      bench = { moves = { "SOLARBEAM" } },
      expected = 2,
    },
    {
      name = "wonder-guard-no-switch-roll",
      high = true,
      player = { types = { "WATER" }, ability = "WONDER_GUARD" },
      bench = { moves = { "SOLARBEAM" } },
    },
    {
      name = "wonder-guard-existing-super",
      high = true,
      enemy = { moves = { "SOLARBEAM" } },
      player = { types = { "WATER" }, ability = "WONDER_GUARD" },
      bench = { moves = { "SOLARBEAM" } },
    },
    {
      name = "wonder-guard-status-not-super",
      player = { types = { "WATER" }, ability = "WONDER_GUARD" },
      bench = { moves = { "GROWTH" } },
    },
    {
      name = "absorb-electric",
      high = true,
      enemy = { last = "THUNDERBOLT" },
      bench = { ability = "VOLT_ABSORB" },
      expected = 2,
    },
    {
      name = "absorb-water",
      high = true,
      enemy = { last = "SURF" },
      third = { ability = "WATER_ABSORB" },
      expected = 3,
    },
    {
      name = "absorb-fire",
      high = true,
      enemy = { last = "EMBER" },
      bench = { ability = "FLASH_FIRE" },
      expected = 2,
    },
    {
      name = "absorb-current-ability",
      high = true,
      enemy = { last = "THUNDERBOLT", ability = "VOLT_ABSORB" },
      bench = { ability = "VOLT_ABSORB" },
    },
    { name = "absorb-failed-roll", enemy = { last = "THUNDERBOLT" }, bench = { ability = "VOLT_ABSORB" } },
    {
      name = "absorb-super-suppression",
      high = true,
      enemy = { last = "THUNDERBOLT", moves = { "SOLARBEAM" } },
      player = { types = { "WATER" } },
      bench = { ability = "VOLT_ABSORB" },
    },
    {
      name = "natural-cure-first-roll",
      high = true,
      enemy = { status = "SLP", ability = "NATURAL_CURE" },
      expected = 2,
    },
    {
      name = "natural-cure-final-roll",
      rolls = { 0, 0, 1 },
      enemy = { status = "SLP", ability = "NATURAL_CURE" },
      expected = 2,
    },
    {
      name = "natural-cure-below-half",
      high = true,
      enemy = { hp = 199, status = "SLP", ability = "NATURAL_CURE" },
    },
    { name = "natural-cure-awake", high = true, enemy = { ability = "NATURAL_CURE" } },
    {
      name = "immune-counter",
      enemy = { last = "DIG", hitBy = 0 },
      player = { types = { "ELECTRIC" } },
      bench = { types = { "FLYING" }, moves = { "DIG" } },
      expected = 2,
    },
    {
      name = "immune-counter-failed-roll",
      high = true,
      enemy = { last = "DIG", hitBy = 0 },
      player = { types = { "ELECTRIC" } },
      bench = { types = { "FLYING" }, moves = { "DIG" } },
    },
    {
      name = "levitate-counter",
      enemy = { last = "DIG", hitBy = 0 },
      player = { types = { "ELECTRIC" } },
      bench = { ability = "LEVITATE", moves = { "DIG" } },
      expected = 2,
    },
    {
      name = "resist-counter",
      enemy = { last = "SURF", hitBy = 0 },
      player = { types = { "WATER" } },
      bench = { types = { "GRASS" }, moves = { "SOLARBEAM" } },
      expected = 2,
    },
    {
      name = "counter-no-attacker",
      enemy = { last = "SURF" },
      player = { types = { "WATER" } },
      bench = { types = { "GRASS" }, moves = { "SOLARBEAM" } },
    },
    {
      name = "counter-raised-stats",
      enemy = { last = "SURF", hitBy = 0, stages = { attack = 4 } },
      player = { types = { "WATER" } },
      bench = { types = { "GRASS" }, moves = { "SOLARBEAM" } },
    },
    {
      name = "counter-positive-stages-only",
      enemy = { last = "SURF", hitBy = 0, stages = { attack = 4, defense = -6 } },
      player = { types = { "WATER" } },
      bench = { types = { "GRASS" }, moves = { "SOLARBEAM" } },
    },
    {
      name = "counter-super-keeps-active",
      high = true,
      enemy = { last = "SURF", hitBy = 0, moves = { "SOLARBEAM" } },
      player = { types = { "WATER" } },
      bench = { types = { "GRASS" }, moves = { "SOLARBEAM" } },
    },
    { name = "double-right-perish", double = true, id = 3, bench = { perish = 0 }, expected = 3 },
  }
  for _, spec in ipairs(specs) do
    local b, trace = setup(spec)
    local action = f.query(spec.id)
    local index = action and (action.slot or action.index)
    T.eq(index or false, spec.expected or false, spec.name .. " native selection")
    local rng = copy(trace)
    if action then
      f.execute(action, spec.id)
    end
    rows[#rows + 1] = {
      mode = "switch-policy",
      name = spec.name,
      index = index or false,
      after = f.mon(spec.id).nickname,
      rng = rng,
    }
  end
  do
    local b, trace = setup({ double = true, enemy = { perish = 0 }, bench = { perish = 0 } })
    local first, second = f.query(1), f.query(3)
    T.eq(first and (first.slot or first.index), 3, "first double decision reserves the only bench slot")
    T.eq(second, nil, "partner cannot reserve the same incoming Pokemon")
    rows[#rows + 1] = {
      mode = "double-switch-reservation",
      first = first and (first.slot or first.index),
      second = f.kind(second),
      rng = trace,
    }
  end
  for _, mode in ipairs({ "landed", "substitute", "semi-invulnerable", "type-immune" }) do
    local spec = {
      enemy = { types = mode == "type-immune" and { "GROUND" } or { "NORMAL" } },
      player = { types = { "WATER" }, moves = { "SURF" } },
      bench = { types = { "GRASS" }, moves = { "SOLARBEAM" } },
    }
    local b = setup(spec)
    local user, target = battler(b, 0), battler(b, 1)
    local name = mode == "type-immune" and "THUNDERBOLT" or "SURF"
    if mode == "substitute" then
      target.substituteHP = 200
    end
    if mode == "semi-invulnerable" then
      if backend == "gen1" then
        target.semiInvulnerable = "ON_AIR"
      else
        target.invulnerable = true
      end
    end
    if backend == "gen1" then
      require("src.core.game3.battle.engine").resolveMove(
        user,
        target,
        moveIds[name],
        nil,
        require("src.core.game3.battle.adapter").new(b),
        b,
        {},
        {}
      )
    else
      b:performMove(user, target, { id = moveIds[name], pp = 10 })
    end
    local last = backend == "gen1" and target.expLastLandedMove or target._gbaLastLandedMove
    local attacker = backend == "gen1" and target.expLastHitById or target._gbaLastHitById
    local hit = mode == "landed" or mode == "substitute"
    T.eq(last or false, hit and moveIds[name] or false, "real move history: " .. mode)
    T.eq(attacker == 0, mode == "landed", "real HP hit owns the attacker history: " .. mode)
    local action = f.query()
    local index = action and (action.slot or action.index)
    T.eq(index or false, mode == "landed" and 2 or false, "automatic decision follows real move: " .. mode)
    rows[#rows + 1] = {
      mode = "move-history",
      name = mode,
      last = hit and name or false,
      attacker = attacker or false,
      index = index or false,
    }
  end
  return rows
end
return run
