-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Friendship belongs to the reached native faint command, before its event.
local M = {}
local V = require('src.core.GameVersion')
local function rs() return V.get()=='ruby' or V.get()=='sapphire' end
local function slot(battle, actor) return actor and actor.position end
local function first(battle)
  local order=battle.linkRole=='guest' and {1,0,3,2} or {0,1,2,3}
  for _,id in ipairs(order) do if battle:battlerAt(id) then return id end end
end
function M.script(battle, user, target)
  if not V.isGen3() then return end
  battle._gbaFaintRoles={attacker=slot(battle,user),target=slot(battle,target),phase='script'}
end
function M.step(battle, actor, phase, source)
  if not V.isGen3() then return end
  local r=battle._gbaFaintRoles or {};battle._gbaFaintRoles=r
  if actor then
    r.attacker,r.target=slot(battle,actor),first(battle)
    if phase=='leech_seed' and source and source.mon.hp>0 and actor.mon.hp>0 then
      r.target=slot(battle,source)
    end
  elseif phase=='fainted_actions' or phase=='perish_song' then
    local last=battle:isDouble() and 3 or 1
    r.target=battle.linkRole=='guest' and (last%2==0 and last+1 or last-1) or last
  elseif phase~='future_sight' then
    r.attacker,r.target=first(battle),first(battle)
  end
  r.phase=phase
end
local function snapshot(battle, actor)
  local r=battle._gbaFaintRoles or {}
  local id=slot(battle,actor)
  local other
  if id==r.attacker then other=r.target elseif id==r.target then other=r.attacker end
  local b=other~=nil and battle:battlerAt(other)
  if not b or not b.mon then return end
  return {other=other,faintedLevel=tonumber(actor.mon.level)or 0,otherLevel=tonumber(b.mon.level)or 0}
end
function M.capture(battle, actor)
  if not rs() or not actor or not actor.mon or actor.mon.hp>0 then return end
  local r=battle._gbaFaintRoles
  if r and (r.phase=='weather_continue' or r.phase=='perish_song') then r.attacker=slot(battle,actor) end
  actor._gbaFaintContext=snapshot(battle,actor)
end
function M.apply(battle, actor)
  if not V.isGen3() or (not actor.isPlayer and battle.kind~='link') or actor._gbaFriendshipFainted then return end
  actor._gbaFriendshipFainted=true
  local mon=actor.mon
  if not mon.species or mon.egg or mon.isEgg or mon.species=='EGG' or require('src.pokemon.Party').isEgg(mon) then return end
  local otherLevel=0
  if rs() then
    local r=battle._gbaFaintRoles
    local c
    if r and r.phase=='script' then c=snapshot(battle,actor)
    else c=actor._gbaFaintContext or snapshot(battle,actor) end
    actor._gbaFaintContext=nil
    if battle:battlerAt(actor.position)~=actor or not c or c.otherLevel<=c.faintedLevel then return end
    -- The comparison uses levels captured by the reached residual HP command.
    -- A later phase must not replace that provenance with a convenient foe.
    local delta=c.otherLevel-c.faintedLevel>29 and 9 or 7
    return M.change(battle,mon,delta,actor.isPlayer)
  end
  for id=0,3 do
    local foe=battle:battlerAt(id)
    if foe and foe.mon and foe.isPlayer~=actor.isPlayer then
      -- The working controller row survives its KO announcement; alive-only
      -- targeting would lose the level of a just-fainted Destiny Bond user.
      otherLevel=math.max(otherLevel,tonumber(foe.mon.level)or 0)
    end
  end
  return M.change(battle,mon,otherLevel-(tonumber(mon.level)or 0)>29 and 9 or 7,actor.isPlayer)
end
function M.change(battle, mon, event, emit)
  local def=battle.data.pokemon and battle.data.pokemon[mon.species]
  local before=tonumber(mon.friendship or mon.happiness)or tonumber(def and def.friendship)or 70
  local loss=event==9 and (before>=200 and 10 or 5)or 1
  local after=math.max(0,math.min(255,math.floor(before-loss)))
  mon.friendship,mon.happiness=after,after
  local Runtime=require('src.mods.Runtime')
  -- A linked simulation also updates its detached remote party copy. Only
  -- the local player's party owns the public friendship notification.
  if emit and before~=after and Runtime.wants('happiness.changed') then
    Runtime.emit('happiness.changed',{mon=mon,event=event,reason='event',from=before,to=after,delta=after-before})
  end
  return true
end
local phases={script=true,ingrain=true,abilities_eot=true,held_items=true,leech_seed=true,status_chip=true,
  weather_continue=true,wish=true,fainted_actions=true,future_sight=true,perish_song=true,field_residual=true}
local function position(v) return v==nil or type(v)=='number' and v==math.floor(v) and v>=0 and v<=3 end
local function level(v)return type(v)=='number'and v==math.floor(v)and v>=0 and v<=255 end
function M.valid(battle, actor)
  local r=battle._gbaFaintRoles
  if r~=nil and (type(r)~='table' or not position(r.attacker)or not position(r.target)or not phases[r.phase])then return false end
  if actor._gbaFriendshipFainted~=nil and type(actor._gbaFriendshipFainted)~='boolean'then return false end
  local c=actor._gbaFaintContext
  return c==nil or type(c)=='table' and c.other~=nil and position(c.other)and level(c.faintedLevel)and level(c.otherLevel)
end
function M.signature(battle, actor, role)
  local r,c=battle._gbaFaintRoles or {},actor._gbaFaintContext or {}
  local function canonical(id)return id~=nil and (role=='guest'and(id%2==0 and id+1 or id-1)or id)or '-'end
  return ':friendshipFaint='..tostring(not not actor._gbaFriendshipFainted)
    ..',roles='..tostring(r.phase)..'/'..canonical(r.attacker)..'/'..canonical(r.target)
    ..',pending='..canonical(c.other)..'/'..tostring(c.faintedLevel)..'/'..tostring(c.otherLevel)
end
return M
