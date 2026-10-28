-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local F=require('tools.battle-source-runtime.fixture')
local V=require('src.core.GameVersion')
local Runtime=require('src.mods.Runtime')
local oldEvents,oldHooks,oldErrors=Runtime.events,Runtime.hooks,Runtime.errors
local events,hooks=require('src.mods.Events').new(),require('src.mods.Hooks').new()
Runtime.install(events,hooks)
local turns={}
events:on('battle.turn_started',function(e)turns[#turns+1]=e end,0,'nonmove-round-fixture')
local function pump(b)
  local n=0
  while b.queue[1]and n<1000 do
    n=n+1;local row=table.remove(b.queue,1)
    if row.fn then b.nextInsert=0;row.fn()end
  end
  T.check(n<1000,'actual battle queue terminates')
end
for _,edition in ipairs{'ruby','sapphire','emerald','firered','leafgreen'}do
  local f=F.new(edition)
  f.data.moves.FAKE_OUT={id='FAKE_OUT',index=252,name='FAKE OUT',power=40,type='NORMAL',
    accuracy=100,accuracyRaw=255,pp=10,effect='FAKE_OUT_EFFECT',priority=1,flags=51}
  f.data.constants.moveOrder[252]='FAKE_OUT'
  local function fresh()
    local b=f.fresh('TACKLE').battle;b:syncSides();b.queue={};b.phase='messages';b.afterQueue='menu'
    for _,a in b:activeBattlers()do a.abilityOverride=false;a.curTypes={'NORMAL'}end
    return b
  end
  local b=fresh();b.turnCount=2
  b.player.turnsOut,b.enemy.turnsOut=2,2
  b.player.protecting,b.player.enduring=true,true
  b.enemy.hurtThisTurn,b.enemy.physicalDamageTaken,b.enemy.specialDamageTaken=true,27,31
  b.player._gen3HelpingHand=true;b.sides[1]._gen3FollowMePosition=0
  local count=#turns;local hp=b.player.mon.hp
  b:itemUsed({});pump(b)
  T.check(b.player.mon.hp<hp,edition..' previous Protect cannot block item-turn reply')
  T.eq(b.player.enduring,nil,edition..' previous Endure expires on item turn')
  T.eq(b.enemy.hurtThisTurn,nil,edition..' previous damage does not power Revenge')
  T.eq(b.enemy.physicalDamageTaken,nil,edition..' Counter cannot reuse previous round damage')
  T.eq(b.enemy.specialDamageTaken,nil,edition..' Mirror Coat cannot reuse previous round damage')
  T.eq(b.player._gen3HelpingHand,nil,edition..' previous Helping Hand expires')
  T.eq(b.sides[1]._gen3FollowMePosition,nil,edition..' previous Follow Me expires')
  T.eq(b.turnCount,3,edition..' item consumes exactly one counted round')
  T.eq(b.player.turnsOut,3,edition..' player first-turn window advances')
  T.eq(b.enemy.turnsOut,3,edition..' enemy first-turn window advances')
  T.eq(#turns,count+1,edition..' committed item emits one turn-start event')
  T.eq(b._nativeOrderReady,false,edition..' residuals retire the item round RNG word')
  local pp=b.enemy.curMoves[1].pp
  b:itemUsed({});pump(b)
  T.eq(b.turnCount,4,edition..' consecutive items are distinct rounds')
  T.eq(b.enemy.curMoves[1].pp,pp-1,edition..' consecutive item gets exactly one reply')
  T.eq(#turns,count+2,edition..' consecutive items emit distinct start events')

  -- The cartridge decrements isFirstTurn after item rounds too. Fake Out
  -- must fail after spending the first round in BAG, rather than getting
  -- an extra first-move window when the first actual move is selected.
  local first=fresh();first.player.curMoves={{id='FAKE_OUT',pp=10}}
  first.player.mon.moves=first.player.curMoves
  first:itemUsed({});pump(first)
  T.eq(first.player.turnsOut,1,edition..' initial item is the first round out')
  local enemyHp=first.enemy.mon.hp
  first:resolveTurn(first.player.curMoves[1]);pump(first)
  T.eq(first.enemy.mon.hp,enemyHp,edition..' Fake Out fails after initial item round')
  T.eq(first.player.curMoves[1].pp,9,edition..' failed Fake Out still spends one PP')
  T.eq(first.turnCount,2,edition..' item then move produces two rounds')

  local legal=fresh();legal.player.curMoves={{id='FAKE_OUT',pp=10}};legal.player.mon.moves=legal.player.curMoves
  local legalHp=legal.enemy.mon.hp
  legal:resolveTurn(legal.player.curMoves[1]);pump(legal)
  T.check(legal.enemy.mon.hp<legalHp,edition..' Fake Out still succeeds as actual first-round move')

  local failedRun=fresh();failedRun.noRun=true
  failedRun:tryRun();pump(failedRun)
  T.eq(failedRun.turnCount,1,edition..' committed failed escape shares the round start')
  T.eq(failedRun.enemy.curMoves[1].pp,9,edition..' failed escape has one enemy reply')
  local refused=fresh();refused.kind='trainer';local refusedTurn=refused.turnCount
  refused:tryRun();pump(refused)
  T.eq(refused.turnCount,refusedTurn,edition..' trainer RUN refusal does not commit a round')

  local switched=fresh();local outgoing=switched.player
  local reserve=require('src.pokemon.Pokemon').new(f.data,'CHARMANDER',30,function(lo)return lo or 0 end)
  reserve.hp,reserve.stats.hp=400,400;f.game.save.party[2]=reserve
  switched:resolveSwitch(reserve);pump(switched)
  T.eq(switched.player.mon,reserve,edition..' ordinary switch still installs its reserve')
  T.eq(switched.turnCount,1,edition..' ordinary switch starts exactly one round')
  T.eq(switched.enemy.curMoves[1].pp,9,edition..' switch has one enemy reply')
  T.eq(outgoing.turnsOut,1,edition..' outgoing actor is counted before the queued switch')

  local cancelled=fresh();local turn=cancelled.turnCount
  cancelled:openItems();cancelled.queue={} -- unopened/cancelled bag has no committed action
  T.eq(cancelled.turnCount,turn,edition..' opening BAG does not spend a round')
  f.close()
end
-- The shared non-move entry must keep the older hosts' delayed selection
-- and existing round ownership; only native GBA gains the missing start.
for _,edition in ipairs{'red','gold','platinum','black'}do
  V.set(edition)
  local b=setmetatable({turnCount=7},{__index=require('src.battle.BattleState')})
  b:nonMoveAction()
  T.eq(b.turnCount,7,edition..' retains existing non-move round ownership')
end
Runtime.install(oldEvents,oldHooks,oldErrors)
T.finish('five-edition item round flags, legal Fake Out window and counted replies')
