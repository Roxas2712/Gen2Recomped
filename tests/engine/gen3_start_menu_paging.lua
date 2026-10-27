-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Menu=require('src.ui.Gen3StartMenu')
local Font=require('src.render.Font')
local Save=require('src.core.SaveSerializer')
local Source=require('src.ui.game3.start_menu')
local saved={Font.drawBox,Font.draw,Font.drawCode,Font.width,Font.glyphHeight}
local labels,box,cursor={}
love.math=love.math or{};love.math.getRandomState=love.math.getRandomState or function()return'unchanged'end
Font.drawBox=function(...)box={...}end
Font.draw=function(label,x,y)labels[#labels+1]={label,x,y}end
Font.drawCode=function(_,x,y)cursor={x,y}end
Font.width=function(text)return #text*6 end
Font.glyphHeight=function()return 15 end
for _,edition in ipairs{'ruby','sapphire','emerald','firered','leafgreen'}do
  require('src.core.GameVersion').set(edition)
  local game={data={constants={},field={boot={}},pokemon={}},save={party={},options={},flags={},player={name='TEST'}},input={edges={}}}
  function game.input:wasPressed(key)return self.edges[key]end
  game.stack=setmetatable({},{__index=require('src.core.StateStack')});game.stack:init()
  local world={};game.stack:push(world)
  local frlg=edition=='firered'or edition=='leafgreen'
  game.data.constants.gen3StartMenu={layout=frlg and'frlg'or'rse'}
  local menu=Menu.new(game);game.stack:push(menu)
  local chosen={};menu.rows={}
  for i=1,13 do
    local id='custom_'..i
    menu.rows[i]={id=id,key=id,label=('ROW%02d'):format(i),onSelect=function(_,row)chosen[#chosen+1]=row.id end}
  end
  local bytes=Save.encode(game.save);local rng=love.math.getRandomState()
  local function press(key)
    game.input.edges={[key]=true};menu:update(1/60);game.input.edges={}
  end
  for pass=1,2 do for index=1,#menu.rows do
    T.eq(menu.index,index)
    labels={};menu:draw()
    local first,last=menu:visibleRange()
    T.eq(#labels,last-first+1);T.check(#labels<=8)
    T.check(first<=index and index<=last)
    T.check(box[1]>=0 and box[2]>=0)
    T.check((box[1]+box[3])*8<=240 and(box[2]+box[4])*8<=160)
    for n,row in ipairs(labels)do
      T.eq(row[1],menu.rows[first+n-1].label)
      T.check(row[2]>=0 and row[2]<240)
      T.check(row[3]>=0 and row[3]+Font.glyphHeight()<=160)
    end
    T.check(cursor[2]>=labels[1][3] and cursor[2]<=labels[#labels][3])
    press('a');T.eq(chosen[#chosen],menu.rows[index].id)
    press('down')
  end end
  press('up');T.eq(menu.index,13);T.eq(select(2,menu:visibleRange()),13)
  press('down');T.eq(menu.index,1);T.eq(menu:visibleRange(),1)
  -- A smaller valid source rectangle must page its rows too.
  local template=Source.contentTemplate
  Source.contentTemplate=function()return{left=2,top=2,width=12,height=4}end
  menu.index=10;labels={};menu:draw()
  T.check(#labels<=2);T.eq(labels[#labels][1],'ROW10')
  Source.contentTemplate=template
  local base=menu:nativeContentTemplate()
  for _,bad in ipairs{{left=1,top=2,width=12,height=18},{left=0,top=1,width=8,height=4},{left=28,top=1,width=2,height=4}}do
    Source.contentTemplate=function()return bad end
    local tpl=menu:contentTemplate();T.eq(tpl.left,base.left);T.eq(tpl.height,base.height)
  end
  Source.contentTemplate=template
  T.eq(Save.encode(game.save),bytes,'opening, paging, drawing and callbacks preserve the save')
  T.eq(love.math.getRandomState(),rng,'menu paging never draws gameplay randomness')
  menu.rows={menu.rows[1]};menu.index=1;labels={};menu:draw();T.eq(#labels,1)
  menu.rows={};menu.index=1;T.eq(menu:visibleRange(),1);T.eq(select(2,menu:visibleRange()),0)
  press('a');T.eq(game.stack:top(),world)
end
Font.drawBox,Font.draw,Font.drawCode,Font.width,Font.glyphHeight=unpack(saved)
T.finish('five-edition START paging, bounds, wrap and stable custom callbacks')
