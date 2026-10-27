love=require('tests.love_stub')
local V=require('src.core.GameVersion');V.set('ruby')
local T=require('src.inventory.Gen3RsShopTransaction');local S=require('src.core.SaveSerializer')
local n=0;local function eq(a,b,why)n=n+1;assert(a==b,why or tostring(a)..' != '..tostring(b))end
local game={data={constants={gen=3,gen3Bag={pockets={BALL=2,ITEM=1}}},items={
  POKE_BALL={index=4,pocket='BALL',price=200},PREMIER_BALL={index=12,pocket='BALL',price=200},
  GREAT_BALL={index=3,pocket='BALL',price=600},POTION={index=13,pocket='ITEM',price=300}}},
  save={money=10000,inventory={POKE_BALL=2},bagOrder={'POKE_BALL'},unrelated={keep=true}}}
local t=T.new(game);local inv,order=game.save.inventory,game.save.bagOrder
eq(t:number('POKE_BALL'),4);eq(t:row(4).id,'POKE_BALL');eq(t:count(4),2)
local before=S.encode(game.save);eq(t:canAdd(12,1),true);eq(before,S.encode(game.save),'Capacity probe is read-only')
eq(t:add(4,97),true);eq(t:count(4),99);eq(t:canAdd(4,1),false);eq(t:add(4,1),false)
eq(t:add(12,1),true);eq(t:canAdd(3,1),false);eq(t:add(3,1),false)
eq(t:remove(4,100),false);eq(t:count(4),99);eq(t:remove(4,98),true);eq(t:count(4),1)
eq(t:remove(4,1),true);eq(t:count(4),0);eq(order[1],'PREMIER_BALL')
eq(game.save.inventory,inv);eq(game.save.bagOrder,order)
eq(t.session.money,10000);t.session.money=8000;eq(game.save.money,8000)
eq(t.session.gameStats,nil);t.session.gameStats={};t.session.gameStats[38]=1;eq(game.save.gen3Stats[38],1)
local b=t:bindings();eq(b.get(t.token,12),1);eq(b.canAdd(t.token,4,10),true)
eq(b.add(t.token,4,10),true);eq(b.remove(t.token,4,2),true);eq(t:count(4),8)
eq(pcall(b.get,{},4),false,'Reject mixed native bag token')
eq(pcall(t.row,t,999),false,'Unknown numeric IDs cannot become bag keys')
eq(game.save.unrelated.keep,true)
for id in pairs(game.save.inventory)do eq(type(id),'string','Host bag keys remain stable IDs')end
local UI=require('src.ui.Gen3RsShop');game.data.constants.gen3RsShop={format=1,version='ruby'}
eq(UI.available(game,{stock={'POKE_BALL'}}),true)
game.data.items.MOD_ITEM={name='CUSTOM',price=42,pocket='ITEM'}
eq(UI.available(game,{stock={'MOD_ITEM'}}),false,'Custom items without native numeric IDs keep the host menu')
game.data.items.MOD_ITEM.index=4
eq(UI.available(game,{stock={'POKE_BALL'}}),false,'Duplicate mod numeric aliases keep stable host IDs')
V.set('leafgreen');eq(UI.available(game,{stock={'POKE_BALL'}}),false,'Other editions keep their current host UI')
print('RS_SHOP_TRANSACTION_CHECKS',n)
