-- Real GBA controller startup/update on the reference; real trainer
-- construction, turn planning and presentation-queue processing on the host.
local function run(f, root, backend)
  local T, rows = f.T, {}
  local copy = require("src.mods.Merge").deepCopy
  local B, trainers, oldTrainers
  if backend == "gen1" then
    B = require("src.core.game3.battle")
    require("src.core.game3.battle.mod_registries").bind(f.data)
    trainers = require("src.core.game3.scripting.trainers")
    oldTrainers = trainers._pack
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
      if B then b.aiClass = "PORTABLE_NATIVE_CLASS"
      else b.trainer.aiClass = "PORTABLE_NATIVE_CLASS" end
    end
    -- These are explicit session stats, equal on both engines. The small
    -- SDK fixtures otherwise seed different species base-stat templates.
    local function commonStats(mon)
      if B then
        mon.maxHp, mon.attack, mon.defense, mon.speed, mon.spAtk, mon.spDef = 400, 50, 50, 50, 50, 50
      else
        mon.stats = { hp = 400, attack = 50, defense = 50, speed = 50, special = 50, spatk = 50, spdef = 50 }
      end
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
      if spec.x then
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
    if spec.mutateStock then
      (B and b.trainerItems or b.trainer.items)[1] = item(300)
    end
    events, ended = {}, 0
    f.e.state.calls, f.e.state.contexts = 0, {}
    f.e.state.mode = spec.mode or "delegate"
    f.e.state.decision = spec.decision
    return b
  end
  local function turn(b)
    local before = ended
    if B then
      B._auto = true
      for _ = 1, 1000 do
        B.update(0, nil)
        if ended > before then
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
    T.eq(ended, before + 1, "one complete native controller turn")
  end
  local specs = {
    { name = "class-item-precedes-hook", class = true, mode = "suppress", fast = true },
    { name = "double-class-items-precede-hook", class = true, mode = "suppress", double = true,
      stock = { item(13), item(13) } },
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
  for _, spec in ipairs(specs) do
    local b = fresh(spec)
    turn(b)
    T.eq(f.e.state.calls, spec.class and 0 or spec.double and 2 or 1, spec.name .. " public query count")
    if spec.fast or spec.mutateStock then
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
      T.eq(battler(b, 1).mon.nickname, "BENCH", "native switch changes the field occupant")
      T.eq(battler(b, 1).mon.hp, 382, "queued player move damages the incoming occupant")
    end
    if spec.x then
      local expected = spec.age ~= 0 and 1 or 0
      T.eq(battler(b, 1).stages.attack or 0, expected, "left foe uses native first-turn window")
      T.eq(battler(b, 3).stages.attack or 0, expected, "right foe uses same native first-turn window")
    end
    local out = {
      mode = "native-controller",
      name = spec.name,
      calls = f.e.state.calls,
      events = copy(events),
      party = {},
    }
    for id = 0, spec.double and 3 or 1 do
      local who = battler(b, id)
      out.party[#out.party + 1] =
        { name = who.mon.nickname, hp = who.mon.hp, attack = who.stages.attack or 0 }
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
  return rows
end
return run
