local F = {}
function F.new(root, backend, version, api, format, noMod)
  local f = dofile(root .. "/tests/charge_required/fixture.lua").new(
    root,
    backend,
    version,
    api,
    format,
    noMod,
    false,
    "portable_enemy_decision",
    function(data, gen)
      if gen == 3 then
        data.constants = data.constants or {}
        data.constants.gen3ItemEffects = {}
      end
      for _, row in ipairs({ { "POTION", 13, 20 }, { "FULL_RESTORE", 19, "all" }, { "FULL_HEAL", 23, false } }) do
        local key = backend == "gen2" and gen == 3 and ("ITEM_%03d"):format(row[2]) or row[1]
        if backend == "gen1" and gen == 3 then
          data.gen3Items._byId[row[2]] = {
            name = row[1]:gsub("_", " "),
            pocket = "ITEMS",
            effect = {
              0,
              0,
              0,
              row[1] ~= "POTION" and 63 or 0,
              row[3] and 4 or 0,
              0,
              row[3] == "all" and 255 or row[3] or 0,
            },
          }
        else
          data.items[key] = { id = key, name = row[1]:gsub("_", " "), index = row[2], price = 100 }
          if gen == 3 then
            data.constants.gen3ItemEffects[key] = {
              heal = row[3] and true or nil,
              amount = row[3] or nil,
              cureAll = row[1] ~= "POTION" and true or nil,
            }
          end
        end
      end
    end
  )
  local copy = require("src.mods.Merge").deepCopy
  local restores = {}
  local function patch(t, k, value)
    local old = t[k]
    t[k] = value
    restores[#restores + 1] = function()
      t[k] = old
    end
  end
  if backend == "gen1" and f.gen == 3 then
    local Items = require("src.core.game3.items_data")
    patch(Items, "_byId", f.data.gen3Items._byId)
    patch(Items, "_byName", { POTION = 13, FULL_RESTORE = 19, FULL_HEAL = 23 })
    patch(Items, "_pack", { items = f.data.gen3Items._byId })
  end
  local oldClose = f.close
  f.close = function()
    for i = #restores, 1, -1 do
      restores[i]()
    end
    oldClose()
  end
  function f.item(name)
    if f.gen == 3 then
      local n = ({ POTION = 13, FULL_RESTORE = 19, FULL_HEAL = 23 })[name]
      return backend == "gen1" and n or ("ITEM_%03d"):format(n)
    end
    return name
  end
  function f.freshDecision(stock, double)
    local first = f.fresh("TACKLE")
    local b = first.battle
    if backend == "gen1" and f.gen == 2 then
      local p = copy(b.player)
      local e, bench = copy(b.enemy), copy(b.enemy)
      e.nickname, bench.nickname = "ENEMY", "BENCH"
      b = require("src.battle.gen2.Battle").new({
        data = f.data,
        party = { p },
        trainer = { name = "FOE", party = { e, bench }, items = stock or {}, attributes = { 0, 0, 0, 0, 0, 0, 0 } },
        random = function()
          return 0
        end,
      })
    elseif backend == "gen1" then
      local State = require("src.core.game3.battle.state")
      local p, e = copy(b.player.mon), copy(b.enemy.mon)
      local p2, e2, e3 = copy(p), copy(e), copy(e)
      p.nickname, e.nickname, e2.nickname, e3.nickname = "PLAYER", "ENEMY", "BENCH", "THIRD"
      b = State.new({ wild = false, double = double, playerParty = { p, p2 }, foeParty = { e, e2, e3 } })
      b.trainerItems, b.rng = stock or {}, function(lo)
        return lo or 0
      end
      b._aiHistory = nil
    else
      b.kind, b.trainer =
        "trainer",
        { id = "PORTABLE_FOE", name = "FOE", items = stock or {}, attributes = { 0, 0, 0, 0, 0, 0, 0 } }
      local bench, third = copy(b.enemy.mon), copy(b.enemy.mon)
      b.enemy.mon.nickname, bench.nickname, third.nickname = "ENEMY", "BENCH", "THIRD"
      b.enemy.name = "ENEMY"
      b.enemyParty = { b.enemy.mon, bench, third }
      b.enemyIndex = 1
      b:syncSides()
      if double then
        local extra = f.fresh("TACKLE").battle
        extra.enemy.mon, extra.enemy.name = bench, "BENCH"
        b.double = true
        b:placeBattler(2, extra.player)
        b:placeBattler(3, extra.enemy)
        b:syncSides()
      end
    end
    f.battle = b
    if backend == "gen1" and f.gen == 2 then
      for _, mon in ipairs(b.enemyParty) do
        mon.maxHp, mon.stats.hp = 400, 400
      end
      b.player.maxHp, b.player.stats.hp = 400, 400
    end
    b.queue, b.nextInsert = {}, nil
    if f.e and f.e.state then
      f.e.state.calls, f.e.state.contexts, f.e.state.last, f.e.state.repeated = 0, {}, nil, nil
    end
    return b
  end
  function f.mon(id)
    local b = f.battle
    if backend == "gen1" and f.gen == 2 then
      return b.enemy
    end
    if backend == "gen1" then
      return require("src.core.game3.battle.state").battler(b, id or 1).mon
    end
    return b:battlerAt(id or 1).mon
  end
  function f.query(id)
    local b = f.battle
    if f.gen == 2 then
      return b:enemyTrySwitchOrItem()
    end
    if backend == "gen1" then
      return require("src.core.game3.battle.ai").switchOrItem(
        b,
        require("src.core.game3.battle.adapter").new(b),
        id or 1,
        b.rng
      )
    end
    return b:enemySwitchOrItem(b:battlerAt(id or 1))
  end
  function f.execute(action, id)
    if not action then
      return false
    end
    local b = f.battle
    if backend == "gen1" then
      local Engine, Adapter =
        require("src.core.game3.battle.engine"), require("src.core.game3.battle.adapter")
      if action.kind == "switch" then
        Engine.performSwitch(b, Adapter.new(b), id or 1, action.slot)
      else
        Engine.performEnemyItem(b, Adapter.new(b), action)
      end
    else
      b:executeAction(b:battlerAt(id or 1), b.player, action)
    end
    return true
  end
  function f.used()
    local b = f.battle
    if f.gen == 2 then
      return #(b.trainer.items or {})
    end
    if backend == "gen1" then
      return require("src.core.game3.battle.ai_items").history(b).items[1] == 0
    end
    return b.gen3ItemsUsed and b.gen3ItemsUsed[1] == true or false
  end
  function f.kind(action)
    if not action then
      return false
    end
    return action.kind or ({ aiSwitch = "switch", aiItem = "item" })[action.special]
  end
  return f
end
return F
