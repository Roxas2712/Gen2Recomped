-- Native GBA class actions must precede the switch/item hook, with their
-- own per-Pokemon allowance and the same shared trainer item stock.
return function(f, backend)
  local T, rows = f.T, {}
  local native = backend == "gen1"
  T.eq(f.e.classItem, "POTION", "public AI class reads canonical item")
  T.eq(f.e.registeredClassItem, "POTION", "public AI class register returns canonical detached record")
  T.eq(f.e.patchResultClassItem, "FULL_RESTORE", "public AI class patch result uses canonical item")
  T.eq(f.e.patchedClassItem, "FULL_RESTORE", "public AI class patch maps canonical item")
  T.eq(f.e.iteratedClassItem, "POTION", "public AI class override and iteration map canonical item")
  T.eq(f.e.classDetached, true, "public AI class reads are detached")
  rows[#rows + 1] = {
    class = "public-content",
    item = f.e.classItem,
    registered = f.e.registeredClassItem,
    patchResult = f.e.patchResultClassItem,
    patched = f.e.patchedClassItem,
    iterated = f.e.iteratedClassItem,
    detached = f.e.classDetached,
  }
  local registries
  if native then
    registries = require("src.core.game3.battle.mod_registries")
    registries.bind(f.data)
  end
  local function query(b, id)
    if native then
      return require("src.core.game3.battle.commands").enemyAction(b, id or 1)
    end
    return b:enemyAction(b:battlerAt(id or 1))
  end
  for _, spec in ipairs({
    { name = "public-class", public = true, expected = "item" },
    { name = "item", record = { uses = 1, item = f.item("POTION") }, expected = "item" },
    { name = "switch", record = { uses = 1, switch = true }, expected = "switch" },
    { name = "chance-refuses", record = { uses = 1, item = f.item("POTION"), chance = 0 } },
    {
      name = "chance-accepts",
      record = { uses = 1, item = f.item("POTION"), chance = 256 },
      expected = "item",
    },
    { name = "zero-uses", record = { uses = 0, item = f.item("POTION") } },
    {
      name = "switch-before-item",
      record = { uses = 1, item = f.item("POTION"), switchChance = 256 },
      expected = "switch",
    },
    { name = "healthy-status-gate", record = { uses = 1, item = f.item("POTION"), onStatus = true } },
    {
      name = "poison-status-gate",
      record = { uses = 1, item = f.item("POTION"), onStatus = true },
      status = "poison",
      expected = "item",
    },
    { name = "hp-below", record = { uses = 1, item = f.item("POTION"), hpBelow = 2 }, expected = "item" },
    { name = "hp-equal", record = { uses = 1, item = f.item("POTION"), hpBelow = 2 }, hp = 200 },
    {
      name = "hp-switch",
      record = { uses = 1, item = f.item("POTION"), hpBelow = 4, switchBelow = 2 },
      hp = 150,
      expected = "switch",
    },
    { name = "layer", record = { kind = "layer", uses = 1, item = f.item("POTION") } },
    { name = "empty-stock", record = { uses = 1, item = f.item("POTION") }, empty = true },
    {
      name = "right-item",
      record = { uses = 1, item = f.item("POTION") },
      double = true,
      id = 3,
      expected = "item",
    },
  }) do
    local b = f.freshDecision(spec.empty and {} or { f.item("POTION") }, spec.double)
    local id, mon = spec.id or 1, f.mon(spec.id)
    mon.hp, mon.status = spec.hp or 1, spec.status
    local registry = native and "gen3AiClasses" or "ai_classes"
    f.data[registry] = f.data[registry] or {}
    local classId = spec.public and "PORTABLE_NATIVE_CLASS" or "PORTABLE_CLASS"
    if not spec.public then
      f.data[registry][classId] = spec.record
    end
    if native then
      b.aiClass = classId
    else
      b.trainer.aiClass = classId
    end
    f.e.state.mode = "suppress"
    local act = query(b, id)
    local kind = f.kind(act) or "move"
    T.eq(kind, spec.expected or "move", "native GBA class action " .. spec.name)
    T.eq(f.e.state.calls, spec.expected and 0 or 1, "native class/hook precedence " .. spec.name)
    if kind == "item" or kind == "switch" then
      f.execute(act, id)
    end
    rows[#rows + 1] = {
      class = spec.name,
      kind = kind,
      calls = f.e.state.calls,
      hp = f.mon(id).hp,
      occupant = f.mon(id).nickname,
      stock = f.remainingStock(),
    }
    if spec.name == "item" then
      f.e.state.calls = 0
      local again = query(b, id)
      T.eq(f.kind(again) or "move", "move", "class allowance is spent once")
      T.eq(f.e.state.calls, 1, "exhausted class reaches public hook")
      rows[#rows + 1] = { class = "spent-allowance", calls = f.e.state.calls, hp = f.mon(id).hp }
    end
  end
  local b = f.freshDecision({})
  local registry = native and "gen3AiClasses" or "ai_classes"
  f.data[registry].PORTABLE_RETURN_CLASS = { uses = 1, switch = true }
  if native then
    b.aiClass = "PORTABLE_RETURN_CLASS"
  else
    b.trainer.aiClass = "PORTABLE_RETURN_CLASS"
  end
  f.e.state.mode = "suppress"
  for i, occupant in ipairs({ "BENCH", "ENEMY", "ENEMY" }) do
    local act = query(b, 1)
    local kind = f.kind(act) or "move"
    if kind == "switch" then
      f.execute(act, 1)
    end
    T.eq(f.mon().nickname, occupant, "class allowance follows the returning party Pokemon")
    T.eq(f.e.state.calls, i == 3 and 1 or 0, "only exhausted returning Pokemon reaches hook")
    rows[#rows + 1] = {
      class = "return-allowance",
      turn = i,
      kind = kind,
      occupant = f.mon().nickname,
      calls = f.e.state.calls,
    }
  end
  if registries then
    registries.bind(nil)
  end
  return rows
end
