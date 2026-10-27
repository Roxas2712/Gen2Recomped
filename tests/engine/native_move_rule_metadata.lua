-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Moves=require('src.core.game3.battle.moves');local Rules=require('src.core.game3.battle.rules')
local Damage=require('src.battle.Damage');local V=require('src.core.GameVersion')
local original=package.loaded['src.core.Game']
T.eq(Rules.crit.CHANCE,nil,'no fabricated GBA session')
for _,edition in ipairs{'firered','leafgreen','emerald','ruby','sapphire'}do
 local f=require('tools.battle-source-runtime.fixture').new(edition)
 package.loaded['src.core.Game']=f.game
 local key=f.ids.TACKLE;local row=f.game.data.moves[key]
 f.game.data.constants.moveOrder={[33]=key};f.game.data.constants.typeOrder={'NORMAL'}
 f.game.data.constants.types={NORMAL={index=0}}
 row.gen3Effect=0;row.effect='NO_ADDITIONAL_EFFECT';row.secondaryChance=10;row.effectChance=26
 row.flags={contact=true,nested={owner='native'}};row.hits={min=2,max=5}
 row.highCrit=false;row.makesContact=true;row.protectAffected=true
 for _,value in ipairs{33,'33',key,{id=key},{move=33}}do
  local out=assert(Moves.get(value))
  T.eq(out.id,33);T.eq(out.numId,33);T.eq(out.nativeId,key);T.eq(out.effect,0)
  T.eq(out.gen3Effect,0);T.eq(out.nativeEffect,'NO_ADDITIONAL_EFFECT')
  T.eq(out.type,0);T.eq(out.secondaryChance,10);T.eq(out.effectChance,26)
  T.eq(out.makesContact,true);T.eq(out.protectAffected,true)
  out.flags.nested.owner='source';out.hits.min=9;out.name='SOURCE'
  T.eq(row.flags.nested.owner,'native');T.eq(row.hits.min,2);T.eq(row.name,'TACKLE')
 end
 for _,byte in ipairs{2,4,6,17,31,36,43,103,200,209,255}do
  row.gen3Effect=byte;T.eq(Moves.get(33).effect,byte,'live imported byte, no name reverse-guess')
 end
 for _,invalid in ipairs{-1,256,.5,0/0,math.huge,'0'}do
  row.gen3Effect=invalid;local out,why=Moves.get(33);T.eq(out,nil);T.eq(why,'invalid imported native move-effect byte')
 end
 row.gen3Effect=nil;T.eq(Moves.get(33).effect,'NO_ADDITIONAL_EFFECT','older metadata stays explicit')
 T.eq(Moves.get(33).gen3Effect,nil);row.gen3Effect=0
 row.flags={contact=false};row.hits=false;T.eq(Moves.get(33).flags.contact,false);T.eq(Moves.get(33).hits,false)
 row.hits=function()error('metadata must never execute a hit producer')end;T.eq(Moves.get(33).hits,true)
 row.flags=51;row.hits=nil;T.eq(Moves.get(33).flags,51)
 T.eq(Moves.get(999999),nil);T.eq(Moves.get({}),nil)
 local replacement={};for k,v in pairs(row)do replacement[k]=v end
 replacement.name='LIVE';f.game.data.moves[key]=replacement;T.eq(Moves.get(33).name,'LIVE')
 local chance=Rules.crit.CHANCE;T.same(chance,{[0]=16,8,4,3,2})
 chance[0]=1;T.eq(Rules.crit.CHANCE[0],16,'returned rule rows are detached')
 T.raises(function()Rules.crit.CHANCE={}end,'read-only')
 local battle=f.fresh('TACKLE').battle
 -- The older public calculation owns a one-based RNG and legacy stage inputs;
 -- the current native command owns physical items and a zero-based draw.
 local modern=debug.getinfo(Damage.critRoll,'u').nparams>=8
 for stage=0,4 do
  local user=battle.player;user.focusEnergy=stage>=2
  local extra=(stage==1 or stage==3 or stage==4)and 1 or 0
  user.item=modern and extra*198 or 0;user.critStage=modern and 0 or extra
  local high=stage==4;local calls=0;local lo,hi
  local function rng(a,b)calls=calls+1;lo,hi=a,b;return a end
  T.eq(Damage.critRoll({critStages=true},user,key,rng,high,battle.data,battle),true)
  T.eq(calls,1);T.eq(lo,modern and 0 or 1);T.eq(hi-lo+1,Rules.crit.CHANCE[stage],'metadata matches native RNG denominator')
 end
 f.close()
end
for _,edition in ipairs{'red','crystal','platinum','black'}do
 V.set(edition);T.eq(Rules.crit.CHANCE,nil,'GBA rules do not replace other generations')
end
package.loaded['src.core.Game']=original;V.set('firered')
T.finish('native move bytes, detached metadata and shared critical-rule observations')
