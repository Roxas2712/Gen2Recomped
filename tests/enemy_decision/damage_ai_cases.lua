-- Native AI damage queries composed with the unchanged public scoring callback.
return function(f, backend)
  local T, rows, native = f.T, {}, backend == "gen1"
  local State, AI, registry, oldPack
  if native then
    State = require("src.core.game3.battle.state")
    AI = require("src.core.game3.battle.ai")
    registry = require("src.core.game3.battle.mod_registries")
    oldPack = AI._pack
    registry.bind(f.data)
  else
    f.game.mods = f.result.loader
  end
  local copy = require("src.mods.Merge").deepCopy
  local oldChart = not native and f.data.type_chart
  if not native then
    f.data.type_chart = copy(oldChart)
    for _, row in ipairs({
      { "NORMAL", "GHOST", 0 },
      { "NORMAL", "STEEL", 5 },
      { "FIRE", "GRASS", 20 },
      { "WATER", "FIRE", 20 },
    }) do
      f.data.type_chart.matchups[#f.data.type_chart.matchups + 1] =
        { attacker = row[1], defender = row[2], multiplier = row[3] }
    end
    require("src.battle.TypeChart").load(f.data)
  end
  local specs = {}
  for _, opcode in ipairs({ "if_can_faint", "if_cant_faint", "get_how_powerful_move_is" }) do
    for _, hp in ipairs({ 1, 9, 10, 13, 14, 16, 17, 400 }) do
      specs[#specs + 1] = { name = opcode .. "-hp-" .. hp, opcode = opcode, hp = hp }
    end
    for _, spec in ipairs({
      { name = "inverted-rolls", rolls = { 15, 0, 7, 3 }, hp = 14 },
      { name = "equal-rolls", rolls = { 0, 0, 7, 3 }, hp = 14 },
      { name = "sparse-fourth-slot", sparse = true, hp = 14 },
      { name = "zero-pp-first", zeroPP = 1, hp = 14 },
      { name = "zero-pp-second", zeroPP = 2, hp = 14 },
      { name = "disabled-first", disabled = true, hp = 14 },
      { name = "two-native-scripts", twice = true, hp = 14 },
      { name = "without-mod-layers", noClass = true, hp = 14 },
      { name = "without-native-flags", noClass = true, noFlags = true, hp = 14 },
      { name = "status-power", power = 0, hp = 14 },
      { name = "one-power", power = 1, hp = 14 },
      { name = "no-stab", noStab = true, hp = 10 },
      { name = "type-immune", targetType = "GHOST", hp = 1 },
      { name = "resisted", targetType = "STEEL", hp = 7 },
      { name = "rain-fire", moveType = "FIRE", weather = "RAIN", hp = 7 },
      { name = "sun-water", moveType = "WATER", weather = "SUN", hp = 7 },
      { name = "sun-fire", moveType = "FIRE", weather = "SUN", hp = 13 },
      { name = "burned", burn = true, hp = 7 },
      { name = "stage-up", stage = 1, hp = 22 },
      { name = "minimum-base", level = 1, power = 2, hp = 3 },
      { name = "large-attack", attack = 300, defense = 50, hp = 90 },
      { name = "large-defense", attack = 255, defense = 257, hp = 14 },
      { name = "large-damage", attack = 500, defense = 10, power = 250, hp = 400 },

      { name = "double-left", double = true, hp = 14 },
      { name = "double-right", double = true, id = 3, hp = 14 },
    }) do
      spec = copy(spec)
      spec.name, spec.opcode = opcode .. "-" .. spec.name, opcode
      specs[#specs + 1] = spec
    end
  end
  local effects = { 7, 8, 39, 75, 80, 145, 151, 161, 170, 186, 187, 204 }
  local types = { NORMAL = 0, GHOST = 7, STEEL = 8, FIRE = 10, WATER = 11, GRASS = 12 }
  for _, spec in ipairs(specs) do
    local b = f.freshDecision({}, spec.double)
    local id = spec.id or 1
    local function at(index)
      return native and State.battler(b, index) or b:battlerAt(index)
    end
    local who = at(id)
    local oldProgram = f.data.constants.gen3BattleAI
    local originalDefs = {}
    for _, name in ipairs({ "TACKLE", "FLY" }) do
      local def = native and require("src.core.game3.battle.moves")._rom[name == "TACKLE" and 33 or 19]
        or f.data.moves[f.ids[name]]
      originalDefs[#originalDefs + 1] =
        { def = def, power = def.power, type = def.type, category = def.category }
      def.power = spec.power or 35
      def.type = native and types[spec.moveType or "NORMAL"] or spec.moveType or "NORMAL"
      if not native then
        def.category = (spec.moveType == "FIRE" or spec.moveType == "WATER") and "special" or "physical"
      end
    end
    for index = 0, spec.double and 3 or 1 do
      local battler = at(index)
      local mon = battler.mon
      mon.level, mon.hp, mon.maxHp = spec.level or 30, index % 2 == 0 and (spec.hp or 14) or 400, 400
      if native then
        mon.attack, mon.defense, mon.speed, mon.spAtk, mon.spDef, mon.ability =
          spec.attack or 50, spec.defense or 50, 50, spec.attack or 50, spec.defense or 50, 0
        battler.ability, battler.stages.attack = 0, index == id and (spec.stage or 0) or 0
        local kind = index % 2 == 0 and (spec.targetType or "NORMAL") or spec.noStab and "FIRE" or "NORMAL"
        battler.type1, battler.type2 = types[kind], types[kind]
      else
        mon.stats = {
          hp = 400,
          attack = spec.attack or 50,
          defense = spec.defense or 50,
          speed = 50,
          special = spec.attack or 50,
          spatk = spec.attack or 50,
          spdef = spec.defense or 50,
        }
        mon.ability, battler.ability, battler.curStats = nil, nil, mon.stats
        battler.stages.attack = index == id and (spec.stage or 0) or 0
        battler.curTypes =
          { index % 2 == 0 and (spec.targetType or "NORMAL") or spec.noStab and "FIRE" or "NORMAL" }
      end
    end
    T.eq(
      native and who.mon.attack or who.curStats.attack,
      spec.attack or 50,
      spec.name .. " matched attack input"
    )
    T.eq(
      native and at(0).mon.defense or at(0).curStats.defense,
      spec.defense or 50,
      spec.name .. " matched defense input"
    )
    local powerful = spec.opcode == "get_how_powerful_move_is"
    if native then
      who.mon.moves, who.mon.pp = { 33, 19 }, { 10, 10 }
      if spec.sparse then
        who.mon.moves, who.mon.pp = { 33, 0, 0, 19 }, { 10, 0, 0, 10 }
      end
      if spec.zeroPP then
        who.mon.pp[spec.zeroPP] = 0
      end
      if spec.disabled then
        who.expDisabledMove = 33
      end
      if spec.burn then
        who.mon.status = "BRN"
      end
      b.aiClass, b.aiFlags, b.weather =
        not spec.noClass and "PORTABLE_SCORE_A" or nil,
        spec.noFlags and 0 or spec.twice and 3 or 1,
        spec.weather
      local main = powerful
          and {
            { op = "get_how_powerful_move_is" },
            { op = "if_equal", value = 2, target = "bonus" },
            { op = "end" },
          }
        or { { op = spec.opcode, target = "bonus" }, { op = "end" } }
      AI._pack = {
        table = { "main", "main" },
        scripts = { main = main, bonus = { { op = "score", delta = 20 }, { op = "end" } } },
      }
    else
      who.curMoves = { { id = f.ids.TACKLE, pp = 10 }, { id = f.ids.FLY, pp = 10 } }
      if spec.sparse then
        who.curMoves = { who.curMoves[1], { id = 0, pp = 0 }, { id = 0, pp = 0 }, who.curMoves[2] }
      end
      who.mon.moves = who.curMoves
      if spec.zeroPP then
        who.curMoves[spec.zeroPP].pp = 0
      end
      if spec.disabled then
        who.disabledSlot = 1
      end
      if spec.burn then
        who.mon.status = "BRN"
      end
      b.trainer.aiClass, b.trainer.aiFlags, b.weather =
        not spec.noClass and "PORTABLE_SCORE_A" or nil,
        spec.noFlags and 0 or spec.twice and 3 or 1,
        spec.weather
      local code = powerful
          and {
            { name = "get_how_powerful_move_is", args = {}, next = 2 },
            { name = "if_equal", args = { 2, 4 }, next = 3 },
            { name = "end", args = {} },
            { name = "score", args = { 20 }, next = 5 },
            { name = "end", args = {} },
          }
        or {
          { name = spec.opcode, args = { 3 }, next = 2 },
          { name = "end", args = {} },
          { name = "score", args = { 20 }, next = 4 },
          { name = "end", args = {} },
        }
      f.data.constants.gen3BattleAI = { entries = { [0] = 1, [1] = 1 }, code = code, discouraged = effects }
    end
    local draws, simulation = {}, 0
    b.rng = function(lo, hi)
      draws[#draws + 1] = { lo, hi }
      if hi == 15 then
        simulation = simulation + 1
        return (spec.rolls or { 0, 15, 7, 15 })[(simulation - 1) % 4 + 1]
      end
      return lo or 0
    end
    f.e.scoring.calls, f.e.scoring.mode = {}, "nil"
    f.e.state.mode = "suppress"
    local ok, action = pcall(function()
      return native and require("src.core.game3.battle.commands").enemyAction(b, id) or b:enemyAction(who)
    end)
    T.eq(ok, true, spec.name .. " native controller completes")
    local slot, target
    if native then
      slot, target = action and action.slot, action and action.target
    else
      for i, move in ipairs(who.curMoves) do
        if action == move then
          slot = i
        end
      end
      local selected = b.chosenTargets and b.chosenTargets[id]
      if selected then
        for i = 0, 3 do
          if selected == at(i) then
            target = i
          end
        end
      end
    end
    T.check(slot ~= nil, spec.name .. " returns a native move slot")
    T.eq(who.mon.hp, 400, spec.name .. " does not execute estimated damage")
    local controllerDraws = copy(draws)
    local estimates = {}
    if spec.power == nil or spec.power > 1 then
      local simulated = {}
      for i, roll in ipairs(spec.rolls or { 0, 15, 7, 15 }) do
        simulated[i] = 100 - roll
      end
      local vm =
        { battle = b, st = b, user = who, target = at(0), moves = who.curMoves, simulatedRNG = simulated }
      for _, slot in ipairs({ 1, spec.sparse and 4 or 2 }) do
        estimates[#estimates + 1] = native
            and require("src.core.game3.battle.ai_cmds").ai_damage(vm, slot == 1 and 33 or 19, slot)
          or require("src.battle.Gen3AI").estimate(vm, slot)
      end
    end
    rows[#rows + 1] = {
      damageAI = spec.name,
      estimates = estimates,
      slot = slot or false,
      target = target or false,
      calls = f.e.scoring.calls,
      rng = controllerDraws,
    }
    for _, row in ipairs(originalDefs) do
      row.def.power, row.def.type, row.def.category = row.power, row.type, row.category
    end
    f.data.constants.gen3BattleAI = oldProgram
  end
  if native then
    AI._pack = oldPack
    registry.bind(nil)
  else
    f.data.type_chart = oldChart
    require("src.battle.TypeChart").load(f.data)
  end
  return rows
end
