-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- GBA RAMPAGE: successful-hit setup, per-battler end-turn countdown and
-- fatigue. The older shared effect counts successful continuation hits.
-- Native references: pokeemerald731ad5b, pokeruby5784633, pokefireredce6406d;
-- BattleScript_EffectRampage / MOVE_EFFECT_THRASH / ENDTURN_THRASH.
local R={}
local V=require('src.core.GameVersion')
local cache=setmetatable({},{__mode='k'})
function R.cancel(user)
 user.thrashTurns,user.thrashMove,user.thrashAnnounced,user.thrashTarget=nil,nil,nil,nil
end
function R.activate(ctx)
 local user=ctx.user
 if not user.thrashTurns or user.thrashTurns<=0 then
  user.thrashTurns=ctx.rng(0,1)+2
  user.thrashMove=ctx.moveInst
 end
 -- GBA attacks announce and animate every locked turn.
 user.thrashAnnounced=nil
end
function R.tick(battle,user)
 if not V.isGen3() or not user.thrashTurns then return end
 user.thrashTurns=user.thrashTurns-1
 if user.thrashTurns>0 then return end
 R.cancel(user)
 if user.confusedTurns or require('src.battle.Abilities').refusesStatus(user,'CONFUSION') then return end
 user.confusedTurns=battle.rng(0,3)+2
 local name=user.isPlayer and user.name or 'Enemy '..user.name
 battle:sayNext(battle:romText('STRINGID_THRASHCONFUSES','%s became\nconfused due to fatigue!',name))
 -- The existing native after-action item phase resolves Persim/Lum after
 -- this fatigue message. Do not run the older immediate berry consumer.
end
function R.interrupted(user,reason,presentation)
 if reason=='gen3_sleep' or presentation and (presentation.blockedStatus=='SLP' or presentation.blockedStatus=='FRZ') then return end
 R.cancel(user)
end
function R.protected(user,target,move,record)
 if not record or not record.gbaRampage or target==user or not target or not target.protecting
  or not require('src.battle.EffectRegistry').protectAffected(move) then return false end
 local locked=(user.thrashTurns or 0)>0
 R.cancel(user)
 return locked
end
function R.builtin(id,base)
 if not V.isGen3() or id~='THRASH_PETAL_DANCE_EFFECT' or not base then return base end
 if cache[base] then return cache[base] end
 local out={};for key,value in pairs(base) do out[key]=value end
 out.gbaRampage=true
 out.afterDamage=function(ctx,...)
  if V.isGen3() then return R.activate(ctx) end
  if base.afterDamage then return base.afterDamage(ctx,...) end
 end
 out.onProtect=function(ctx,...)
  if V.isGen3() then R.cancel(ctx.user) end
  if base.onProtect then return base.onProtect(ctx,...) end
 end
 out.onMiss=function(ctx,reason,...)
  if V.isGen3() and reason=='immune' then R.cancel(ctx.user) end
  if base.onMiss then return base.onMiss(ctx,reason,...) end
 end
 cache[base]=out;return out
end
return R
