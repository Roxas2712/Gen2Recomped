-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Original-result identity semantics through each engine's actual SDK callback boundary.
package.path='./?.lua;./?/init.lua;'..package.path
local C={}
function C.run(root,backend,version,api,format)
local f=dofile(root..'/tests/charge_required/fixture.lua').new(root,backend,version,api,format,false,false,'portable_enemy_action',function(data)
 if backend=='gen1' then
  data.gen3Items._byId[13]={name='POTION',pocket='ITEMS',effect={0,0,0,0,4,0,20}}
  data.gen3Items._byId[19]={name='FULL RESTORE',pocket='ITEMS',effect={0,0,0,63,4,0,255}}
 else
  data.constants.generation=3;data.constants.gen3ItemEffects={};data.items={}
  for _,row in ipairs({{13,'POTION',{0,0,0,0,4,0,20}},{19,'FULL RESTORE',{0,0,0,63,4,0,255}}})do
   local key=('ITEM_%03d'):format(row[1]);data.items[key]={id=key,index=row[1],name=row[2]};data.constants.gen3ItemEffects[key]={bytes=row[3]}
  end
 end
end,function(files)
 local key='mods/portable_enemy_action/main.lua';files[key]=assert(files[key]):gsub('battle%.enemy_action','battle.enemy_switch_or_item')
end)
local ItemsData,previous,Ai,Adapter,Items,Decision
if backend=='gen1' then
 ItemsData=require('src.core.game3.items_data');previous=ItemsData._byId;ItemsData._byId=f.data.gen3Items._byId
 Ai,Adapter,Items=require('src.core.game3.battle.ai'),require('src.core.game3.battle.adapter'),require('src.core.game3.battle.ai_items')
else Items=require('src.battle.Gen3TrainerItems');Decision=require('src.battle.Gen3TrainerDecision') end
local copy=require('src.mods.Merge').deepCopy
local rows={}
local cases={
 {'original identity',function(n,b)return n(b)end,{}},
 {'original unstocked item',function(n,b)local a=n(b);a.item=19;return a end,{item=19}},
 {'original portable item string',function(n,b)local a=n(b);a.item='POTION';return a end,{item='POTION'}},
 {'original actor redirect',function(n,b)local a=n(b);a.battler=0;a.target=0;return a end,{battler=0,target=0}},
 {'original kind mutation',function(n,b)local a=n(b);a.kind='custom';return a end,{kind='custom'}},
 {'original absent item',function(n,b)local a=n(b);a.item=nil;return a end,{item=false}},
 {'original classification mutation',function(n,b)local a=n(b);a.aiItemType=6;a.aiItemFlags=123;return a end,{itemType=6,itemFlags=123}},
 {'copied result needs fresh stock',function(n,b)return copy(n(b))end,{kind='none',item=false,battler=false,target=false,itemType=false,itemFlags=false}},
 {'mutation followed by true',function(n,b)local a=n(b);a.item=19;return true end,{item=19}},
 {'mutation followed by failure',function(n,b)local a=n(b);a.item=19;error('intentional error after original mutation')end,{item=19}},
 {'two continuations exhaust one slot',function(n,b)local a=n(b);n(b);return a end,{kind='none',item=false,battler=false,target=false,itemType=false,itemFlags=false,continuations=2}},
 {'first result after second continuation',function(n,b)local a=n(b);n(b);return a end,{continuations=2,stock2=0,stock3=0},true},
 {'true keeps last continuation',function(n,b)n(b);n(b);return true end,{continuations=2,stock2=0,stock3=13},true},
 {'true without continuation',function()return true end,{kind='none',item=false,battler=false,target=false,itemType=false,itemFlags=false,stock1=13,continuations=0}},
 {'false without continuation',function()return false end,{kind='none',item=false,battler=false,target=false,itemType=false,itemFlags=false,stock1=13,continuations=0}},
 {'nil without continuation',function()end,{kind='none',item=false,battler=false,target=false,itemType=false,itemFlags=false,stock1=13,continuations=0}},
 {'false after continuation',function(n,b)n(b);return false end,{kind='none',item=false,battler=false,target=false,itemType=false,itemFlags=false}},
 {'nil after continuation',function(n,b)n(b)end,{kind='none',item=false,battler=false,target=false,itemType=false,itemFlags=false}},
 {'fresh numeric item',function()return{kind='item',item=13}end,{continuations=0}},
 {'fresh portable item',function()return{kind='item',item='POTION'}end,{continuations=0}},
 {'fresh unstocked item',function()return{kind='item',item=19}end,{kind='none',item=false,battler=false,target=false,itemType=false,itemFlags=false,stock1=13,continuations=0}},
 {'fresh spent item',function(n,b)n(b);return{kind='item',item=13}end,{kind='none',item=false,battler=false,target=false,itemType=false,itemFlags=false}},
 {'active switch rejected',function()return{kind='switch',index=1}end,{kind='none',item=false,battler=false,target=false,itemType=false,itemFlags=false,stock1=13,continuations=0}},
 {'fainted switch rejected',function()return{kind='switch',index=2}end,{kind='none',item=false,battler=false,target=false,itemType=false,itemFlags=false,stock1=13,continuations=0}},
 {'healthy switch',function()return{kind='switch',index=2}end,{kind='switch',slot=2,item=false,target=false,itemType=false,itemFlags=false,stock1=13,continuations=0},false,true},
 {'fractional healthy switch',function()return{kind='switch',index=2.5}end,{kind='switch',slot=2,item=false,target=false,itemType=false,itemFlags=false,stock1=13,continuations=0},false,true},
 {'numeric string healthy switch',function()return{kind='switch',slot='2.5'}end,{kind='switch',slot=2,item=false,target=false,itemType=false,itemFlags=false,stock1=13,continuations=0},false,true},
 {'failure before continuation',function()error('intentional error before next')end,{continuations=0}},
 {'original changed into switch',function(n,b)local a=n(b);a.kind='switch';a.slot=2;return a end,{kind='switch',slot=2},false,true},
 {'fresh switch after item selection',function(n,b)n(b);return{kind='switch',index=2}end,{kind='switch',slot=2,item=false,target=false,itemType=false,itemFlags=false},false,true},
}
for _,case in ipairs(cases)do
 local label,choice,want,three,bench=unpack(case)
 local b=f.fresh('TACKLE').battle;b.enemy.mon.hp=10
 if backend=='gen1' then
  b.wild=false;b.trainerItems=three and{13,13,13}or{13}
  b.foeParty[2]=copy(b.enemy.mon);b.foeParty[2].hp=bench and 400 or 0
 else
  b.kind='trainer';b.trainer={items=three and{'ITEM_013','ITEM_013','ITEM_013'}or{'ITEM_013'}}
  b.enemyParty={b.enemy.mon,copy(b.enemy.mon)};b.enemyParty[2].hp=bench and 400 or 0;b:syncSides()
 end
 local continuations,calls=0,0
 f.e.choose(function(nextAction,...)
  calls=calls+1;f.T.eq(select('#',...),1,label..': exactly one battle argument')
  f.T.eq((...),b,label..': native battle identity retained')
  return choice(function(...)continuations=continuations+1;return nextAction(...)end,...)
 end)
 local action
 local stock={}
 if backend=='gen1' then
  action=Ai.switchOrItem(b,Adapter.new(b),1,function(lo)return lo or 0 end)
  stock=Items.history(b).items
 else
  action=Decision.call(b,b.enemy)
  for index,slot in ipairs(Items.history(b,Items.context(b,b.enemy)).slots)do stock[index]=not slot.spent and Items.itemNumber(b,slot.item)or 0 end
 end
 local row={label=label,kind=action and action.kind or'none',item=action and action.item or false,
  battler=action and action.battler or false,target=action and action.target or false,slot=action and action.slot or false,
  itemType=action and action.aiItemType or false,itemFlags=action and action.aiItemFlags or false,
  stock1=stock[1]or 0,stock2=stock[2]or 0,stock3=stock[3]or 0,continuations=continuations}
 local expected={label=label,kind='item',item=13,battler=1,target=1,slot=false,itemType=2,itemFlags=0,stock1=0,
  stock2=three and 13 or 0,stock3=three and 13 or 0,continuations=1}
 for k,v in pairs(want)do expected[k]=v end
 -- API 3 memoizes its public continuation. Older native/API2 wrappers
 -- really re-enter the producer, so their stock/identity outcomes differ.
 if api>=3 and expected.continuations==2 then
  expected.kind,expected.item,expected.battler,expected.target='item',13,1,1
  expected.itemType,expected.itemFlags=2,0
  expected.stock2,expected.stock3=three and 13 or 0,three and 13 or 0
 end
 f.T.eq(calls,1,label..': one native hook call');f.T.same(row,expected,label..': expected original-result semantics')
 rows[#rows+1]=row
end
if ItemsData then ItemsData._byId=previous end
f.close()
return rows,f.T
end
return C
