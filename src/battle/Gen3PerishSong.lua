-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- GBA Perish Song affects the whole present field and exposes a live zero turn.
local P={}
local V=require('src.core.GameVersion')
local Strings=require('src.core.Strings')
local builtins=setmetatable({},{__mode='k'})
local function name(actor)
 return actor.isPlayer and actor.name or Strings('Enemy %s',actor.name)
end
local function soundproof(actor)
 local ability=require('src.battle.Abilities').of(actor)
 return tonumber(ability)==43 or type(ability)=='string'and ability:upper():gsub('%s+','_')=='SOUNDPROOF'
end
function P.run(ctx)
 local affected,blocked=0,{}
 for _,actor in ctx.battle:activeBattlers()do
  local immune=soundproof(actor)
  if actor.perishTurns or immune then
   if immune then blocked[#blocked+1]=actor end
  else actor.perishTurns=3;affected=affected+1 end
 end
 if affected==0 then return{Strings('But, it failed!')},false end
 local messages={ctx.battle:romText('STRINGID_FAINTINTHREE',Strings.source('All POKéMON that\nhear the song will\nfaint in three turns!'))}
 for _,actor in ipairs(blocked)do
  messages[#messages+1]=ctx.battle:romText('STRINGID_PKMNSXBLOCKSY2',Strings.source("%s's %s\nblocks %s!"),name(actor),Strings('SOUNDPROOF'),Strings('PERISH SONG'))
 end
 return messages,true
end
function P.tick(battle,order)
 order=order or require('src.battle.GbaItemSchedule').residualOrder(battle)
 for _,previous in ipairs(order)do
  local actor=battle:battlerAt(previous.position)
  if actor and actor.mon and actor.mon.hp>0 and actor.perishTurns then
   local n=actor.perishTurns
   battle:sayNext(battle:romText('STRINGID_PKMNPERISHCOUNTFELL',Strings.source("%s's PERISH count\nfell to %d!"),name(actor),n))
   if n<=0 then
    actor.perishTurns=nil
    -- Perish is residual loss, so a previous attacking move cannot make
    -- Destiny Bond or Grudge act as the source of this faint.
    actor.destinyBond,actor.grudge=nil,nil
    actor.mon.hp=0;battle:drainNext(actor,0);battle:onFaint(actor)
   else actor.perishTurns=n-1 end
  end
 end
end
function P.builtin(id,base)
 if not V.isGen3()or id~='PERISH_SONG_EFFECT'or not base then return base end
 if builtins[base]then return builtins[base]end
 local out={};for key,value in pairs(base)do out[key]=value end
 out.run=P.run;builtins[base]=out;builtins[out]=out;return out
end
return P
