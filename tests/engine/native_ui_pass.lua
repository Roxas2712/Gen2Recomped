-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local initial=package.loaded['src.core.Game']
local Pass=require('src.ui.game3.ui_pass');local base=Pass.drawUi
T.eq(package.loaded['src.core.Game'],initial,'import cannot bootstrap another game')
T.eq(base(),false,'there is no independent UI draw loop')
local NativeGame=require('src.core.Game')
local R=require('src.render.Renderer');local G=require('src.core.Game3')
local g=love.graphics;R:init()
local function pack(...)return{n=select('#',...),...}end
for _,edition in ipairs{'firered','leafgreen','emerald','ruby','sapphire'}do
 local f=require('tools.battle-source-runtime.fixture').new(edition)
 local game=setmetatable(f.game,{__index=NativeGame});package.loaded['src.core.Game']=game
 local records={};local function mark(kind)
  records[#records+1]={kind=kind,target=g.getCanvas(),owner=G._callbackOwner()}
 end
 local world={isOverworld=true,isOpaque=true,uiSize=function()return 240,160 end,
  draw=function()mark('world')end}
 game.overworld=world;game.stack:push(world)
 local b=f.fresh('TACKLE').battle;b.enter=false;b.isOpaque=false
 b.draw=function()mark('battle')end;game.stack:push(b)
 local box=require('src.render.TextBox').new(game,'Native overlay')
 box.isOpaque=false
 local boxDraw=box.draw
 box.draw=function(self)mark('message');return boxDraw(self)end
 game.stack:push(box)
 local top={isOpaque=false,uiSize=function()return 240,160 end,
  draw=function()mark('top')end};game.stack:push(top)
 local function frame()
  records={};NativeGame._draw(game)
  local names={};for _,row in ipairs(records)do names[#names+1]=row.kind end
  return table.concat(names,',')
 end
 local before=b.frame;local expected='world,battle,message,top'
 package.loaded['src.ui.game3.ui_pass']=nil
 T.eq(frame(),expected,'module-absent native ordering')
 package.loaded['src.ui.game3.ui_pass']=Pass;Pass.drawUi=base
 T.eq(frame(),expected,'default module preserves native ordering')
 local callbacks=0
 Pass.drawUi=function()
  callbacks=callbacks+1;T.eq(select('#',base()),0);base()
  return false,nil,'borrowed UI return'
 end
 T.eq(frame(),expected);T.eq(callbacks,1,'contiguous native overlays share one UI pass')
 T.eq(b.frame,before,'UI drawing cannot advance battle rules')
 local hud=g.newCanvas(240,160)
 Pass.drawUi=function()g.setCanvas(hud);return base()end
 T.eq(frame(),expected)
 for i,row in ipairs(records)do T.eq(row.target,i<=2 and R.canvas or hud,
  row.kind..' retains the correct native or borrowed surface')end
 T.eq(g.getCanvas(),nil,'the ordinary native compositor still presents its frame')
 -- Explicit native scene-owner flags also protect custom battle/world
 -- states. Keep interleaved UI groups in their original draw order.
 game.stack:pop()
 local custom={isBattleState=true,isOpaque=false,uiSize=function()return 240,160 end,
  draw=function()mark('custom battle')end}
 game.stack:push(custom);game.stack:push(top);callbacks=0
 Pass.drawUi=function()callbacks=callbacks+1;g.setCanvas(hud);return base()end
 T.eq(frame(),'world,battle,message,custom battle,top');T.eq(callbacks,2)
 T.eq(records[3].target,hud);T.eq(records[4].target,R.canvas);T.eq(records[5].target,hud)
 game.stack:pop();game.stack:pop();game.stack:push(top)
 Pass.drawUi=function()return false end
 T.eq(frame(),'world,battle','holding UI cannot suppress world/battle painting')
 local depth=g.getStackDepth and g.getStackDepth()
 Pass.drawUi=function()g.push('all');g.setCanvas(hud);error('source UI failed')end
 T.raises(function()frame()end,'source UI failed')
 if depth then T.eq(g.getStackDepth(),depth,'leaked callback pushes are fenced')end
 T.eq(g.getCanvas(),R.canvas,'error returns to the native UI target')
 local nativeCalls=0;box.draw=function()nativeCalls=nativeCalls+1;error('native UI failed')end
 Pass.drawUi=function()pcall(base);return true end
 T.raises(function()frame()end,'native UI failed');T.eq(nativeCalls,1,'a swallowed native error cannot replay')
 box.draw=function(self)mark('message');return boxDraw(self)end
 local rejected
 Pass.drawUi=function()
  local saved=game.save;game.save={options={}}
  local a,why=base();rejected=why;game.save=saved;return a,why
 end
 T.eq(frame(),'world,battle');T.eq(rejected,'native UI pass cohort changed')
 Pass.drawUi=function()
  local index=#game.stack.states-1;local saved=game.stack.states[index]
  game.stack.states[index]={};local a,why=base();rejected=why;game.stack.states[index]=saved
  return a,why
 end
 T.eq(frame(),'world,battle');T.eq(rejected,'native UI pass cohort changed',
  'middle-state replacement is rejected even with unchanged depth/top')
 Pass.drawUi=function()
  game.stack:push({});local a,why=base();rejected=why;game.stack:pop();return a,why
 end
 T.eq(frame(),'world,battle');T.eq(rejected,'native UI pass cohort changed')
 local seams=require('src.mods.ModSeams');local owner=G._callbackOwner()
 Pass.drawUi=function()T.eq(G._callbackOwner(),'ui_pass_owner');return base()end
 seams._journal[#seams._journal+1]={tbl=Pass,key='drawUi',after=Pass.drawUi,owner='ui_pass_owner'}
 T.eq(frame(),expected)
 T.eq(records[1].owner,owner);T.eq(records[2].owner,owner)
 T.eq(records[3].owner,nil,'native drawers do not inherit the source callback owner')
 T.eq(records[4].owner,nil);T.eq(G._callbackOwner(),owner);table.remove(seams._journal)
 Pass.drawUi=function()base();return base()end
 local values=pack(Pass._nativeDrawUi(game,function()return nil,4,nil end))
 T.eq(values.n,3);T.eq(values[1],nil);T.eq(values[2],4);T.eq(values[3],nil)
 T.eq(base(),false,'retained base has no drawing phase after return')
 Pass.drawUi=base;game.stack:pop();game.stack:pop();game.stack:pop();game.stack:pop()
 if hud.release then hud:release()end;f.close();G.release()
end
-- Generation routing must not depend on whether the GBA UI module has been
-- imported or patched. Keep ordinary native frames in their own pipeline.
for _,edition in ipairs{'red','crystal','platinum','black'}do
 local f=require('tools.battle-source-runtime.fixture').new('firered')
 local game=setmetatable(f.game,{__index=NativeGame});package.loaded['src.core.Game']=game
 require('src.core.GameVersion').set(edition)
 local paints=0;game.stack:push({isOpaque=true,uiSize=function()return 160,144 end,
  draw=function()paints=paints+1 end})
 Pass.drawUi=function()error('GBA UI wrapper reached another generation')end
 NativeGame._draw(game);T.eq(paints,1,edition..' native frame')
 Pass._nativeDrawUi(game,function()paints=paints+1 end);T.eq(paints,2)
 Pass.drawUi=base;game.stack:pop();f.close();G.release()
end
package.loaded['src.core.Game']=initial;require('src.core.GameVersion').set('firered')
T.finish('native UI-only drawing, modal order, target borrowing and frame admission')
