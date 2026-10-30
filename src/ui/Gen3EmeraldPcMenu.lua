-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Native Emerald PC windows around the host's existing menu/result owner.
local M={}
function M.available(game)
 local c=game and game.data and game.data.constants or{}
 local text=game and game.data and game.data.text or{}
 return require('src.core.GameVersion').get()=='emerald'
  and c.gen3EmeraldCredits and c.gen3EmeraldHall and c.gen3EmeraldPresentation
  and type(c.gen3EmeraldPresentation.songIds)=='table'
  and type(c.gen3EmeraldPresentation.songIds.SE_SELECT)=='number'
  and type(text.TEXT_27266F)=='string'and type(text.TEXT_5E8D80)=='string'
end
function M.decorate(menu,game,mode)
 if not M.available(game)then return menu end
 assert(mode=='player'or mode=='storage'or mode=='root')
 local c=game.data.constants;local root=require('src.import.Gen3EmeraldHallAssets').ROOT
 -- The pinned module also imports its text API. This presenter supplies all
 -- labels/status strings from the host; its native transaction paths stay idle.
 local context=require('src.ui.Gen3EmeraldSceneContext').new(game,{textIR={},ui={frames={
  manifest=c.gen3EmeraldHall.manifest,userCount=20,user=root..'frame_%d.rgba',std='user',sign=false,
  dialogue={path=root..'message_box.rgba',layout='message_box',manifestKey='message_box'},
  dialogueWindow={left=2,top=15,width=26,height=4}}},bindings={['src.core.game3.storage']={}}})
 local ui=context.load('src.ui.game3.rse.player_pc')
 context.load('src.ui.game3.chrome').setFrameType(math.max(0,math.min(19,((game.save.options or{}).gen3Frame or 1)-1)))
 local owner={canvas=context.canvas,load=context.load};menu.emeraldPcPresenter=owner
 menu.holdsUIAnchors=true
 local update=menu.update;menu.noSound=true
 function menu:update(dt)
  local input=game.input
  if input:wasPressed('up')or input:wasPressed('down')or input:wasPressed('a')
   or(self.cancelable and input:wasPressed('b'))then
   require('src.core.Sound').playId(game.data,c.gen3EmeraldPresentation.songIds.SE_SELECT)
  end
  return update(self,dt)
 end
 function menu:uiSize()return 240,160 end
 function menu:wantsFillScale()return true end
 function menu:wantsEdgeBleed()return false end
 function menu:sgbPalettes()return{require('src.render.PaletteFX').trueColorZone(0,0,29,19)}end
 function menu:draw()
  if self.hidden then return end
  local above=false
  for _,state in ipairs(game.stack.states)do
   if above and state.emeraldPcPresenter then return end
   if state==self then above=true end
  end
  local labels={};for i,row in ipairs(self.items)do labels[i]=row.label end
  local status=mode=='root'and game.data.text.TEXT_27266F or game.data.text.TEXT_5E8D80
  if mode=='storage'then status=(self.items[self.index]or{}).describe or status end
  local g=love.graphics
  local ok,why=require('src.render.GraphicsScope').call(function()
   g.setCanvas(owner.canvas);g.origin();g.setScissor();g.setShader();g.clear(0,0,0,0)
   ui.drawMenu(labels,self.index,#labels*2)
   ui.drawStatus({_session={version='emerald'},_status=status})
  end)
  if not ok then error(why,0)end
  g.setColor(1,1,1,1);g.draw(owner.canvas,0,0)
 end
 local exit=menu.exit
 function menu:exit()
  if exit then exit(self)end
  if owner.canvas then owner.canvas:release();owner.canvas=nil end
  owner.load=nil
 end
 return menu
end
return M
