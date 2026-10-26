-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Battle=require('src.core.game3.battle')
local Ui=require('src.core.game3.battle.ui')
local Phase=require('src.compat.game3.BattleCommandPhase')
local base=Ui.takeCommand
local oldGame=package.loaded['src.core.Game']
local G=require('src.core.Game3')
for _,edition in ipairs{'firered','leafgreen','emerald','ruby','sapphire'}do
 local f=require('tools.battle-source-runtime.fixture').new(edition)
 local game=f.game;package.loaded['src.core.Game']=game
 local second=require('src.mods.Merge').deepCopy(game.data.moves.MOVE_033)
 second.id,second.index,second.name='MOVE_034',34,'SECOND'
 game.data.moves.MOVE_034=second;game.data.constants.moveOrder[34]='MOVE_034'
 local function fresh()
  Ui.takeCommand=base;Battle._service.release()
  while game.stack:top()do game.stack:pop()end
  local b=f.fresh('TACKLE').battle;b.enter=false;game.stack:push(b)
  b.phase='moveSelect';b.queue={};b.current=nil;b.afterQueue=nil
  b.player.curMoves[2]={id='MOVE_034',pp=7}
  b.player.mon.moves=b.player.curMoves
  local count,chosen=0,nil;local turn=b.resolveTurn
  b.resolveTurn=function(self,action)count=count+1;chosen=action;return turn(self,action)end
  return b,function()return count,chosen end
 end
 T.eq(type(base),'function');T.eq(base(),nil,'no command exists outside its native selection')
 local q=fresh();T.eq(Ui._st,Battle.getState());T.eq(Ui._mode,'moves');T.eq(Ui._active,0)
 local qframe=q.frame;Ui._moveIndex=2;T.eq(q.moveIndex,2);T.eq(Ui._moveIndex,2);T.eq(rawget(Ui,'_moveIndex'),nil,'cursor assignment cannot shadow the live native observation')
 T.eq(q.frame,qframe);T.eq(Ui.waitingForCommand(),true);T.eq(Ui.busy(),false);T.eq(Ui.dialogPending(),false)
 T.raises(function()Ui._moveIndex=3 end,'invalid native battle cursor')
 T.raises(function()Ui._mode='menu'end,'read-only');T.raises(function()Ui._st={}end,'read-only')
 q.phase='menu';Ui._menuIndex=4;T.eq(q.menuIndex,4);T.eq(rawget(Ui,'_menuIndex'),nil)
 T.raises(function()Ui._moveIndex=1 end,'cursor is not active')
 q.moveSwapIndex=1;T.eq(Ui._swap,1);q.moveSwapIndex=nil
 q:act(function()end);T.eq(Ui.busy(),true);T.eq(Ui.waitingForCommand(),false);T.eq(Ui.dialogPending(),false)
 q:say('Native queued message');T.eq(Ui.dialogPending(),true);q.queue={};q:startMessage({text='Native current message'})
 T.eq(Ui.dialogPending(),true);T.eq(Ui.busy(),true);q.current=nil
 game.stack:push({});T.eq(Ui.waitingForCommand(),false);T.eq(Ui.busy(),true)
 T.raises(function()Ui._menuIndex=1 end,'does not own the cursor');game.stack:pop()

 local b,seen=fresh();local frame=b.frame
 Ui.takeCommand=function()
  local c=base();T.eq(c.kind,'move');T.eq(c.slot,1);T.eq(c.move,33);T.eq(c.battler,0);T.eq(c.user,'player')
  T.eq(base(),nil,'the pending native selection can be taken only once')
  return c
 end
 b:chooseMove(1);local n,action=seen();T.eq(n,1);T.eq(action,b.player.curMoves[1]);T.eq(b.frame,frame,'taking a command does not advance a combat frame')
 T.eq(base(),nil)
 b,seen=fresh();local secondMove=b.player.curMoves[2]
 Ui.takeCommand=function()local c=base();c.slot,c.move=2,34;return c end
 b:chooseMove(1);n,action=seen();T.eq(n,1);T.eq(action,secondMove,'replacement uses an actual native move slot');T.eq(b.moveIndex,2)
 b,seen=fresh();local pp=b.player.curMoves[1].pp
 Ui.takeCommand=function()base();return nil end
 T.eq(b:chooseMove(1),true);n=seen();T.eq(n,0);T.eq(b.phase,'moveSelect');T.eq(b.player.curMoves[1].pp,pp,'cancelled selection cannot spend PP');T.eq(base(),nil)
 b,seen=fresh()
 Ui.takeCommand=function()local c=base();Battle.getState().player.mon.pp[1]=0;return c end
 b:chooseMove(1);n=seen();T.eq(n,0,'native selection refusal is reevaluated after the callback');T.eq(b.phase,'messages')
 b,seen=fresh()
 Ui.takeCommand=function()local c=base();c.slot=0/0;return c end
 T.raises(function()b:chooseMove(1)end,'invalid native move command slot');n=seen();T.eq(n,0);T.eq(base(),nil,'an error cannot strand a pending command')
 b,seen=fresh()
 Ui.takeCommand=function()local c=base();c.move=34;return c end
 T.raises(function()b:chooseMove(1)end,'does not match its slot');n=seen();T.eq(n,0)
 b,seen=fresh()
 Ui.takeCommand=function()local c=base();game.stack:push({});return c end
 b:chooseMove(1);n=seen();T.eq(n,0,'a covering state invalidates the borrowed native command');T.eq(base(),nil);game.stack:pop()
 b,seen=fresh()
 Ui.takeCommand=function()local c=base();b.phase='messages';return c end
 b:chooseMove(1);n=seen();T.eq(n,0,'changed native input ownership prevents a stale commit')
 b,seen=fresh()
 local calls=0;Ui.takeCommand=function()calls=calls+1;return base()end
 b:chooseAction({id='STRUGGLE',pp=1,struggle=true});n=seen();T.eq(n,1);T.eq(calls,0,'forced commands stay with their native sequencer')
 b,seen=fresh()
 Ui.takeCommand=function()local c=base();Battle._service.release();Battle.getState();return c end
 b:chooseMove(1);n=seen();T.eq(n,0,'retired source admission cannot commit through a new view of the same native battle')
 b,seen=fresh()
 Ui.takeCommand=function()local c=base();b.player.mon.hp=0;return c end
 b:chooseMove(1);n=seen();T.eq(n,0,'fainted actors cannot commit after a source callback')
 b,seen=fresh()
 local Native=require('src.battle.BattleState')
 local Pokemon=require('src.pokemon.Pokemon')
 local function extra(pos,player)
  local mon=Pokemon.new(game.data,'CHARMANDER',30,function(lo)return lo or 0 end)
  mon.hp,mon.stats.hp,mon.moves=400,400,{{id='MOVE_033',pp=10}}
  if player then game.save.party[#game.save.party+1]=mon else b.enemyParty=b.enemyParty or{b.enemy.mon};b.enemyParty[#b.enemyParty+1]=mon end
  b:placeBattler(pos,Native.makeBattler(game.data,mon,player,player and game.save or nil,b))
 end
 b.double=true;extra(2,true);extra(3,false);b:syncSides()
 Ui.takeCommand=function()local c=base();T.eq(c.target,1);c.target=3;return c end
 b:chooseMove(1);T.eq(b.phase,'targetSelect')
 local first;for i,candidate in ipairs(b.targetChoices)do if candidate.position==1 then first=i end end
 T.check(first~=nil);b:chooseTarget(first)
 n=seen();T.eq(n,0,'first double selection waits for its native partner')
 T.eq(b.pendingActions[0],b.player.curMoves[1]);T.eq(b.chosenTargets[0],b:battlerAt(3),'replacement target uses the real native selector')
 T.eq(b:choosingSlotNow(),2)
 Ui.takeCommand=function()local c=base();T.eq(c.battler,2);return c end
 b:chooseMenu('fight');b:chooseMove(1)
 local nextTarget;for i,candidate in ipairs(b.targetChoices or{})do if candidate.position==1 then nextTarget=i end end
 T.check(nextTarget~=nil);b:chooseTarget(nextTarget);n=seen();T.eq(n,1,'both native selections produce one double turn')
 b,seen=fresh()
 b.resolveTurn=function()return false,nil,'native commit result'end
 Ui.takeCommand=function()return base()end
 local firstResult,secondResult,thirdResult=b:chooseAction(b.player.curMoves[1])
 T.eq(firstResult,false);T.eq(secondResult,nil);T.eq(thirdResult,'native commit result','native command phase preserves multiple and nil return values')
 b,seen=fresh();local owner=G._callbackOwner()
 Ui.takeCommand=function()T.eq(G._callbackOwner(),'command_owner');error('command source failure')end
 local seams=require('src.mods.ModSeams');seams._journal[#seams._journal+1]={tbl=Ui,key='takeCommand',after=Ui.takeCommand,owner='command_owner'}
 T.raises(function()b:chooseMove(1)end,'command source failure');T.eq(G._callbackOwner(),owner);T.eq(base(),nil);n=seen();T.eq(n,0)
 table.remove(seams._journal)
 Ui.takeCommand=base;f.close();Battle._service.release();G.release()
end
Ui.takeCommand=base;package.loaded['src.core.Game']=oldGame
T.finish('native move command borrowing, selection validation and once-only commit')
