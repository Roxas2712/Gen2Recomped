-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
local C = {}
function C.run(root, backend, version)
  local Fixture = dofile(root .. "/tests/charge_required/fixture.lua")
  local defs = {
    [13] = {0,0,0,0,4,0,20}, [19] = {0,0,0,63,4,0,255},
    [20] = {0,0,0,0,4,0,255}, [23] = {0,0,0,63,0,0},
    [500] = {15,242,66,0,0,0}, [501] = {0,0,0,128,0,0},
    [502] = {0,0,0,0,7,0,1,2,50}, [503] = {0,0,0,0,4,0,254},
    [504] = {0,0,0,0,4,0,253}, [505] = {0,0,0,0,68,0,254},
    [506] = {176,0,0,0,0,0}, [507] = {0,0,0,16,0,0},
    [508] = {0,0,0,0,0,0},
    [509] = {0,0,0,0,5,0,3,45}, [510] = {0,0,0,0,6,0,4,50},
  }
  local function key(id) return backend == "gen1" and id or ("ITEM_%03d"):format(id) end
  local f = Fixture.new(root, backend, version, 3, "unified", true, false,
    "portable_enemy_action", function(data)
      local copy = require("src.mods.Merge").deepCopy
      if backend == "gen2" then
        data.constants.generation, data.constants.gen3ItemEffects = 3, {}
        data.moves.MOVE_210 = {id="MOVE_210", index=210, effect="FURY_CUTTER_EFFECT"}
      end
      for id, bytes in pairs(defs) do
        if backend == "gen1" then
          data.gen3Items._byId[id] = {name="ITEM " .. id, pocket="ITEMS", effect=copy(bytes)}
        else
          data.items[key(id)] = {id=key(id), index=id, name="ITEM " .. id}
          data.constants.gen3ItemEffects[key(id)] = {bytes=copy(bytes)}
        end
      end
    end)
  local copy = require("src.mods.Merge").deepCopy
  local Native, Effects, Items, previous, Adapter, oldSink
  if backend == "gen1" then
    Native = require("src.core.game3.battle.ai_items")
    Items = require("src.core.game3.items_data")
    previous, Items._byId = Items._byId, f.data.gen3Items._byId
    Adapter = require("src.core.game3.battle.adapter")
    oldSink, Adapter.textSink = Adapter.textSink, function(id) return id end
  else Effects = require("src.battle.Gen3TrainerItemEffects") end
  local rows = {}
  local cases = {
    {"potion",13,{hp=10},{hp=30}},
    {"mixed HP parameter",502,{hp=345},{hp=346}},
    {"EV HP and heal parameter",509,{hp=10},{hp=13}},
    {"EV attack and heal parameter",510,{hp=10},{hp=14}},
    {"full restore",19,{hp=10,status="TOX",confusion=3},{hp=400,status=false,confusion=0,toxic=0}},
    {"max potion",20,{hp=300},{hp=400}},
    {"half HP",503,{hp=1,maxHp=401},{hp=201}},
    {"level-up sentinel",504,{hp=10},{hp=10}},
    {"healing cannot revive",13,{hp=0},{hp=0}},
    {"revive minimum one",505,{hp=0,maxHp=1},{hp=1}},
    {"revive ignores living",505,{hp=10},{hp=10}},
    {"sleep and nightmare",23,{hp=400,status="SLP",nightmare=true},{status=false,sleep=0,nightmare=false}},
    {"unrelated status retained",507,{status="BRN"},{status="BRN"}},
    {"X stats clamp",500,{stage=5},{stages={6,6,6,6,6}}},
    {"focus and attraction",506,{infatuated=true},{focus=true,infatuated=false}},
    {"mist begins",501,{}, {mist=5}},
    {"mist not refreshed",501,{mist=2},{mist=2}},
    {"double right recipient",13,{right=true,hp=10},{hp=30,leftHp=200}},
    {"two-trainer right recipient",13,{right=true,second=true,hp=10},{hp=30,leftHp=200}},
    {"redirected player recipient",13,{player=true,hp=10},{hp=30,playerHp=30,leftHp=200}},
    {"redirected player mist",501,{player=true,hp=10},{mist=5,playerHp=10,leftHp=200}},
    {"live item program",13,{hp=10,mutate=true},{hp=60}},
    {"item clears move effects",508,{fury=true,destiny=true,grudge=true},{fury=0,destiny=false,grudge=false}},
    {"item preserves Rollout",508,{rollout=true},{rollout=4}},
  }
  for _, case in ipairs(cases) do
    local label, item, opts, want = unpack(case)
    local b = f.fresh("TACKLE").battle
    local mons = {b.enemy.mon, copy(b.enemy.mon)}
    local players = {b.player.mon, copy(b.player.mon)}
    if backend == "gen1" then
      if opts.right then
        b = require("src.core.game3.battle.state").new({wild=false,double=true,
          playerParty=players,foeParty=mons,foeHalf=opts.second and 1 or nil})
      end
      b.wild, b.trainerItems = false, {item}
    else
      b.kind, b.enemyParty, b.trainer = "trainer", opts.right and not opts.second and mons or {mons[1]}, {items={key(item)}}
      b:syncSides()
      if opts.right then
        f.game.save.party, b.playerParty, b.playerPartyIndices = players, players, {1,2}
        b.double = true; b:sendOutSecondPair()
        if opts.second then
          f.data.trainers.TEST_ITEM_SECOND = {name="SECOND",items={},parties={{{prebuilt=copy(mons[2])}}}}
          f.T.eq(b:addOpponentTrainer("TEST_ITEM_SECOND"), true, label .. ": native second trainer")
        end
      end
    end
    local id = opts.player and 0 or opts.right and 3 or 1
    local actor = backend == "gen1" and require("src.core.game3.battle.state").battler(b,id) or b:battlerAt(id)
    b.player.mon.hp = 400; b.enemy.mon.hp = (opts.right or opts.player) and 200 or 400
    actor.mon.hp, actor.mon.maxHp = opts.hp or 10, opts.maxHp or 400
    actor.mon.stats = actor.mon.stats or {}; actor.mon.stats.hp = actor.mon.maxHp
    actor.mon.status, actor.status = opts.status, opts.status
    actor.toxicCounter, actor.sleepTurns = opts.status == "TOX" and 3 or nil, opts.status == "SLP" and 2 or nil
    actor.stages = backend == "gen1" and {attack=opts.stage or 0,defense=opts.stage or 0,speed=opts.stage or 0,accuracy=opts.stage or 0,spAtk=opts.stage or 0}
      or {attack=opts.stage or 0,defense=opts.stage or 0,speed=opts.stage or 0,accuracy=opts.stage or 0,spatk=opts.stage or 0}
    actor.focusEnergy, actor.destinyBond = nil, opts.destiny or nil
    if backend == "gen1" then
      actor.confusionTurns, actor.expNightmare, actor.expInfatuated = opts.confusion, opts.nightmare, opts.infatuated
      actor.expGrudge, actor.expFuryCutter, actor.expRollout = opts.grudge, opts.fury and 4 or 0, opts.rollout and 4 or 0
      local side = opts.player and b.playerSide or b.enemySide
      side.expMistTurns = opts.mist or 0
    else
      actor.confusedTurns, actor.nightmare, actor.infatuated = opts.confusion, opts.nightmare, opts.infatuated
      actor.grudge = opts.grudge
      actor.rampMove, actor.rampRun = opts.fury and "MOVE_210" or opts.rollout and "ROLLOUT" or nil, (opts.fury or opts.rollout) and 4 or nil
      b.sides[opts.player and 1 or 2].gen3MistTurns = opts.mist or 0
    end
    local action
    if opts.mutate then
      action = backend == "gen1" and Native.useStocked(b,id,item) or require("src.battle.Gen3TrainerItems").stocked(b,actor,key(item))
      f.T.check(action ~= nil, label .. ": reserve before editing effect bytes")
      if backend == "gen1" then Items._byId[item].effect[7] = 50
      else f.data.constants.gen3ItemEffects[key(item)].bytes[7] = 50 end
    end
    if backend == "gen1" then
      local effect = Native.effect(item)
      action = action or {item=item,battler=id,aiItemType=Native.itemType(item,effect),aiItemFlags=0}
      f.T.eq(require("src.core.game3.battle.items").enemyUse(b,Adapter.new(b),action), true, label .. ": native enemyUse")
    else f.T.eq(Effects.apply(b,actor,key(item)), true, label .. ": native effect program") end
    local function flag(value) return value and true or false end
    local row = {label=label,hp=actor.mon.hp,status=actor.mon.status or false,
      confusion=(backend=="gen1" and actor.confusionTurns or actor.confusedTurns) or 0,
      toxic=actor.toxicCounter or 0,sleep=actor.sleepTurns or 0,focus=flag(actor.focusEnergy),
      nightmare=flag(backend=="gen1" and actor.expNightmare or actor.nightmare),
      infatuated=flag(backend=="gen1" and actor.expInfatuated or actor.infatuated),
      destiny=flag(actor.destinyBond),grudge=flag(backend=="gen1" and actor.expGrudge or actor.grudge),
      fury=backend=="gen1" and (actor.expFuryCutter or 0) or (actor.rampMove=="MOVE_210" and actor.rampRun or 0),
      rollout=backend=="gen1" and (actor.expRollout or 0) or (actor.rampMove=="ROLLOUT" and actor.rampRun or 0),
      mist=backend=="gen1" and (opts.player and b.playerSide or b.enemySide).expMistTurns or b.sides[opts.player and 1 or 2].gen3MistTurns,
      leftHp=(opts.right or opts.player) and b.enemy.mon.hp or false,playerHp=b.player.mon.hp,
      stages={actor.stages.attack,actor.stages.defense,actor.stages.speed,actor.stages.accuracy,actor.stages.spAtk or actor.stages.spatk}}
    local expected = {label=label,hp=opts.hp or 10,status=opts.status or false,confusion=opts.confusion or 0,
      toxic=opts.status=="TOX" and 3 or 0,sleep=opts.status=="SLP" and 2 or 0,focus=false,
      nightmare=opts.nightmare or false,infatuated=opts.infatuated or false,destiny=false,grudge=false,
      fury=0,rollout=opts.rollout and 4 or 0,mist=opts.mist or 0,leftHp=false,playerHp=400,
      stages={opts.stage or 0,opts.stage or 0,opts.stage or 0,opts.stage or 0,opts.stage or 0}}
    for k,v in pairs(want) do expected[k]=v end
    f.T.same(row,expected,label .. ": independently expected native post-state")
    rows[#rows+1] = row
  end
  if Items then Items._byId, Adapter.textSink = previous, oldSink end
  f.close()
  return rows, f.T
end
return C
