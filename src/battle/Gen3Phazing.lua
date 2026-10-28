-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- GBA atk8F_forcerandomswitch / sub_80264C0; no Gen1 trainer immunity.
local M={}
local V=require('src.core.GameVersion')
local Strings=require('src.core.Strings')
local cache=setmetatable({},{__mode='k'})
local function name(b)return b.isPlayer and b.name or('Enemy '..b.name)end
local function able(mon)
  return mon and mon.species and mon.species~=0 and (mon.hp or 0)>0
    and not require('src.pokemon.Party').isEgg(mon)
end
function M.isMove(move)
  local id=move and(move.index or move.numId or move.id)
  return id==18 or id==46 or id=='ROAR'or id=='WHIRLWIND'
end
function M.levelCheck(battle,user,target)
  local u,t=user.mon.level,target.mon.level
  if u>=t then return true end
  local r=battle.rng(0,65535)%256
  return math.floor(r*(u+t)/256)+1>math.floor(t/4)
end
function M.pool(battle,target)
  local pos=target.position or(target.isPlayer and 0 or 1)
  local party=battle:benchFor(target.isPlayer,pos)
  local separate=target.isPlayer and battle.ally~=nil or not target.isPlayer and battle.enemyPartyB~=nil
  local double=battle:isDouble()
  local count,valid,excluded=0,{},{[target.mon]=true}
  if double and not separate then
    local partner=battle:partnerOf(target)
    if partner then excluded[partner.mon]=true end
  end
  for i,mon in ipairs(party)do
    if able(mon)then count=count+1;if not excluded[mon]then valid[i]=true end end
  end
  local minimum=double and not separate and 3 or 2
  if count<minimum then return nil,party end
  return valid,party,separate and 3 or 6
end
-- Native random modulo party slots, including rejection draws for empty,
-- fainted, egg and already active slots. Do not compact the candidate list.
function M.pick(battle,valid,slots)
  local index
  repeat index=battle.rng(0,65535)%slots+1 until valid[index]
  return index
end
local function clearLinks(battle,previous)
  for _,other in battle:activeBattlers()do
    if other.infatuated==previous then other.infatuated=nil end
    if other.trappedBy==previous then
      other.trapped,other.trappedBy,other.escapePrevention=nil,nil,nil
    end
    if other.isPlayer~=previous.isPlayer then
      other.trappingTurns,other.trapMove,other.trapDamage=nil,nil,nil
    end
  end
end
function M.switch(battle,previous,index,party)
  local State=require('src.battle.BattleState')
  local pos=previous.position or(previous.isPlayer and 0 or 1)
  local mon=party[index]
  battle:restoreMimicked(previous)
  battle:abilitySwitchOut(previous)
  local incoming=State.makeBattler(battle.data,mon,previous.isPlayer,
    previous.isPlayer and not previous.ally and battle.game.save or nil,battle)
  incoming.ally,incoming.partyIndex=previous.ally,index
  previous.batonPass,previous.wantsSwitch=nil,nil
  battle:placeBattler(pos,incoming)
  if pos==1 and not incoming.isPlayer then battle.enemyIndex=index end
  battle:syncSides()
  clearLinks(battle,previous)
  require('src.mods.Runtime').emit('battle.battler_switched',{
    battle=battle,side=battle:sideOf(incoming),battler=incoming,previous=previous,
    battlerId=pos,partyIndex=index,reason='phazing'})
  if incoming.isPlayer and not incoming.ally then battle:markParticipant()end
  if not incoming.isPlayer then State.markSeen(battle.game,mon.species,mon)end
  battle:sayNext(Strings('%s was\ndragged out!',name(incoming)))
  battle:actNext(function()
    battle:startGrowIn(incoming)
    require('src.core.Sound').playCry(battle.data,mon.species)
    require('src.battle.HeldItems').onEntry(battle,incoming)
  end)
  battle:actNext(function()battle:abilitySwitchIn(incoming)end)
  return incoming
end
function M.perform(ctx)
  local b,u,t=ctx.battle,ctx.user,ctx.target
  local function fail(line)
    b:cancelMoveAnim();ctx.say(line or Strings('But, it failed!'))
    return false
  end
  if not(t and able(t.mon))then return fail()end
  if require('src.battle.Abilities').refusesPhasing(t)then
    return fail(Strings('%s\nanchored itself\nwith SUCTION CUPS!',name(t)))
  end
  if t.ingrained then return fail(Strings('%s anchored\nitself with its roots!',name(t)))end
  local hit,reason=b:accuracyRoll(ctx.move,u,t)
  if not hit then
    if reason=='absorbed'then b:cancelMoveAnim();return false end
    return fail(b:romText('_AttackMissedText',"%s's\nattack missed!",name(u)))
  end
  local valid,party,slots
  if b.kind~='wild'then
    valid,party,slots=M.pool(b,t)
    if not valid then return fail()end
  end
  if not M.levelCheck(b,u,t)then return fail()end
  if b.kind=='wild'then
    b.result,b.afterQueue='run','finish'
    return true
  end
  local index=M.pick(b,valid,slots)
  return M.switch(b,t,index,party)
end
function M.builtin(id,base)
  if not V.isGen3()or id~='SWITCH_AND_TELEPORT_EFFECT'or not base then return base end
  if cache[base]then return cache[base]end
  local out={};for k,v in pairs(base)do out[k]=v end
  out.perform=function(ctx,...)
    if V.isGen3()and M.isMove(ctx.move)then M.perform(ctx);return end
    return base.perform(ctx,...)
  end
  cache[base]=out;return out
end
return M
