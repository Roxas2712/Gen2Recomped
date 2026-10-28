-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- battle.started observers run after native GBA history has been captured.
local T=require('tests.harness');love=require('tests.love_stub')
local Fixture=require('tests.checkpoint_fixture')
local Native=require('src.battle.BattleState')
local Items=require('src.battle.Gen3TrainerItems')
for _,edition in ipairs({'firered','leafgreen','ruby','sapphire','emerald'})do
 for _,policy in ipairs({{1,'native'},{2,'native'},{2,'unified'},{3,'unified'}})do
  for _,empty in ipairs({false,true})do
   local f=Fixture.boot(edition,policy[1],policy[2]);local game=f.game
   local api=f.loaded.loader.exports.checkpoint_fixture.api
   for _,row in ipairs({{13,20},{19,255}})do
    local key=('ITEM_%03d'):format(row[1]);game.data.items[key]={id=key,index=row[1],name=key}
    game.data.constants.gen3ItemEffects=game.data.constants.gen3ItemEffects or{}
    game.data.constants.gen3ItemEffects[key]={bytes={0,0,0,0,4,0,row[2]}}
   end
   local def=game.data.trainers.OPP_FIX_YOUNGSTER
   def.items=empty and{}or{'ITEM_013'}
   local battle=Native.newTrainer(game,'OPP_FIX_YOUNGSTER',1)
   local events,calls,selected=0,0,nil
   local offEvent=api.events:on('battle.started',function()
    events=events+1
    local history=rawget(battle,'_gen3TrainerItems')
    T.check(history and history.history,'native stock already exists at battle.started')
    -- A class edit is legal content mutation, but not a refill of this fight.
    def.items={'ITEM_019'}
   end)
   local offHook=api.hooks:wrap('battle.enemy_switch_or_item',function(next,current)
    calls=calls+1;selected=next(current);return selected
   end)
   f.stack.states={f.world,battle};battle:enter()
   T.eq(events,1,'actual native entry emits battle.started once')
   battle.enemy.mon.stats.hp=400;battle.enemy.mon.hp=10;battle.enemy.shownHP=10
   battle:enemyAction(battle.enemy)
   T.eq(calls,1,'actual native controller invokes registered trainer hook')
   if empty then
    T.eq(selected,false,'empty initial bag stays empty after entry observer edits')
   else
    T.eq(type(selected),'table','native original item action selected')
    T.eq(type(selected)=='table'and selected.item,13,'original Potion survives entry observer edits')
   end
   local history=Items.history(battle)
   T.eq(history.count,empty and 0 or 1,'original entry stock count retained')
   if not empty then
    T.eq(history.slots[1].item,'ITEM_013','original entry item retained')
    T.eq(history.slots[1].spent,true,'native item selection spends original entry slot')
   end
   T.eq(def.items[1],'ITEM_019','content edit remains available to future fights')
   offEvent();offHook()
   local nextBattle=Native.newTrainer(game,'OPP_FIX_YOUNGSTER',1)
   f.stack.states={f.world,nextBattle};nextBattle:enter()
   local nextState=rawget(nextBattle,'_gen3TrainerItems')
   T.check(nextState and nextState.history,'unobserved native entry also captures stock')
   T.eq(nextState and nextState.history.slots[1].item,'ITEM_019','future fight receives the changed class item')
   T.check(nextState~=battle._gen3TrainerItems,'each native fight owns its stock')
   f.close()
  end
 end
end
-- The GBA history must not be installed on other generations.
for _,edition in ipairs({'red','crystal'})do
 local f=Fixture.boot(edition,3,'unified')
 local battle=Native.newTrainer(f.game,'OPP_FIX_YOUNGSTER',1)
 f.stack.states={f.world,battle};battle:enter()
 T.eq(rawget(battle,'_gen3TrainerItems'),nil,'older native entry keeps its original stock policy')
 f.close()
end
T.finish('native GBA trainer stock precedes battle.started observers')
