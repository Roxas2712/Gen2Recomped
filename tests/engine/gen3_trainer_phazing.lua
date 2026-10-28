-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local F=require('tools.battle-source-runtime.fixture')
local P=require('src.pokemon.Pokemon')
local M=require('src.battle.Gen3Phazing')
local V=require('src.core.GameVersion')
local W=require('src.import.LuaWriter')
local function mon(f)
  return P.new(f.data,'CHARMANDER',30,function(lo)return lo or 0 end)
end
local function rolls(b,list)
  local used=0
  b.rng=function(lo,hi)
    used=used+1;local value=assert(list[used],debug.traceback('unexpected RNG draw '..used))
    T.check(value>=lo and value<=hi,'draw stays in native range')
    return value
  end
  return function()return used end
end
local function context(b,user,target,id)
  b:syncSides()
  return{battle=b,user=user,target=target,move={id=id or'ROAR',index=id=='WHIRLWIND'and 18 or 46,
    power=0,type='NORMAL',accuracy=100,protectAffected=true},say=function(text)b:sayNext(text)end}
end
for _,edition in ipairs{'ruby','sapphire','emerald','firered','leafgreen'}do
  local f=F.new(edition)
  local b=f.fresh('TACKLE').battle;b.kind='trainer'
  local old=b.player;old.mon.level=47;b.enemy.mon.level=41
  local dead,egg,reserve=mon(f),mon(f),mon(f);dead.hp=0;egg.isEgg=true
  f.game.save.party[2],f.game.save.party[3],f.game.save.party[4]=dead,egg,reserve
  old.stages.attack,old.confusedTurns,old.substituteHP=4,3,20
  b.enemy.infatuated,b.enemy.trappedBy,b.enemy.trappingTurns=old,old,4
  local before=W.encode(f.game.save)
  local used=rolls(b,{1,255,0,1,2,3})
  local incoming=M.perform(context(b,b.enemy,old))
  T.eq(incoming.mon,reserve,'enemy Roar actually replaces the player')
  T.eq(b.player,incoming);T.eq(incoming.position,0);T.eq(incoming.partyIndex,4)
  T.eq(incoming.stages.attack or 0,0);T.eq(incoming.confusedTurns,nil);T.eq(incoming.substituteHP,nil)
  T.eq(b.enemy.infatuated,nil);T.eq(b.enemy.trappedBy,nil);T.eq(b.enemy.trappingTurns,nil)
  T.eq(used(),6,'native level byte and uncompressed rejection sampling')
  T.eq(W.encode(f.game.save),before,'phazing does not edit party or save contents')
  local enemyHp=b.enemy.mon.hp
  b:executeAction(old,b.enemy,{id='MOVE_033',pp=10})
  T.eq(b.enemy.mon.hp,enemyHp,'outgoing actor cannot perform its queued action')
  -- Player Whirlwind switches the foe, not the player, and records its index.
  b=f.fresh('TACKLE').battle;b.kind='trainer'
  local foe=b.enemy;local spare=mon(f);b.enemyParty={foe.mon,mon(f),spare};b.enemyParty[2].hp=0
  used=rolls(b,{1,0,1,2})
  incoming=M.perform(context(b,b.player,foe,'WHIRLWIND'))
  T.eq(incoming.mon,spare);T.eq(b.enemyIndex,3);T.eq(incoming.isPlayer,false);T.eq(used(),4)
  -- Native refusal order: ability and roots precede accuracy and selection.
  for _,reason in ipairs{'ability','roots'}do
    b=f.fresh('TACKLE').battle;b.kind='trainer'
    if reason=='ability'then b.player.abilityOverride='SUCTION_CUPS'else b.player.ingrained=true end
    used=rolls(b,{})
    T.eq(M.perform(context(b,b.enemy,b.player)),false);T.eq(used(),0)
  end
  b=f.fresh('TACKLE').battle;b.kind='trainer'
  used=rolls(b,{1})
  T.eq(M.perform(context(b,b.enemy,b.player)),false,'no eligible replacement')
  T.eq(used(),1,'party refusal consumes accuracy but no level/selection draw')
  -- With a lower-level user the native low byte can still reject the move.
  f.game.save.party[2]=mon(f);b.enemy.mon.level=1;b.player.mon.level=100
  used=rolls(b,{1,0});local kept=b.player
  T.eq(M.perform(context(b,b.enemy,b.player)),false);T.eq(b.player,kept);T.eq(used(),2)
  -- Wild phazing ends the battle without attempting trainer replacements.
  b=f.fresh('TACKLE').battle;used=rolls(b,{1})
  T.eq(M.perform(context(b,b.player,b.enemy)),true);T.eq(b.result,'run');T.eq(b.afterQueue,'finish')
  T.eq(used(),1)
  -- A shared double bench must have three able mons, and cannot draw the
  -- target's active partner even if that slot is sampled repeatedly.
  b=f.fresh('TACKLE').battle;b.kind='trainer';b.double=true
  f.game.save.party[2],f.game.save.party[3]=mon(f),mon(f)
  b.enemyParty={b.enemy.mon,mon(f)};b:sendOutSecondPair();b:syncSides()
  local right=b:battlerAt(2);local valid,party,slots=M.pool(b,b.player)
  T.eq(valid[1],nil);T.eq(valid[2],nil);T.eq(valid[3],true);T.eq(slots,6)
  used=rolls(b,{1,1,2})
  T.eq(M.pick(b,valid,slots),3);T.eq(used(),3)
  party[3].hp=0;T.eq(M.pool(b,b.player),nil,'double requires three able party members')
  party[3].hp=1
  b.ally={party={right.mon,mon(f)}};right.ally=true
  valid,party,slots=M.pool(b,right)
  T.eq(party,b.ally.party);T.eq(valid[1],nil);T.eq(valid[2],true);T.eq(slots,3,'ally uses its own three slots')
  local secondFoe=b:battlerAt(3);b.enemyPartyB={secondFoe.mon,mon(f)}
  valid,party,slots=M.pool(b,secondFoe)
  T.eq(party,b.enemyPartyB);T.eq(valid[2],true);T.eq(slots,3,'second trainer keeps its party ownership')
  local vanillaCalls=0;local base={kind='full',customField='kept',perform=function()vanillaCalls=vanillaCalls+1;return'vanilla'end}
  local record=M.builtin('SWITCH_AND_TELEPORT_EFFECT',base)
  T.check(record~=base);T.eq(record.customField,'kept');T.eq(M.builtin('SWITCH_AND_TELEPORT_EFFECT',base),record)
  T.eq(record.perform({move={id='TELEPORT'}}),'vanilla');T.eq(vanillaCalls,1)
  for _,other in ipairs{'red','gold','platinum','black'}do
    V.set(other);T.eq(M.builtin('SWITCH_AND_TELEPORT_EFFECT',base),base)
  end
  V.set(edition);T.eq(M.builtin('NO_ADDITIONAL_EFFECT',base),base)
  f.close()
end
T.finish('GBA trainer phazing, native level/rejection draws, party ownership and continuations')
