local C = {}
function C.run(root, backend, version, api, format, inspect)
  local f = dofile(root .. "/tests/enemy_decision/fixture.lua").new(root, backend, version, api, format)
  local T, rows = f.T, {}
  if inspect then
    inspect(f)
  end
  if f.gen ~= 2 and f.gen ~= 3 then
    T.eq(f.e.available, false, "no invented GB producer")
    f.close()
    return { { available = false } }
  end
  T.eq(f.e.available, true, "native producer advertised")
  local out = f.e.state
  for _, mode in ipairs({
    "override",
    "suppress",
    "nil",
    "true",
    "delegate",
    "repeat",
    "claim",
    "fail-before",
    "fail-after",
  }) do
    local b = f.freshDecision({ f.item("POTION") })
    local mon = f.mon()
    mon.hp = 1
    out.mode, out.decision = mode, { kind = "item", item = "POTION" }
    local action = f.query()
    local spent = f.gen == 2 and action or f.kind(action)
    local before = f.mon().hp
    if f.gen == 3 then
      f.execute(action)
    end
    rows[#rows + 1] = { mode = mode, spent = spent, before = before, after = f.mon().hp, stock = f.used() }
    T.eq(out.calls, 1, "one public decision per native query")
    T.eq(out.contexts[1], b, "native battle handle remains exact")
    if mode == "override" then
      T.eq(f.mon().hp, 21, "explicit public Potion heals through native handler")
      T.eq(before, f.gen == 2 and 21 or 1, "generation-specific execution phase")
    end
    if mode == "suppress" or mode == "nil" then
      T.eq(f.mon().hp, 1, "suppression cannot heal")
      T.eq(f.used(), f.gen == 2 and 1 or false, "suppression cannot consume stock")
    end
  end
  for _, decision in ipairs({
    { kind = "switch", index = 2 },
    { kind = "switch", index = 1 },
    { kind = "switch", index = 9 },
    { kind = "other" },
    { kind = "item", item = "UNKNOWN" },
  }) do
    f.freshDecision({})
    out.mode, out.decision = "override", decision
    local action = f.query()
    local before = f.mon().nickname
    if f.gen == 3 then
      f.execute(action)
    end
    rows[#rows + 1] = {
      decision = decision,
      spent = f.gen == 2 and action or f.kind(action),
      before = before,
      after = f.mon().nickname,
    }
    if decision.kind == "switch" then
      T.eq(f.mon().nickname, decision.index == 2 and "BENCH" or "ENEMY", "actual switched occupant")
    end
  end
  if f.gen == 3 then
    local b = f.freshDecision({ f.item("POTION") }, true)
    f.mon(1).hp, f.mon(3).hp = 1, 1
    out.mode, out.decision = "override", { kind = "item", item = "POTION" }
    local action = f.query(3)
    f.execute(action, 3)
    T.eq(f.mon(3).hp, 21, "right-hand foe receives its requested item")
    T.eq(f.mon(1).hp, 1, "left-hand foe is untouched")
    rows[#rows + 1] = { mode = "right-item", left = f.mon(1).hp, right = f.mon(3).hp, stock = f.used() }
    f.freshDecision({}, true)
    out.mode, out.decision = "override", { kind = "switch", index = 3 }
    action = f.query(3)
    f.execute(action, 3)
    T.eq(f.mon(3).nickname, "THIRD", "right-hand switch uses right-hand native slot")
    T.eq(f.mon(1).nickname, "ENEMY", "right-hand switch preserves left-hand occupant")
    rows[#rows + 1] = { mode = "right-switch", left = f.mon(1).nickname, right = f.mon(3).nickname }
  end
  for _, row in ipairs({
    { "POTION", 201 },
    { "POTION", 200 },
    { "POTION", 390 },
    { "FULL_RESTORE", 100 },
    { "FULL_RESTORE", 130 },
    { "FULL_HEAL", 400, "poison" },
  }) do
    local b = f.freshDecision({ f.item(row[1]) })
    local mon = f.mon()
    mon.hp, mon.status = row[2], row[3]
    out.mode = "delegate"
    local action = f.query()
    if f.gen == 3 then
      f.execute(action)
    end
    rows[#rows + 1] = {
      mode = "native-item",
      item = row[1],
      hp = row[2],
      status = row[3],
      spent = f.gen == 2 and action or f.kind(action),
      after = f.mon().hp,
      afterStatus = f.mon().status or false,
      stock = f.used(),
    }
  end
  for _, mode in ipairs({ "next-false", "next-item", "mutate" }) do
    f.freshDecision({ f.item("POTION") })
    f.mon().hp = 1
    out.mode = mode
    local action = f.query()
    if f.gen == 3 then
      f.execute(action)
    end
    rows[#rows + 1] =
      { mode = mode, spent = f.gen == 2 and action or f.kind(action), hp = f.mon().hp, stock = f.used() }
  end
  do
    local b = f.freshDecision({})
    out.mode = "delegate"
    if f.gen == 2 then
      b.trainer.attributes[6] = 1
      if backend == "gen1" then
        b:volatile(b.enemy).perish = 1
      else
        b.enemy.perishTurns = 1
      end
    elseif backend == "gen1" then
      b.enemy.perishSong, b.enemy.expPerishTurns = true, 0
    else
      b.enemy.perishTurns = 0
    end
    local action = f.query()
    if f.gen == 3 then
      f.execute(action)
    end
    rows[#rows + 1] = {
      mode = "native-perish-switch",
      spent = f.gen == 2 and action or f.kind(action),
      after = f.mon().nickname,
    }
  end
  if f.gen == 2 then
    for _, mode in ipairs({ "no-attributes", "higher-bench" }) do
      local b = f.freshDecision({ f.item("POTION") })
      f.mon().hp = 1
      if mode == "no-attributes" then
        b.trainer.attributes = nil
      else
        b.enemyParty[2].level = 40
      end
      out.mode = "delegate"
      local action = f.query()
      rows[#rows + 1] = { mode = mode, spent = action, hp = f.mon().hp, stock = f.used() }
    end
  end
  if f.gen == 3 then
    for _, row in ipairs(dofile(root .. "/tests/enemy_decision/switch_cases.lua")(f, root, backend)) do
      rows[#rows + 1] = row
    end
  end
  out.stop()
  f.close()
  return rows
end
return C
