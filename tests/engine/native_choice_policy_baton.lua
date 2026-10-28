-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Probe=dofile('tests/native_action_plan/turn.lua')
local B=require('src.core.game3.battle')
local E=require('src.core.game3.battle.engine')
local Copy=require('src.mods.Merge').deepCopy
local base=E.resolveMove
local function open(edition)local f,b=Probe.open(edition);b:syncSides();return f,b end
-- Exercise the native Baton Pass owner, not a replacement party-choice loop.
for _,edition in ipairs{'firered','leafgreen','ruby','sapphire','emerald'}do
 for _,disabled in ipairs{false,true}do
  local f,b=open(edition);local st=B.getState();local mon=b.player.mon
  f.data.moves.MOVE_226={id='MOVE_226',index=226,name='BATON PASS',effect='BATON_PASS_EFFECT',gen3Effect=127,power=0,type='NORMAL',accuracy=0,pp=20,target=16,protectAffected=false}
  mon.moves={{id='MOVE_226',pp=20}};b.player.curMoves=mon.moves
  local bench=Copy(mon);bench.nickname='BENCH';f.game.save.party={mon,bench};b.playerParty=f.game.save.party
  b.interactiveChoices=true
  E.resolveMove=function(...)
   local prior=st.interactiveChoices
   if disabled then st.interactiveChoices=false end
   local result=base(...)
   if disabled then st.interactiveChoices=prior end
   return result
  end
  b:performMove(b.player,b.player,mon.moves[1])
  if disabled then
   T.eq(b._gen3BatonPending,nil,'scoped false uses the existing synchronous native choice')
   T.eq(b.player.mon,bench,'existing native Baton Pass installs its actual eligible member')
  else
   T.check(b._gen3BatonPending~=nil,'default native party choice remains interactive')
   T.eq(b.player.mon,mon,'interactive native choice keeps its donor pending')
  end
  T.eq(mon.moves[1].pp,19,'native PP is spent exactly once')
  T.eq(b.interactiveChoices,true,'native choice preference is never rewritten')
  E.resolveMove=base;Probe.close(f)
 end
end
-- A called Baton Pass inherits the live policy while spending only its
-- caller's PP; its nested resolver is deliberately not redecorated.
for _,edition in ipairs{'firered','leafgreen','ruby','sapphire','emerald'}do
 local f,b=open(edition);local st=B.getState();local mon=b.player.mon
 f.data.moves.MOVE_226={id='MOVE_226',index=226,name='BATON PASS',effect='BATON_PASS_EFFECT',gen3Effect=127,power=0,type='NORMAL',accuracy=0,pp=20,target=16,protectAffected=false}
 mon.moves={{id='MOVE_226',pp=20},{id='MOVE_033',pp=10}};b.player.curMoves=mon.moves
 local bench=Copy(mon);bench.nickname='CALLED_BENCH';f.game.save.party={mon,bench};b.playerParty=f.game.save.party
 f.data.move_effects=f.data.move_effects or Copy(require('src.battle.MoveEffects').RECORDS)
 f.data.move_effects.CALL_BATON={kind='full',callsMove=function()return 'MOVE_226'end}
 f.data.moves.MOVE_033.effect='CALL_BATON'
 b.interactiveChoices=true;local depth=0
 E.resolveMove=function(...)
  depth=depth+1;local prior=st.interactiveChoices
  if depth==1 then st.interactiveChoices=false end
  local result=base(...)
  if depth==1 then st.interactiveChoices=prior end
  depth=depth-1;return result
 end
 b:performMove(b.player,b.player,mon.moves[2])
 T.eq(b._gen3BatonPending,nil,'called native move borrows its active ancestor policy')
 T.eq(b.player.mon,bench);T.eq(mon.moves[1].pp,20,'called Baton Pass does not spend its own PP')
 T.eq(mon.moves[2].pp,9,'only the native caller spends PP')
 T.eq(b.interactiveChoices,true)
 E.resolveMove=base;Probe.close(f)
end
T.finish('Native invocation-local choice policy, coroutine visibility and actual Baton Pass selection')
