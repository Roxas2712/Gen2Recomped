-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Keep the raw hook protocol separate from controller ownership and execution.
local Decision=require("src.battle.Gen3TrainerDecision")
local Items=require("src.battle.Gen3TrainerItems")
local C={}
local Strings=require("src.core.Strings")
local function position(battle,actor)
  return actor==battle.enemy and 1 or actor and actor.position
end
local function firstMove(actor)
  for _,move in ipairs(actor.curMoves or {})do
    if move.pp==nil or (tonumber(move.pp)or 0)>0 then return move end
  end
end
function C.fallback(actor)
  return firstMove(actor)or{id="STRUGGLE",pp=1,struggle=true}
end
function C.action(battle,actor,chosen)
  if not chosen then return nil end
  local id=position(battle,actor)
  if battle:isDouble() then
    if chosen.battler~=id and not(chosen.battler==nil and id==1)then return firstMove(actor)end
  elseif chosen.kind~="move" and chosen.kind~="switch" and chosen.kind~="item"
      and chosen.kind~="run" and chosen.kind~="watch" then return firstMove(actor)end
  if chosen.kind=="move" then
    return require("src.battle.EnemyMoveChoice").normalize(battle.data,actor,chosen)
      or firstMove(actor)
  end
  local special=chosen.kind=="item" and "aiItem" or chosen.kind=="switch" and "aiSwitch" or "modEnemyTurn"
  local payload={}
  for key,value in pairs(chosen)do payload[key]=value end
  -- The controller fixes the actor. In particular, an original hook result's
  -- battler edit must not move item use into the player's party.
  payload.battler=id
  return {special=special,gen3TrainerAction=true,gen3TrainerPosition=id,
    gen3TrainerPayload=payload,item=Decision.itemKey(battle,chosen.item)or chosen.item,
    aiItemType=chosen.aiItemType,aiItemFlags=chosen.aiItemFlags}
end
function C.plan(battle,actor)
  return C.action(battle,actor,Decision.call(battle,actor))
end

local cureLabels={
 [0]={"STRINGID_PKMNSITEMSNAPPEDOUT",Strings.source("%s snapped out\nof confusion!")},
 {"STRINGID_PKMNSITEMCUREDPARALYSIS",Strings.source("%s was cured\nof paralysis!")},
 {"STRINGID_PKMNSITEMDEFROSTEDIT",Strings.source("%s thawed out!")},
 {"STRINGID_PKMNSITEMHEALEDBURN",Strings.source("%s's burn\nwas healed!")},
 {"STRINGID_PKMNSITEMCUREDPOISON",Strings.source("%s was cured\nof poison!")},
 {"STRINGID_PKMNSITEMWOKEIT",Strings.source("%s woke up!")},
}
local function text(battle,label,fallback,...)
  battle:sayNext(battle:romText(label,fallback,...))
end
function C.execute(battle,queuedActor,action)
  local id=action.gen3TrainerPosition
  local actor=battle:battlerAt(id)
  if not actor or not actor.mon then return false end
  local payload=action.gen3TrainerPayload
  if payload.kind=="switch" then
    battle.monToSwitchInto=battle.monToSwitchInto or {}
    battle.monToSwitchInto[id]=nil
    local entry=Decision.entry(battle,payload.slot)
    if not entry then return false end
    return battle:switchTrainerInto(id,entry.index,entry.party)~=nil
  elseif payload.kind=="run" or payload.kind=="flee"then
    text(battle,"_WildFledText",Strings.source("Wild %s\nfled!"),actor.name)
    battle.result,battle.afterQueue="run","finish"
    return true
  elseif payload.kind~="item" or not payload.item then return false end
  local item=Decision.itemKey(battle,payload.item)or payload.item
  local effect=Items.effect(battle,item)
  local kind=payload.aiItemType or effect and effect.kind
  local flags=tonumber(payload.aiItemFlags)or 0
  local trainer=id==3 and battle.trainerB or battle.trainer
  local trainerName=trainer and trainer.name or battle:trainerLabel_()
  local itemName=battle.data.items[item]and battle.data.items[item].name or tostring(payload.item)
  local who=actor.isPlayer and actor.name or Strings("Enemy %s",actor.name)
  local Sound=require("src.core.Sound")
  if not Sound.playNamedEffect(battle.data,"SE_USE_ITEM")then Sound.play(battle.data,"Heal_HP")end
  text(battle,"STRINGID_TRAINER1USEDITEM",Strings.source("%s\nused %s!"),trainerName,itemName)
  require("src.battle.Gen3TrainerItemEffects").apply(battle,actor,item)
  if kind==Items.TYPE.FULL_RESTORE or kind==Items.TYPE.HEAL_HP then
    text(battle,"STRINGID_PKMNSITEMRESTOREDHEALTH",Strings.source("%s's item\nrestored health!"),who)
    battle:drainNext(actor)
  elseif kind==Items.TYPE.CURE_CONDITION then
    local chooser=0
    if flags%2==1 then if flags%64>=2 then chooser=5 end
    else
      local bits=flags
      while bits>0 and bits%2==0 do bits=math.floor(bits/2);chooser=chooser+1 end
    end
    local message=cureLabels[chooser]
    if message then text(battle,message[1],message[2],who)end
  elseif kind==Items.TYPE.X_STAT then
    if math.floor(flags/128)%2==1 then
      text(battle,"STRINGID_PKMNUSEDXTOGETPUMPED",Strings.source("%s used an item\nto get pumped!"),who)
    else
      local stat,bits=1,flags
      while bits>0 and bits%2==0 do bits=math.floor(bits/2);stat=stat+1 end
      local names={Strings.source("ATTACK"),Strings.source("DEFENSE"),Strings.source("SPEED"),Strings.source("SP. ATK"),Strings.source("SP. DEF"),Strings.source("ACCURACY")}
      text(battle,"STRINGID_USINGITEMSTATOFPKMNROSE",Strings.source("Using %s, the %s\nof %s rose!"),itemName,Strings(names[stat]or Strings.source("STAT")),who)
    end
  elseif kind==Items.TYPE.GUARD_SPECS then
    if battle:isDouble()then text(battle,"STRINGID_PKMNGETTINGPUMPED",Strings.source("%s is getting\npumped!"),who)
    else text(battle,"STRINGID_PKMNSHROUDEDINMIST",Strings.source("%s became\nshrouded in MIST!"),who)end
  end
  battle:syncShownStatus()
  return true
end
return C
