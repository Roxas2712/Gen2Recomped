-- Deterministic owned native turn probe, shared by CPU regressions and an
-- exact predecessor comparison. No ROM, player profile or simulated combat.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local B=require('src.core.game3.battle')
local Fixture=require('tools.battle-source-runtime.fixture')
local function open(edition)
 local f=Fixture.new(edition);local b=f.fresh('TACKLE').battle
 -- Wild construction uses random personality/IVs before this fixture binds
 -- its battle RNG. Hold both actual mon records constant for the A/B turn.
 local enemy=b.enemy.mon
 for key in pairs(enemy)do enemy[key]=nil end
 for key,value in pairs(require('src.mods.Merge').deepCopy(b.player.mon))do enemy[key]=value end
 b.enemy.curStats,b.enemy.curMoves=enemy.stats,enemy.moves
 b.player.shownHP,b.enemy.shownHP=b.player.mon.hp,enemy.hp
 package.loaded['src.core.Game']=f.game
 b.enter=false;f.game.stack:push(b)
 b.queue={};b.current=nil;b.introSlide=0;b.introBalls=nil;b.phase='menu'
 return f,b
end
local function close(f)
 while f.game.stack:top()do f.game.stack:pop()end
 f.close();B._service.release();require('src.core.Game3').release()
end
local function turn(edition,observe,prepare)
 local f,b=open(edition);local rolls={}
 b.rng=function(lo,hi)rolls[#rolls+1]={lo,hi};return lo or 0 end
 if prepare then prepare(f,b)end
 if not observe then package.loaded['src.core.game3.battle']=nil end
 b:resolveTurn(b.player.mon.moves[1])
 package.loaded['src.core.game3.battle']=B
 f.game.input.wasPressed=function(_,key)return key=='a'end
 local trace={}
 for i=1,1200 do
  b:update(1/60)
  if observe then local actions,cursor=B._actions,B._actionI;assert(not actions or cursor==nil or cursor>=0)end
  trace[i]={phase=b.phase,frame=b.frame,playerHP=b.player.mon.hp,enemyHP=b.enemy.mon.hp,
   playerPP=b.player.mon.moves[1].pp,enemyPP=b.enemy.mon.moves[1]and b.enemy.mon.moves[1].pp}
  if b.phase=='menu'and #b.queue==0 and not b.current then break end
  assert(i<1200,'owned native action turn did not finish')
 end
 local result={trace=trace,rolls=rolls,turn=b.turnCount,phase=b.phase}
 close(f)
 return result
end
return {open=open,close=close,turn=turn}
