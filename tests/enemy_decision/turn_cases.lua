-- Real GBA controller startup/update on the reference; real trainer
-- construction, turn planning and presentation-queue processing on the host.
local function run(f, root, backend, selectedSpecs)
  local T, rows = f.T, {}
  local copy = require("src.mods.Merge").deepCopy
  local B, trainers, oldTrainers
  if backend == "gen1" then
    B = require("src.core.game3.battle")
    require("src.core.game3.battle.mod_registries").bind(f.data)
    trainers = require("src.core.game3.scripting.trainers")
    oldTrainers = trainers._pack
  end
  local oldChart
  if not B then
    -- Match the reference's native chart for the extra victim types used by
    -- the escape-blocker cases; the small host fixture starts neutral-only.
    oldChart = f.data.type_chart
    f.data.type_chart = copy(oldChart)
    for _, row in ipairs({ { "GHOST", 0 }, { "STEEL", 5 } }) do
      f.data.type_chart.matchups[#f.data.type_chart.matchups + 1] =
        { attacker = "NORMAL", defender = row[1], multiplier = row[2] }
    end
    require("src.battle.TypeChart").load(f.data)
  end
  local function battler(b, id)
    return backend == "gen1" and require("src.core.game3.battle.state").battler(b, id) or b:battlerAt(id)
  end
  local function item(index)
    return backend == "gen1" and index or ("ITEM_%03d"):format(index)
  end
  if backend == "gen1" then
    local Moves = require("src.core.game3.battle.moves")
    Moves._rom[165] =
      { effect = 48, power = 50, type = 0, accuracy = 100, pp = 1, target = 0, priority = 0, flags = 51 }
    f.data.gen3Pokemon._moveNames[165] = "STRUGGLE"
    require("src.core.game3.pokemon")._romMoveNames[165] = "STRUGGLE"
    require("src.core.game3.items_data")._byId[300] =
      { name = "X TONIC", pocket = "ITEMS", effect = { 1, 0, 0, 0, 0, 0 } }
  else
    f.data.items.ITEM_300 = { id = "ITEM_300", index = 300, name = "X TONIC", price = 100 }
    f.data.constants.gen3ItemEffects.ITEM_300 = { bytes = { 1, 0, 0, 0, 0, 0 } }
  end
  local ended, events = 0, {}
  local stops = {
    f.e.api.events:on("battle.turn_started", function(e)
      events[#events + 1] = { kind = "start", turn = e.turn }
    end),
    f.e.api.events:on("battle.turn_ended", function(e)
      ended = ended + 1
      events[#events + 1] = { kind = "end", turn = e.turn }
      if B then
        B._auto = false
      end
    end),
    f.e.api.events:on("battle.move_used", function(e)
      local user, target = e.user and e.user.mon, e.target and e.target.mon
      events[#events + 1] = {
        kind = "move",
        user = user and (user.nickname or user.name),
        target = target and (target.nickname or target.name),
        hp = target and target.hp,
      }
    end),
    f.e.api.events:on("battle.battler_switched", function(e)
      local mon = e.battler and e.battler.mon
      events[#events + 1] = { kind = "switch", name = mon and (mon.nickname or mon.name) }
    end),
  }
  local function fresh(spec)
    local stock = spec.stock or { item(spec.x and 300 or 13) }
    local seed = f.freshDecision(stock, spec.double)
    local b
    if B then
      local pack =
        require("src.import.LuaWriter").encode({ moves = copy(require("src.core.game3.battle.moves")._rom) })
      local cache = {
        read = function(_, path)
          if path:match("battle_moves.lua$") then
            return pack
          end
        end,
      }
      trainers._pack = {
        trainers = {
          [0] = { name = "FOE", class = 0, pic = 0, party = {} },
          [1] = { name = "FOE", class = 0, pic = 0, party = {} },
        },
        classNames = { [0] = "FOE" },
      }
      T.eq(
        B.start({
          cache = cache,
          headless = true,
          autoFight = false,
          playerParty = copy(seed.playerParty),
          foeParty = copy(seed.foeParty),
          foe = { name = "FOE", party = copy(seed.foeParty) },
          trainerId = 1,
          trainerItems = stock,
          double = spec.double,
          rng = function(lo)
            return lo or 0
          end,
        }),
        true,
        "actual native GBA controller starts"
      )
      b = B.getState()
    else
      local party = {}
      for _, mon in ipairs(seed.enemyParty) do
        party[#party + 1] = { prebuilt = copy(mon) }
      end
      f.game.save.party = { copy(seed.player.mon) }
      if spec.double then
        f.game.save.party[2] = copy(seed:battlerAt(2).mon)
      end
      f.data.trainers.PORTABLE_CONTROLLER = {
        name = "FOE",
        parties = { party },
        items = stock,
        doubleBattle = spec.double,
        attributes = { 0, 0, 0, 0, 0, 0, 0 },
      }
      b = require("src.battle.BattleState").newTrainer(f.game, "PORTABLE_CONTROLLER", 1)
      b:syncSides()
      b.queue, b.phase, b.afterQueue, b.introSlide = {}, "menu", "menu", 0
      f.game.stack.states = { b }
      f.game.input.wasPressed = function(_, key)
        return key == "a"
      end
      f.game.input.isDown = function(_, key)
        return key == "a"
      end
      b.rng = function(lo)
        return lo or 0
      end
    end
    f.battle = b
    if spec.class then
      if B then
        b.aiClass = "PORTABLE_NATIVE_CLASS"
      else
        b.trainer.aiClass = "PORTABLE_NATIVE_CLASS"
      end
    end
    -- These are explicit session stats, equal on both engines. The small
    -- SDK fixtures otherwise seed different species base-stat templates.
    local function commonStats(mon)
      if B then
        mon.maxHp, mon.attack, mon.defense, mon.speed, mon.spAtk, mon.spDef = 400, 50, 50, 50, 50, 50
        mon.pp = {}
        for i in ipairs(mon.moves or {}) do
          mon.pp[i] = 10
        end
      else
        mon.stats = { hp = 400, attack = 50, defense = 50, speed = 50, special = 50, spatk = 50, spdef = 50 }
        for _, move in ipairs(mon.moves or {}) do
          move.pp = 10
        end
      end
    end
    if spec.brain then
      if B then
        b.aiClass = "PORTABLE_NATIVE_BRAIN"
      else
        b.trainer.aiClass = "PORTABLE_NATIVE_BRAIN"
      end
      for _, id in ipairs(spec.double and { 1, 3 } or { 1 }) do
        local who = battler(b, id)
        if B then
          who.mon.moves[2] = 33
        else
          who.curMoves[2] = { id = f.ids.TACKLE, pp = 10 }
        end
      end
      f.e.brain.calls, f.e.brain.seen = 0, {}
      f.e.brain.mode, f.e.brain.pick = spec.brainMode or "pick", 2
    end
    for _, mon in ipairs(B and b.foeParty or b.enemyParty) do
      commonStats(mon)
    end
    for id = 0, spec.double and 3 or 1 do
      local who = battler(b, id)
      commonStats(who.mon)
      if not B then
        who.curStats = who.mon.stats
      end
    end
    local left = battler(b, 1)
    if spec.fast then
      if B then
        b.player.mon.speed = 80
      else
        b.player.curStats.speed = 80
      end
    end
    left.mon.hp = spec.hp or 200
    if not B then
      left.shownHP = left.mon.hp
    end
    if spec.age then
      if B then
        left.isFirstTurn = spec.age
      else
        left.turnsOut = 2 - spec.age
      end
    end
    if spec.double then
      local right = battler(b, 3)
      right.mon.hp = spec.hp or 200
      if not B then
        right.shownHP = right.mon.hp
      end
      if spec.age then
        if B then
          right.isFirstTurn = spec.age
        else
          right.turnsOut = 2 - spec.age
        end
      end
      if spec.x or spec.changes or spec.clear then
        (B and b.foeParty or b.enemyParty)[3].hp = 0
      end
    end
    if spec.perish then
      if B then
        left.perishSong, left.expPerishTurns = true, 0
      else
        left.perishTurns = 0
      end
    end
    if spec.brainZeroSecond then
      if B then
        left.mon.pp[2] = 0
      else
        left.curMoves[2].pp = 0
      end
      f.e.brain.mode = "first-usable"
    end
    if spec.encore then
      if B then
        left.expEncoreTurns, left.expEncoreMove = 2, 33
      else
        left.encoreTurns, left.encoreMove = 2, f.ids.TACKLE
      end
    end
    if spec.sleep then
      left.mon.status = "SLP"
      if not B then
        left.shownStatus = "SLP"
      end
    end
    if spec.freeze then
      left.mon.status = "FRZ"
    end
    if spec.escapePrevention then
      left.escapePrevention = true
    end
    if spec.blocker then
      if B then
        b.player.ability = spec.blocker
      else
        b.player.abilityOverride = spec.blocker
      end
    end
    if spec.victimAbility then
      if B then
        left.ability = spec.victimAbility
      else
        left.abilityOverride = spec.victimAbility
      end
    end
    if spec.victimType then
      if B then
        local types = { NORMAL = 0, FLYING = 2, GHOST = 7, STEEL = 8 }
        left.type1, left.type2 = types[spec.victimType], types[spec.victimType]
      else
        left.curTypes = { spec.victimType }
      end
    end
    if spec.trapped then
      if B then
        left.expTrapped = true
      else
        left.trapped = true
      end
    end
    if spec.mutateStock then
      (B and b.trainerItems or b.trainer.items)[1] = item(300)
    end
    events, ended = {}, 0
    f.e.state.calls, f.e.state.contexts = 0, {}
    f.e.state.mode = spec.mode or "delegate"
    f.e.state.decision = spec.decision
    f.e.state.changes, f.e.state.clear = spec.changes, spec.clear
    return b
  end
  local function turn(b)
    local before = ended
    if B then
      B._auto = true
      for _ = 1, 1000 do
        B.update(0, nil)
        if ended > before or b.over then
          break
        end
      end
    else
      if b:isDouble() then
        b.pendingActions = { [0] = b.player.curMoves[1], [2] = b:battlerAt(2).curMoves[1] }
      end
      b:resolveTurn(b.player.curMoves[1])
      local count = 0
      while b:updateQueue() do
        count = count + 1
        assert(count < 15000, "host native turn queue did not settle")
      end
    end
    if not (b.over or b.result) then
      T.eq(ended, before + 1, "one complete native controller turn")
    end
  end
  local specs = {
    { name = "delegated-run-freeze", mode = "mutate-fields", freeze = true, changes = { kind = "run" } },
    {
      name = "delegated-run-escape-prevention",
      mode = "mutate-fields",
      escapePrevention = true,
      changes = { kind = "run" },
    },
    {
      name = "delegated-run-shadow-tag",
      mode = "mutate-fields",
      blocker = "SHADOW_TAG",
      changes = { kind = "run" },
    },
    {
      name = "delegated-run-own-shadow-tag-still-blocked",
      mode = "mutate-fields",
      blocker = "SHADOW_TAG",
      victimAbility = "SHADOW_TAG",
      changes = { kind = "run" },
    },
    {
      name = "delegated-run-ghost-still-blocked",
      mode = "mutate-fields",
      blocker = "SHADOW_TAG",
      victimType = "GHOST",
      changes = { kind = "run" },
    },
    {
      name = "delegated-run-arena-grounded",
      mode = "mutate-fields",
      blocker = "ARENA_TRAP",
      changes = { kind = "run" },
    },
    {
      name = "delegated-run-arena-flying",
      mode = "mutate-fields",
      blocker = "ARENA_TRAP",
      victimType = "FLYING",
      changes = { kind = "run" },
    },
    {
      name = "delegated-run-arena-levitate",
      mode = "mutate-fields",
      blocker = "ARENA_TRAP",
      victimAbility = "LEVITATE",
      changes = { kind = "run" },
    },
    {
      name = "delegated-run-magnet-steel",
      mode = "mutate-fields",
      blocker = "MAGNET_PULL",
      victimType = "STEEL",
      changes = { kind = "run" },
    },
    {
      name = "delegated-run-magnet-other",
      mode = "mutate-fields",
      blocker = "MAGNET_PULL",
      victimType = "NORMAL",
      changes = { kind = "run" },
    },
    { name = "delegated-run-claimed", mode = "mutate-claim", changes = { kind = "run" } },
    {
      name = "delegated-meta-watch-move-single",
      mode = "mutate-fields",
      changes = { kind = "watch", move = 33, slot = 1, target = "player", meta = true },
    },
    {
      name = "delegated-done-forfeit-double",
      mode = "mutate-fields",
      double = true,
      stock = { item(13), item(13) },
      changes = { kind = "run", forfeit = true, done = true },
    },
    {
      name = "delegated-false-control-flags-double",
      mode = "mutate-fields",
      double = true,
      stock = { item(13), item(13) },
      changes = { done = false, finished = false, meta = true },
    },
    { name = "delegated-run-single", mode = "mutate-fields", changes = { kind = "run" } },
    {
      name = "delegated-run-fast-player",
      mode = "mutate-fields",
      fast = true,
      changes = { kind = "run" },
      skipHealAssertion = true,
    },
    { name = "delegated-run-sleep", mode = "mutate-fields", sleep = true, changes = { kind = "run" } },
    { name = "delegated-run-trapped", mode = "mutate-fields", trapped = true, changes = { kind = "run" } },
    {
      name = "delegated-run-double",
      mode = "mutate-fields",
      double = true,
      stock = { item(13), item(13) },
      changes = { kind = "run" },
    },
    {
      name = "delegated-watch-single",
      mode = "mutate-fields",
      changes = { kind = "watch" },
      clear = { "target" },
    },
    {
      name = "delegated-watch-double",
      mode = "mutate-fields",
      double = true,
      stock = { item(13), item(13) },
      changes = { kind = "watch" },
      clear = { "target" },
    },
    {
      name = "delegated-watch-move-single",
      mode = "mutate-fields",
      changes = { kind = "watch", move = 33, slot = 1, target = "player" },
    },
    {
      name = "delegated-watch-player-move-single",
      mode = "mutate-fields",
      changes = { kind = "watch", move = 33, slot = 1, user = "player", target = "enemy" },
    },
    {
      name = "delegated-watch-move-double",
      mode = "mutate-fields",
      double = true,
      stock = { item(13), item(13) },
      changes = { kind = "watch", move = 33, slot = 1, target = 0 },
    },
    { name = "delegated-done-item-single", mode = "mutate-fields", changes = { done = true } },
    {
      name = "delegated-done-item-double",
      mode = "mutate-fields",
      double = true,
      stock = { item(13), item(13) },
      changes = { done = true },
    },
    {
      name = "delegated-finished-item-double",
      mode = "mutate-fields",
      double = true,
      stock = { item(13), item(13) },
      changes = { finished = true },
    },
    {
      name = "delegated-done-move-single",
      mode = "mutate-fields",
      changes = { kind = "move", move = 33, slot = 1, done = true },
    },
    {
      name = "delegated-done-move-double",
      mode = "mutate-fields",
      double = true,
      stock = { item(13), item(13) },
      changes = { kind = "move", move = 33, slot = 1, done = true },
    },
    { name = "delegated-forfeit-single", mode = "mutate-fields", changes = { kind = "run", forfeit = true } },
    {
      name = "delegated-forfeit-double",
      mode = "mutate-fields",
      double = true,
      stock = { item(13), item(13) },
      changes = { kind = "run", forfeit = true },
    },
    { name = "delegated-meta-item-single", mode = "mutate-fields", changes = { meta = true } },
    {
      name = "delegated-meta-item-double",
      mode = "mutate-fields",
      double = true,
      stock = { item(13), item(13) },
      changes = { meta = true },
    },
    {
      name = "delegated-meta-move-single",
      mode = "mutate-fields",
      changes = { kind = "move", move = 33, slot = 1, meta = true },
    },
    {
      name = "delegated-meta-move-double",
      mode = "mutate-fields",
      double = true,
      stock = { item(13), item(13) },
      changes = { kind = "move", move = 33, slot = 1, meta = true },
    },
    { name = "delegated-user-item-single", mode = "mutate-fields", changes = { user = "player" } },
    {
      name = "delegated-user-item-double",
      mode = "mutate-fields",
      double = true,
      stock = { item(13), item(13) },
      changes = { user = "player" },
    },
    {
      name = "delegated-user-move-single",
      mode = "mutate-fields",
      changes = { kind = "move", move = 33, slot = 1, user = "player" },
    },
    {
      name = "delegated-user-move-double",
      mode = "mutate-fields",
      double = true,
      stock = { item(13), item(13) },
      changes = { kind = "move", move = 33, slot = 1, user = "player" },
    },
    {
      name = "delegated-move-double-unusable-target",
      mode = "mutate-fields",
      double = true,
      stock = { item(13), item(13) },
      changes = { kind = "move", move = 33, slot = 1, target = true },
    },
    {
      name = "delegated-move-double-selected-target",
      mode = "mutate-fields",
      double = true,
      stock = { item(13), item(13) },
      changes = { kind = "move", move = 33, slot = 1, target = 2 },
    },
    { name = "brain-second-slot-controller", brain = true, stock = {}, mode = "suppress" },
    {
      name = "brain-second-slots-double-controller",
      brain = true,
      stock = {},
      mode = "suppress",
      double = true,
    },
    { name = "brain-item-precedence-controller", brain = true, brainItem = true },
    { name = "native-item-precedes-encore-controller", encore = true },
    {
      name = "brain-zero-pp-controller",
      brain = true,
      brainZeroSecond = true,
      stock = {},
      mode = "suppress",
    },
    { name = "brain-error-controller", brain = true, brainMode = "error", stock = {}, mode = "suppress" },
    { name = "delegated-item-to-switch", mode = "mutate-fields", changes = { kind = "switch", slot = 2 } },
    {
      name = "delegated-item-to-switch-claimed",
      mode = "mutate-claim",
      changes = { kind = "switch", slot = 2 },
    },
    {
      name = "delegated-switch-slot",
      mode = "mutate-fields",
      perish = true,
      switchName = "THIRD",
      changes = { slot = 3 },
    },
    {
      name = "delegated-item-to-move",
      mode = "mutate-fields",
      changes = { kind = "move", move = 33, slot = 1, target = 0 },
    },
    { name = "delegated-unknown-single", mode = "mutate-fields", changes = { kind = "other" } },
    {
      name = "delegated-unknown-double",
      mode = "mutate-fields",
      double = true,
      stock = { item(13), item(13) },
      changes = { kind = "other" },
    },
    { name = "delegated-battler-single", mode = "mutate-fields", changes = { battler = 3 } },
    {
      name = "delegated-battler-double",
      mode = "mutate-fields",
      double = true,
      stock = { item(13), item(13) },
      changes = { battler = 3 },
    },
    {
      name = "delegated-missing-battler-double",
      mode = "mutate-fields",
      double = true,
      stock = { item(13), item(13) },
      clear = { "battler" },
    },
    { name = "delegated-item-target-single", mode = "mutate-fields", changes = { target = 0 } },
    {
      name = "delegated-item-target-double",
      mode = "mutate-fields",
      double = true,
      stock = { item(13), item(13) },
      changes = { target = 0 },
    },
    { name = "class-item-precedes-hook", class = true, mode = "suppress", fast = true },
    {
      name = "double-class-items-precede-hook",
      class = true,
      mode = "suppress",
      double = true,
      stock = { item(13), item(13) },
    },
    { name = "native-item-before-faster-player", fast = true },
    { name = "constructor-freezes-native-stock", mutateStock = true },
    { name = "native-heal-prevents-faint", hp = 1 },
    { name = "suppress-spends-no-item", mode = "suppress" },
    { name = "repeated-next-keeps-one-native-item", mode = "repeat" },
    { name = "post-next-failure-keeps-native-item", mode = "fail-after" },
    {
      name = "explicit-switch-refreshes-target",
      mode = "override",
      decision = { kind = "switch", index = 2 },
    },
    { name = "automatic-switch-refreshes-target", perish = true },
    {
      name = "double-shared-items-before-moves",
      double = true,
      mode = "override",
      stock = { item(13), item(13) },
      decision = { kind = "item", item = "POTION" },
    },
    { name = "double-x-initial-age", double = true, x = true, age = 2, stock = { item(300), item(300) } },
    { name = "double-x-last-first-age", double = true, x = true, age = 1, stock = { item(300), item(300) } },
    { name = "double-x-later-age", double = true, x = true, age = 0, stock = { item(300), item(300) } },
  }
  for _, spec in ipairs(selectedSpecs or specs) do
    local b = fresh(spec)
    turn(b)
    T.eq(f.e.state.calls, spec.class and 0 or spec.double and 2 or 1, spec.name .. " public query count")
    if spec.brain then
      T.eq(
        f.e.brain.calls,
        spec.brainItem and 0 or spec.double and 2 or 1,
        spec.name .. " native brain count"
      )
    end
    if spec.fast and not spec.skipHealAssertion or spec.mutateStock then
      local firstMove
      for _, event in ipairs(events) do
        if event.kind == "move" then
          firstMove = event
          break
        end
      end
      T.eq(firstMove and firstMove.hp, 220, spec.name .. " native item executes before attack")
    end
    if spec.name == "native-heal-prevents-faint" then
      T.eq(battler(b, 1).mon.nickname, "ENEMY", "native healing keeps original foe on the field")
      T.eq(battler(b, 1).mon.hp, 3, "native healing prevents the lethal hit")
    end
    if spec.perish or spec.decision and spec.decision.kind == "switch" then
      T.eq(battler(b, 1).mon.nickname, spec.switchName or "BENCH", "native switch changes the field occupant")
      T.eq(battler(b, 1).mon.hp, 382, "queued player move damages the incoming occupant")
    end
    if spec.x then
      local expected = spec.age ~= 0 and 1 or 0
      T.eq(battler(b, 1).stages.attack or 0, expected, "left foe uses native first-turn window")
      T.eq(battler(b, 3).stages.attack or 0, expected, "right foe uses same native first-turn window")
    end
    local expectedResults = {
      ["delegated-run-single"] = "fled",
      ["delegated-run-fast-player"] = "fled",
      ["delegated-run-claimed"] = "fled",
      ["delegated-run-arena-flying"] = "fled",
      ["delegated-run-arena-levitate"] = "fled",
      ["delegated-run-magnet-other"] = "fled",
      ["delegated-forfeit-single"] = "fled",
      ["delegated-forfeit-double"] = "forfeited",
    }
    T.eq(b.result, expectedResults[spec.name], spec.name .. " native terminal result")
    local out = {
      mode = "native-controller",
      name = spec.name,
      calls = f.e.state.calls,
      events = copy(events),
      stock = f.remainingStock(),
      party = {},
      brainCalls = spec.brain and f.e.brain.calls or nil,
      brainViews = spec.brain and copy(f.e.brain.seen) or nil,
      terminal = not not (b.over or b.result),
      result = b.result,
    }
    for id = 0, spec.double and 3 or 1 do
      local who = battler(b, id)
      local pp = {}
      for i in ipairs(who.mon.moves) do
        pp[i] = B and who.mon.pp[i] or who.curMoves[i].pp
      end
      out.party[#out.party + 1] = {
        name = who.mon.nickname,
        hp = who.mon.hp,
        attack = who.stages.attack or 0,
        pp = B and who.mon.pp[1] or who.curMoves[1].pp,
        allPP = pp,
      }
    end
    rows[#rows + 1] = out
    if B then
      B.reset()
    end
  end
  for _, gate in ipairs({ "wild", "pokedude", "oldman", "locked", "recharge", "trainer" }) do
    local b = f.freshDecision({ item(13) })
    if B then
      if gate == "wild" then
        b.wild = true
      end
      if gate == "pokedude" then
        b.pokedude = true
      end
      if gate == "oldman" then
        b.oldManTutorial = true
      end
      if gate == "locked" then
        b.enemy.expLockedMove = 33
      end
      if gate == "recharge" then
        b.enemy.expMustRecharge = true
      end
    else
      if gate == "wild" then
        b.kind = "wild"
      end
      if gate == "pokedude" then
        b.pokedudeDemo = { enemyMove = 1 }
      end
      if gate == "oldman" then
        b.demo = true
      end
      if gate == "locked" then
        b.enemy.charging, b.enemy.chargeReady = b.enemy.curMoves[1], true
      end
      if gate == "recharge" then
        b.enemy.mustRecharge = true
      end
    end
    f.e.state.mode = "delegate"
    local action
    if B then
      action = require("src.core.game3.battle.commands").enemyAction(b, 1)
    else
      action = b:enemyAction(b.enemy)
    end
    T.eq(action ~= nil, true, gate .. " controller still chooses its native action")
    T.eq(f.e.state.calls, gate == "trainer" and 1 or 0, gate .. " switch/item producer gate")
    rows[#rows + 1] =
      { mode = "native-command-gate", name = gate, calls = f.e.state.calls, action = action ~= nil }
  end
  for _, stop in ipairs(stops) do
    stop()
  end
  if trainers then
    trainers._pack = oldTrainers
    require("src.core.game3.battle.mod_registries").bind(nil)
  end
  if oldChart then
    f.data.type_chart = oldChart
    require("src.battle.TypeChart").load(f.data)
  end
  return rows
end
return run
