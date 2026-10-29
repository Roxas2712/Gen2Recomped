-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local Menu=require('src.ui.Gen3BagMenu')
local S=require('src.core.SaveSerializer');local V=require('src.core.GameVersion')
local Sound=require('src.core.Sound');local Text=require('src.render.TextBox')
local oldV,oldPlay,oldText=V.get(),Sound.play,Text.new
Sound.play=function()end
local confirmation
Text.new=function(_,_,_,opts)confirmation=opts;return{}end
for _,version in ipairs{'emerald','firered','leafgreen'}do
 V.set(version)
 local current,answer,messages
 local game={data={constants={gen=3,gen3Bag={version=version,pockets={ITEM=30,BERRY=46}}},
  items={POTION={index=13,name='POTION',pocket='ITEM'}}},save={}}
 game.stack={push=function(_,state)current=state end}
 local owner=setmetatable({game=game,rows={{id='POTION',qty=10}},index=1},Menu)
 owner.askQuantity=function(_,_,_,_,done)answer=done end
 owner.rebuild=function()end;owner.tell=function()messages=messages+1 end
 local function reset()
  game.save={inventory={POTION=10},bagOrder={'POTION'},pcItems={POTION=12},unrelated='KEEP'}
  messages=0;confirmation=nil;answer=nil
 end
 local function unchanged(action,label)
  local before=S.encode(game.save);action();T.eq(S.encode(game.save),before,version..' '..label);T.eq(messages,0)
 end
 for _,qty in ipairs{0,-1,1.5,math.huge,13}do
  reset();owner:withdrawItem('POTION')
  unchanged(function()answer(qty,'POTION')end,'rejects invalid withdrawal quantity')
 end
 for _,change in ipairs{
  function()game.save.pcItems.POTION=1 end,
  function()game.save.pcItems.POTION=nil end,
  function()game.save.pcItems={POTION=12}end,
 }do
  reset();owner:withdrawItem('POTION');change()
  unchanged(function()answer(3,'POTION')end,'stale withdrawal cannot mint bag items')
 end
 reset();owner:withdrawItem('POTION');answer(3,'POTION')
 T.eq(game.save.inventory.POTION,13);T.eq(game.save.pcItems.POTION,9);T.eq(messages,1)
 reset();owner:depositItem('POTION');game.save.inventory.POTION=1
 unchanged(function()answer(3,'POTION')end,'stale deposit cannot mint PC goods')
 reset();owner:depositItem('POTION');answer(3,'POTION')
 T.eq(game.save.inventory.POTION,7);T.eq(game.save.pcItems.POTION,15);T.eq(messages,1)
 for _,change in ipairs{
  function()game.save.pcItems.POTION=1 end,
  function()game.save.pcItems.POTION=nil end,
  function()game.save.pcItems={POTION=12}end,
 }do
  reset();owner:tossStored('POTION');change()
  unchanged(function()answer(3,'POTION')end,'stale initial toss is refused')
  T.eq(confirmation,nil)
  reset();owner:tossStored('POTION');answer(3,'POTION');T.check(confirmation)
  change();unchanged(function()confirmation.choice(true)end,'toss rechecks the current PC at YES')
 end
 reset();owner:tossStored('POTION');answer(3,'POTION')
 unchanged(function()confirmation.choice(false)end,'NO preserves the PC')
 reset();owner:tossStored('POTION');answer(3,'POTION')
 confirmation.choice(true);T.eq(game.save.pcItems.POTION,9);T.eq(messages,1)
end
Text.new=oldText
-- Reach FRLG's separate withdrawal callback through the actual PC menu rows.
local Root=require('src.ui.Gen3PlayerPC');local Generic=require('src.ui.Menu')
local Qty=require('src.ui.Gen3ItemPcQuantity');local Message=require('src.ui.Gen3ItemPcMessage')
local oldMenu,oldQty,oldMessage=Generic.new,Qty.new,Message.new
Generic.new=function(_,rows)return{items=rows}end
for _,version in ipairs{'firered','leafgreen'}do
 V.set(version)
 for _,stale in ipairs{false,'partial','missing','replaced'}do
  local current,answer,messages=nil,nil,0
  local game={data={constants={gen=3,gen3Bag={version=version,pockets={ITEM=30}},
   gen3BagScreen={layout='frlg'}},items={POTION={index=13,name='POTION',pocket='ITEM'}}},
   save={inventory={},bagOrder={},pcItems={POTION=12}}}
  game.stack={push=function(_,state)current=state end}
  Qty.new=function(_,_,opts)answer=opts.onDone;return{}end
  Message.new=function()messages=messages+1;return{}end
  local root=Root.new(game);root.items[1].onSelect();current.items[1].onSelect()
  local pc=current;pc.onPick('POTION',pc)
  T.check(answer,version..' actual WITHDRAW route opens a quantity callback')
  if stale=='partial'then game.save.pcItems.POTION=1
  elseif stale=='missing'then game.save.pcItems.POTION=nil
  elseif stale=='replaced'then game.save.pcItems={POTION=12}end
  local before=S.encode(game.save);answer(3)
  if stale then
   T.eq(S.encode(game.save),before,version..' actual PC withdrawal rejects '..stale);T.eq(messages,0)
  else
   T.eq(game.save.inventory.POTION,3);T.eq(game.save.pcItems.POTION,9);T.eq(messages,1)
  end
 end
end
Generic.new=oldMenu;Qty.new=oldQty;Message.new=oldMessage
V.set(oldV);Sound.play=oldPlay
T.finish('GBA PC callbacks refuse stale stores before transferring or discarding items')
