-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local F=require('tools.battle-source-runtime.fixture')
local P=require('src.pokemon.Pokemon')
local M=require('src.battle.Gen3ExpParticipants')
local W=require('src.import.LuaWriter')
for _,edition in ipairs{'ruby','sapphire','emerald','firered','leafgreen'}do
  local f=F.new(edition);local b=f.fresh('TACKLE').battle
  local partner=P.new(f.data,'CHARMANDER',30,function(lo)return lo or 0 end)
  local reserve=P.new(f.data,'CHARMANDER',30,function(lo)return lo or 0 end)
  f.game.save.party[2],f.game.save.party[3]=partner,reserve
  b.enemyParty={b.enemy.mon,P.new(f.data,'CHARMANDER',30,function(lo)return lo or 0 end)}
  b.double=true;b:sendOutSecondPair();b:syncSides()
  local left,right=b:battlerAt(1),b:battlerAt(3)
  local first=b.player.mon
  T.check(M.forFallen(b,left)[first]and M.forFallen(b,left)[partner])
  local exp1,exp2=first.exp,partner.exp
  b:awardExp(left)
  local gain1,gain2=first.exp-exp1,partner.exp-exp2
  T.check(gain1>0);T.eq(gain2,gain1,'first foe splits among both active players')
  T.eq(next(b.participants),nil,'legacy participant list really was cleared')
  exp1,exp2=first.exp,partner.exp
  b:awardExp(right)
  T.eq(first.exp-exp1,gain1,'second foe cannot give the lead an unsplit award')
  T.eq(partner.exp-exp2,gain2,'partner receives experience from the second foe too')
  -- Switching out does not erase a surviving participant of the other foe.
  local actor=b:battlerAt(2);actor.mon=reserve;b:syncSides()
  local flags=M.forFallen(b,right)
  T.check(flags[first]and flags[partner]and flags[reserve],'all three faced the existing foe')
  -- Only the newly entering opponent resets its mask to current occupants.
  b.enemyParty[3]=P.new(f.data,'CHARMANDER',30,function(lo)return lo or 0 end)
  left.mon=b.enemyParty[3];b:syncSides()
  flags=M.forFallen(b,left)
  T.check(flags[first]and flags[reserve]and not flags[partner],'new foe starts its own exposure history')
  T.check(M.forFallen(b,right)[partner],'the unchanged flank keeps its switched-out participant')
  partner.hp=0;T.eq(M.forFallen(b,right)[partner],nil,'fainted mons do not dilute the split')
  partner.hp=1;T.check(M.forFallen(b,right)[partner],'revived prior participants remain eligible')
  local snapshot=W.encode(b.gen3ExpParticipants)
  local restored=assert(loadstring(snapshot))();b.gen3ExpParticipants=restored
  T.check(M.forFallen(b,right)[partner],'index-only logical record survives serialization')
  local before=W.encode(f.game.save);local random,rolls=love.math.random,0
  love.math.random=function(...)rolls=rolls+1;return random(...)end
  M.observe(b);M.forFallen(b,right)
  T.eq(W.encode(f.game.save),before,'observation never edits save')
  T.eq(rolls,0,'observation never consumes RNG');love.math.random=random
  require('src.core.GameVersion').set('gold')
  T.eq(M.forFallen(b,right),nil,'Gen2 keeps its own experience path')
  f.close()
end
T.finish('GBA independent opposing EXP masks, switched participants and checkpoint-safe indices')
