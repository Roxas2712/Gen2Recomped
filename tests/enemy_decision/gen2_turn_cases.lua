-- Ordinary Gen-2 native turns, using the same public decision consumer.
return function(f, backend, imported)
  local T, native, copy = f.T, backend == "gen1", require("src.mods.Merge").deepCopy
  local rows = {}
  if imported then
    rows[#rows + 1] = {
      mode = "gen2-fresh-import",
      attributes = copy(imported.attributes),
      items = copy(imported.items),
    }
  end
  local events, ended = {}, 0
  local stops = {
    f.e.api.events:on("battle.turn_started", function(e)
      events[#events + 1] = { kind = "start", turn = e.turn }
    end),
    f.e.api.events:on("battle.turn_ended", function(e)
      ended = ended + 1
      events[#events + 1] = { kind = "end", turn = e.turn }
    end),
    f.e.api.events:on("battle.move_used", function(e)
      local user = e.user and (e.user.mon or e.user)
      local target = e.target and (e.target.mon or e.target)
      events[#events + 1] = {
        kind = "move",
        user = user and user.nickname,
        target = target and target.nickname,
        hp = target and target.hp,
      }
    end),
  }
  for _, spec in ipairs({
    { name = "single-native-heal", stock = { "POTION" }, turns = 1 },
    { name = "stock-exhausted-next-turn", stock = { "POTION" }, turns = 2 },
    { name = "two-native-heals", stock = { "FULL_RESTORE", "FULL_RESTORE" }, turns = 3, lowEach = true },
    { name = "suppressed-native-heal", stock = { "POTION" }, mode = "suppress", turns = 1 },
    { name = "repeated-native-heal", stock = { "POTION" }, mode = "repeat", turns = 1 },
    { name = "failure-keeps-native-heal", stock = { "POTION" }, mode = "fail-after", turns = 1 },
    { name = "lower-level-refuses-item", stock = { "POTION" }, lowerLevel = true, turns = 1 },
    { name = "above-half-refuses-item", stock = { "POTION" }, hp = 201, turns = 1 },
    { name = "missing-attributes-refuses-native-item", stock = { "POTION" }, noAttrs = true, turns = 1 },
  }) do
    local stock = {}
    local requested = imported and spec.name == "two-native-heals" and imported.items or spec.stock
    for _, id in ipairs(requested) do
      stock[#stock + 1] = f.item(id)
    end
    local b = f.freshDecision(copy(stock))
    local sourceAttrs = imported and imported.attributes or { 14, 14, 25, 211, 3, 68, 0 }
    b.trainer.attributes = copy(sourceAttrs)
    if spec.noAttrs then
      b.trainer.attributes = nil
    end
    local function mon(who)
      return native and who or who.mon
    end
    local function stats(who)
      local m = mon(who)
      m.level, m.hp = 30, 400
      m.stats = {
        hp = 400,
        attack = 50,
        defense = 50,
        speed = 50,
        special = 50,
        spatk = 50,
        spdef = 50,
        specialAttack = 50,
        specialDefense = 50,
      }
      m.maxHp = 400
      if not native then
        who.curStats = m.stats
      end
    end
    stats(b.player)
    stats(b.enemy)
    mon(b.player).nickname = "PLAYER"
    for _, candidate in ipairs(b.enemyParty) do
      candidate.level = spec.lowerLevel and candidate ~= mon(b.enemy) and 31 or 30
    end
    if spec.lowerLevel then
      mon(b.enemy).level = 29
    end
    mon(b.enemy).hp = spec.hp or 100
    f.e.state.mode = spec.mode or "delegate"
    for turn = 1, spec.turns do
      if spec.lowEach and #b.trainer.items > 0 then
        mon(b.enemy).hp = 1
      end
      events, ended = {}, 0
      local calls = f.e.state.calls
      if native then
        b:takeTurn({ kind = "move", move = "TACKLE" })
      else
        b.phase, b.queue, b.afterQueue = "menu", {}, "menu"
        b:resolveTurn(b.player.curMoves[1])
        f.game.input.wasPressed = function(_, key)
          return key == "a"
        end
        f.game.input.isDown = function(_, key)
          return key == "a"
        end
        local count = 0
        while b:updateQueue() do
          count = count + 1
          assert(count < 15000, "Gen-2 turn queue did not settle")
        end
      end
      T.eq(f.e.state.calls - calls, 1, "one public query in actual Gen-2 turn")
      T.eq(ended, 1, "one native Gen-2 turn ends")
      rows[#rows + 1] = {
        mode = "gen2-native-controller",
        name = spec.name,
        turn = turn,
        events = copy(events),
        player = { hp = mon(b.player).hp },
        enemy = { hp = mon(b.enemy).hp, name = mon(b.enemy).nickname },
        stock = #b.trainer.items,
      }
    end
  end
  for _, stop in ipairs(stops) do
    stop()
  end
  return rows
end
