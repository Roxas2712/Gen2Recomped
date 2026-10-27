-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- MIST and Guard Spec share one five-turn condition on each GBA side.
local V=require('src.core.GameVersion')
local Strings=require('src.core.Strings')
local M={}
local builtins=setmetatable({},{__mode='k'})
local function side(battle,actor)
 return actor and battle.sides and battle.sides[actor.isPlayer and 1 or 2]
end
function M.active(battle,actor)
 local own=side(battle,actor)
 return own~=nil and (tonumber(own.gen3MistTurns)or 0)>0
end
function M.sync(battle)
 if not V.isGen3()then return end
 for position=0,3 do
  local actor=battle.battlerAt and battle:battlerAt(position)
    or(position==0 and battle.player or position==1 and battle.enemy)
  if actor then
   if M.active(battle,actor)then actor.mist,actor.gen3MistFromSide=true,true
   elseif actor.gen3MistFromSide then actor.mist,actor.gen3MistFromSide=nil,nil end
  end
 end
end
function M.apply(battle,actor)
 local own=side(battle,actor)
 if not own or (tonumber(own.gen3MistTurns)or 0)>0 then return false end
 own.gen3MistTurns=5;M.sync(battle);return true
end
function M.tick(battle)
 for index,own in ipairs(battle.sides or{})do
  if (tonumber(own.gen3MistTurns)or 0)>0 then
   own.gen3MistTurns=own.gen3MistTurns-1
   if own.gen3MistTurns==0 then
    own.gen3MistTurns=nil
    battle:sayNext(index==1 and Strings("Your team's MIST wore off!")or Strings("The foe's MIST wore off!"))
   end
  end
 end
 M.sync(battle)
end
function M.validState(battle)
 for _,own in ipairs(battle.sides or{})do
  local n=own.gen3MistTurns
  if n~=nil and(type(n)~='number'or n%1~=0 or n<0 or n>5)then return false end
 end
 return true
end
function M.builtin(id,base)
 if not V.isGen3()or not base or(id~='MIST_EFFECT'and id~='HAZE_EFFECT')then return base end
 if builtins[base]then return builtins[base]end
 local out={};for key,value in pairs(base)do out[key]=value end
 if id=='MIST_EFFECT'then
  out.run=function(ctx)
   if not M.apply(ctx.battle,ctx.user)then return{Strings('But, it failed!')},false end
   local name=ctx.user.isPlayer and ctx.user.name or('Enemy '..ctx.user.name)
   return{Strings("%s's\nshrouded in mist!",name)},true
  end
 else
  out.run=function(ctx)
   local messages,success=base.run(ctx)
   -- Legacy Haze clears actor flags; native side screens survive Haze.
   M.sync(ctx.battle)
   return messages,success
  end
 end
 builtins[base]=out;builtins[out]=out;return out
end
return M
