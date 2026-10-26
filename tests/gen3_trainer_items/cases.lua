-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local C = {}
function C.run(root, backend, version)
local Fixture=dofile(root..'/tests/charge_required/fixture.lua')
local definitions={
 {13,'POTION',{0,0,0,0,4,0,20},{heal=true,amount=20}},
 {19,'FULL RESTORE',{0,0,0,63,4,0,255},{heal=true,amount='all',cureAll=true}},
 {20,'MAX POTION',{0,0,0,0,4,0,255},{heal=true,amount='all'}},
 {23,'FULL HEAL',{0,0,0,63,0,0},{cureAll=true}},
 {500,'X ATTACK',{1,0,0,0,0,0},{battle=true}}, {501,'GUARD SPEC',{0,0,0,128,0,0},{mist=true}},
 -- Distinguish the first parameter from the later HP-looking parameter.
 {502,'MIXED HEAL',{0,0,0,0,7,0,1,2,50},{ev='attack',heal=true,amount=1}},
 {503,'UNRECOGNIZED',{0,0,0,0,0,0},{}},
}
local f=Fixture.new(root,backend,version,3,'unified',true,false,'portable_enemy_action',function(data)
 if backend=='gen1'then
  for _,row in ipairs(definitions)do data.gen3Items._byId[row[1]]={name=row[2],pocket='ITEMS',effect=row[3]}end
 else
  data.constants.generation=3;data.constants.gen3ItemEffects={}
  for _,row in ipairs(definitions)do
   local id=('ITEM_%03d'):format(row[1]);data.items[id]={id=id,index=row[1],name=row[2]}
   local record={bytes=row[3]};for k,v in pairs(row[4])do record[k]=v end
   data.constants.gen3ItemEffects[id]=record
  end
 end
end)
local Native,Host,Items,previous
if backend=='gen1'then
 Native=require('src.core.game3.battle.ai_items');Items=require('src.core.game3.items_data')
 previous=Items._byId;Items._byId=f.data.gen3Items._byId
else Host=require('src.battle.Gen3TrainerItems')end
local function key(id)return backend=='gen1'and id or('ITEM_%03d'):format(id)end
local copy=require('src.mods.Merge').deepCopy
local rows={}
local function fresh(opts)
 opts=opts or{}
 local b=f.fresh('TACKLE').battle
 local mons={b.enemy.mon}
 for i=2,opts.count or 1 do mons[i]=copy(mons[1])end
 for _,mon in ipairs(mons)do mon.hp=opts.hp or 10;mon.maxHp=400;mon.stats=mon.stats or{};mon.stats.hp=400 end
 local items={};for i,id in ipairs(opts.items or{13})do items[i]=key(id)end
 local players={b.player.mon,copy(b.player.mon)}
 if backend=='gen1'then
  if opts.double then
   b=require('src.core.game3.battle.state').new({wild=false,double=true,playerParty=players,foeParty=mons,foeHalf=opts.second and 1 or nil})
  end
  b.wild=false;b.foeParty=mons;b.trainerItems=items
 else
  b.kind='trainer';b.enemyParty=opts.second and{mons[1]}or mons;b.enemyIndex=1;b.trainer={name='FIRST',items=items}
  b:syncSides()
  if opts.double then
   f.game.save.party=players;b.playerParty=players;b.playerPartyIndices={1,2}
   b.double=true;b:sendOutSecondPair()
  end
  if opts.second then
   f.data.trainers.TEST_SECOND={name='SECOND',items={key(19)},parties={{{prebuilt=copy(mons[2])}}}}
   f.T.eq(b:addOpponentTrainer('TEST_SECOND'),true,'native second-trainer admission')
  end
 end
 local id=opts.right and 3 or 1
 local actor=backend=='gen1'and require('src.core.game3.battle.state').battler(b,id)or b:battlerAt(id)
 actor.mon.hp=opts.hp or 10;actor.mon.maxHp=400;actor.mon.stats=actor.mon.stats or{};actor.mon.stats.hp=400
 actor.mon.status=opts.status
 if backend=='gen1'then actor.status=opts.status;actor.confusionTurns=opts.confusion;actor.isFirstTurn=opts.later and 0 or 1;b.enemySide.expMistTurns=opts.mist or 0
 else actor.confusedTurns=opts.confusion;actor.turnsOut=opts.later and 1 or 0;b.sides[2].gen3MistTurns=opts.mist or 0 end
 return b,actor,id
end
local expected={
 ['quarter heal']={13,2,0,{0,0,0,0}}, ['no wasted potion']={0,0,0,{13,0,0,0}},
 ['raw max potion sentinel']={0,0,0,{20,0,0,0}}, ['full restore low HP']={19,1,0,{0,0,0,0}},
 ['full restore status alone']={0,0,0,{19,0,0,0}}, ['status and confusion flags']={23,3,17,{0,0,0,0}},
 ['toxic cure']={23,3,16,{0,0,0,0}}, ['X item first turn']={500,4,1,{0,0,0,0}},
 ['X item later turn']={0,0,0,{500,0,0,0}}, ['mist first turn']={501,5,0,{0,0,0,0}},
 ['mist already active']={0,0,0,{501,0,0,0}}, ['mixed HP parameter']={502,2,0,{0,0,0,0}},
 ['mixed HP threshold']={502,2,0,{0,0,0,0}},
 ['unrecognized stops bag scan']={0,0,0,{503,13,0,0}}, ['shared doubles right recipient']={13,2,0,{0,0,0,0}},
 ['two opponents share first bag']={13,2,0,{0,0,0,0}}, ['first available stock']={13,2,0,{0,13,13,0}},
 ['later stock locked by full bench']={0,0,0,{0,13,13,0}}, ['second stock unlocks']={13,2,0,{0,0,13,0}},
 ['third stock unlocks']={13,2,0,{0,0,0,0}}, ['right owner cannot invent second trainer stock']={0,0,0,{13,0,0,0}},
 ['right owner can reserve shared first trainer stock']={13,2,0,{0,0,0,0}}, ['spent shared stock stays spent']={0,0,0,{0,0,0,0}},
}
local function observe(label,b,actor,id,forced)
 local originalItems=backend=='gen1'and b.trainerItems or b.trainer.items
 local originalFirst=originalItems[1]
 if Host and label=='quarter heal'then
  local legacy=require('src.battle.TrainerAI').gen3ItemAction(b)
  f.T.check(legacy and legacy.item==key(13),'legacy native selector sees the same usable potion')
 end
 local action
 if backend=='gen1'then action=forced and Native.useStocked(b,id,forced)or not forced and Native.shouldUseItem(b,id)
 else action=forced and Host.stocked(b,actor,key(forced))or not forced and Host.choose(b,actor)end
 local stock={}
 if backend=='gen1' then local h=Native.history(b);for i=1,4 do stock[i]=h.items[i]or 0 end
 else
  local h=Host.history(b,assert(Host.context(b,actor)))
  for i=1,4 do local slot=h.slots[i];stock[i]=slot and not slot.spent and Host.itemNumber(b,slot.item)or 0 end
 end
 local item=action and(backend=='gen1'and action.item or Host.itemNumber(b,action.item))or 0
 local row={label=label,item=item,kind=action and action.aiItemType or 0,flags=action and action.aiItemFlags or 0,stock=stock}
 local want=assert(expected[label],'case has no independent expectation: '..label)
 f.T.eq(row.item,want[1],label..': item decision')
 f.T.eq(row.kind,want[2],label..': native AI item type')
 f.T.eq(row.flags,want[3],label..': native AI item flags')
 f.T.same(row.stock,want[4],label..': remaining opposing stock')
 f.T.eq(originalItems[1],originalFirst,label..': pristine trainer items stay unchanged')
 if Host and label=='quarter heal'then
  f.T.eq(require('src.battle.TrainerAI').gen3ItemAction(b),nil,'legacy selector observes the spent native stock')
 end
 rows[#rows+1]=row
 return action,row
end
local cases={
 {'quarter heal',{}}, {'no wasted potion',{hp=390}}, {'raw max potion sentinel',{items={20},hp=200}},
 {'full restore low HP',{items={19}}}, {'full restore status alone',{items={19},hp=400,status='PSN'}},
 {'status and confusion flags',{items={23},hp=400,status='PSN',confusion=3}},
 {'toxic cure',{items={23},hp=400,status='TOX'}}, {'X item first turn',{items={500},hp=400}},
 {'X item later turn',{items={500},hp=400,later=true}}, {'mist first turn',{items={501},hp=400}},
 {'mist already active',{items={501},hp=400,mist=2}}, {'mixed HP parameter',{items={502},hp=345}},
 {'mixed HP threshold',{items={502},hp=390}},
 {'unrecognized stops bag scan',{items={503,13}}}, {'shared doubles right recipient',{double=true,right=true,count=2}},
 {'two opponents share first bag',{double=true,right=true,second=true,count=2}},
}
for _,case in ipairs(cases)do local b,actor,id=fresh(case[2]);observe(case[1],b,actor,id)end
do
 local b,actor,id=fresh({items={13,13,13},count=6})
 local action=observe('first available stock',b,actor,id)
 observe('later stock locked by full bench',b,actor,id)
 local party=backend=='gen1'and b.foeParty or b.enemyParty
 for i=4,6 do party[i].hp=0 end
 observe('second stock unlocks',b,actor,id)
 party[3].hp=0;observe('third stock unlocks',b,actor,id)
end
do
 local b,actor,id=fresh({double=true,right=true,second=true,count=2})
 observe('right owner cannot invent second trainer stock',b,actor,id,19)
 observe('right owner can reserve shared first trainer stock',b,actor,id,13)
 observe('spent shared stock stays spent',b,actor,id,13)
end
if Items then Items._byId=previous end
f.close()
return rows, f.T
end
return C
