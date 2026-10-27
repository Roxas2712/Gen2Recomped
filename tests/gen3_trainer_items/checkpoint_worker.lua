-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- The producer and consumer run in separate VMs. Only serialized checkpoint
-- bytes cross that boundary; the consumer never creates the original battle.
local phase,edition,api,format=arg[1],assert(arg[2]),assert(tonumber(arg[3])),assert(arg[4])
if phase=='produce-baseline' then
 local source=assert(arg[5]);package.preload['src.core.CheckpointBattle']=function()return assert(loadfile(source))()end
end
local T=require('tests.harness');love=require('tests.love_stub')
local seed=714821
love.math.random=function(a,b)
 seed=(seed*48271)%2147483647
 if not a then return seed/2147483647 end
 if not b then a,b=1,a end
 return a+seed%(b-a+1)
end
love.math.getRandomState=function()return tostring(seed)end
love.math.setRandomState=function(value)seed=assert(tonumber(value))end
love.math.newRandomGenerator=function()return{setState=function(_,value)assert(tonumber(value))end}end
local F=require('tests.checkpoint_fixture')
local Native=require('src.battle.BattleState')
local Items=require('src.battle.Gen3TrainerItems')
local Serializer=require('src.core.SaveSerializer');local Json=require('src.link.Json')
local f=F.boot(edition,api,format);local game=f.game
game.save.options.battleAnimations=false
local calls=0
f.loaded.loader.exports.checkpoint_fixture.api.hooks:wrap('battle.enemy_switch_or_item',function(next,battle)
 calls=calls+1;return next(battle)
end)
for _,row in ipairs({{13,{0,0,0,0,4,0,20}},{19,{0,0,0,63,4,0,255}},{501,{0,0,0,128,0,0,0}}})do
 local key=('ITEM_%03d'):format(row[1]);game.data.items[key]={id=key,index=row[1],name=key}
 game.data.constants.gen3ItemEffects=game.data.constants.gen3ItemEffects or{}
 game.data.constants.gen3ItemEffects[key]={bytes=row[2]}
end
local def=game.data.trainers.OPP_FIX_YOUNGSTER
def.items={[1]='ITEM_013',[3]='ITEM_501',[4]='ITEM_019'}
local function turn()
 local battle=f.stack:top();local previous=battle.turnCount or 0
 game.input.wasPressed=function()return true end;game.input.pressed=game.input.wasPressed
 battle:chooseMenu('fight');battle:chooseMove(1)
 local ticks=0
 repeat battle:update(1/60);ticks=ticks+1
 until battle.phase=='menu' and not battle.current and #battle.queue==0 or ticks>=4000
 T.check(ticks<4000 and battle.phase=='menu','actual native turn completed')
 T.check((battle.turnCount or 0)>previous,'native turn advanced')
 return battle
end
if phase=='produce' or phase=='produce-baseline' then
 local battle=Native.newTrainer(game,'OPP_FIX_YOUNGSTER',1)
 battle.phase,battle.queue,battle.introSlide='menu',{},0;battle:syncSides()
 for _,actor in ipairs({battle.player,battle.enemy})do
  actor.mon.stats.hp,actor.mon.stats.defense,actor.mon.stats.spdef=400,400,400
  actor.mon.hp,actor.shownHP=400,400
 end
 battle.enemy.mon.hp,battle.enemy.shownHP=10,10;f.stack.states={f.world,battle}
 turn();T.eq(calls,1,'producer used actual trainer hook')
 T.eq(Items.history(battle).slots[1].spent,true,'producer consumed first native slot')
 def.items[4]='ITEM_013'
 local cp,code=f.checkpoints:capture(game);assert(cp,code)
 local future=turn();T.check(future.enemy.mon.hp>300,'uninterrupted native Full Restore healed')
 local nextCp,why=f.checkpoints:capture(game);assert(nextCp,why)
 print('GBA_CHECKPOINT_PACKET '..Json.encode({checkpoint=Serializer.encode(cp),future=Serializer.encode(nextCp),hp=future.enemy.mon.hp}))
elseif phase=='consume' then
 local packet=assert(Json.decode(io.read('*a')))
 T.eq(f.stack:top(),f.world,'fresh VM starts in the world, with no original battle')
 T.eq(calls,0,'fresh VM has not selected a trainer item')
 def.items[4]='ITEM_013'
 local cp=assert(Serializer.decode(packet.checkpoint));local ok,why=f.checkpoints:restore(game,cp)
 T.check(ok,'fresh VM restores actual checkpoint: '..tostring(why))
 if ok then
  local battle=f.stack:top();local cache=rawget(battle,'_gen3TrainerItems')
  T.check(cache~=nil,'serialized stock exists without the original VM')
  local future=turn();local nextCp,code=f.checkpoints:capture(game);assert(nextCp,code)
  local same=Serializer.encode(nextCp)==packet.future
  T.eq(future.enemy.mon.hp,packet.hp,'fresh VM reproduces native item HP')
  T.check(same,'fresh VM reproduces the complete next checkpoint')
  T.eq(calls,1,'fresh VM executed the trainer callback once')
  print('GBA_CHECKPOINT_RESULT '..Json.encode({restored=true,cacheRetained=cache~=nil,hp=future.enemy.mon.hp,expectedHp=packet.hp,futureEqual=same}))
 end
else error('unknown checkpoint worker phase')end
f.close();T.finish('native trainer checkpoint across fresh VMs')
