-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local V=require('src.core.GameVersion')
local Context=require('src.ui.Gen3EmeraldSceneContext');local UI=require('src.ui.Gen3EmeraldPcMenu')
local Menu=require('src.ui.Menu');local S=require('src.core.SaveSerializer')
local Sound=require('src.core.Sound');local oldV,oldContext,oldPlay=V.get(),Context.new,Sound.playId
local sounds=0;Sound.playId=function(_,id)T.eq(id,5,'native Emerald cursor cue');sounds=sounds+1 end
local draws,statuses,releases,frame={}, {},0,nil
local native={drawMenu=function(labels,index,height)draws[#draws+1]={labels=labels,index=index,height=height}end,
 drawStatus=function(pc)statuses[#statuses+1]=pc._status end}
Context.new=function(game,opts)
 T.eq(type(opts.textIR),'table','native PC text dependency is explicitly bound')
 T.eq(opts.ui.frames.dialogueWindow.left,2,'original dialogue left')
 T.eq(opts.ui.frames.dialogueWindow.width,26,'original dialogue width')
 return{canvas={release=function()releases=releases+1 end},load=function(id)
  if id=='src.ui.game3.rse.player_pc'then return native end
  assert(id=='src.ui.game3.chrome');return{setFrameType=function(n)frame=n end}
 end}
end
local game={data={constants={gen3EmeraldCredits={},gen3EmeraldHall={manifest='OWN'},gen3EmeraldPresentation={songIds={SE_SELECT=5}}},
 text={TEXT_27266F='Which PC?',TEXT_5E8D80='What now?'}},save={options={gen3Frame=20},inventory={POTION=3}},
 input={pressed={}},stack={states={}}}
function game.input:wasPressed(key)return self.pressed[key]end
function game.stack:pop()local state=table.remove(self.states);if state.exit then state:exit()end;return state end
local called=0;local rows={{label='STORAGE',describe='Withdraw description',onSelect=function()called=called+1 end},
 {label='CANCEL',describe='Return description'}}
V.set('emerald');local menu=Menu.new(game,rows,{noSound=true});local update=menu.update
T.eq(UI.decorate(menu,game,'player'),menu,'decorate the actual host menu')
T.eq(menu.items,rows,'preserve original rows and callbacks')
T.eq(frame,19,'native twenty-frame option remains zero-based')
game.stack.states={menu};local raw=S.encode(game.save);menu:draw()
T.eq(draws[1].height,4,'two native rows use four tiles inside the frame')
T.eq(statuses[1],'What now?','player PC uses its original question');T.eq(raw,S.encode(game.save),'drawing preserves inventory and options')
local child=Menu.new(game,rows,{noSound=true});UI.decorate(child,game,'storage');game.stack.states={menu,child}
menu:draw();T.eq(#draws,1,'covered native PC parent does not paint a second menu')
child.index=2;child:draw();T.eq(statuses[#statuses],'Return description','description follows host highlighted row')
child.hidden=true;child:draw();T.eq(#draws,2,'item-storage child can hide its parent menu');child.hidden=nil
child:exit();game.stack.states={menu};menu:draw();T.eq(#draws,3,'closing child restores parent drawing')
game.input.pressed={a=true};menu:update(1/60);T.eq(called,1,'ordinary A invokes existing callback once')
T.eq(sounds,1,'acknowledgment plays exactly one original menu cue')
T.eq(releases,2,'both popped/closed menus release only their own canvases')
local root=Menu.new(game,rows,{noSound=true});UI.decorate(root,game,'root');game.stack.states={root};root:draw()
T.eq(statuses[#statuses],'Which PC?','root menu retains its separate cartridge question');root:exit()
for _,v in ipairs{'ruby','sapphire','firered','leafgreen','gold'}do
 V.set(v);local other=Menu.new(game,rows,{});local draw=other.draw
 T.eq(UI.decorate(other,game,'player'),other);T.eq(other.draw,draw,v..' renderer remains unchanged')
end
V.set('emerald');game.data.text.TEXT_5E8D80=nil
local legacy=Menu.new(game,rows,{});local draw=legacy.draw;UI.decorate(legacy,game,'player')
T.eq(legacy.draw,draw,'incomplete old caches retain their existing menu')
Context.new=oldContext;Sound.playId=oldPlay;V.set(oldV);T.finish('Native Emerald PC menu composition and original callbacks')
