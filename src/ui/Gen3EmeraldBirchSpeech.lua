-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Emerald's professor sequence completes before the truck field is created.
local M={};M.__index=M
M.isOpaque=true;M.holdsUIAnchors=true;M.screenId='Gen3EmeraldBirchSpeech'
local aliases={gBirchSpeech_Welcome='gText_Birch_Welcome',gBirchSpeech_ThisIsPokemon='gText_ThisIsAPokemon',
  gSystemText_NewPara='sText_NewParagraph',gBirchSpeech_WorldInhabitedByPokemon='gText_Birch_MainSpeech',
  gBirchSpeech_AndYouAre='gText_Birch_AndYouAre',gBirchSpeech_AreYouBoyOrGirl='gText_Birch_BoyOrGirl',
  gBirchSpeech_WhatsYourName='gText_Birch_WhatsYourName',gBirchSpeech_SoItsPlayer='gText_Birch_SoItsPlayer',
  gBirchSpeech_AhOkayYouArePlayer='gText_Birch_YourePlayer',gBirchSpeech_AreYouReady='gText_Birch_AreYouReady',
  gBirchText_Boy='gText_BirchBoy',gBirchText_Girl='gText_BirchGirl'}
function M.available(data,version)
  version=version or require('src.core.GameVersion').get()
  return version=='emerald'and data and require('src.import.Gen3EmeraldBirchAssets')
    .valid((data.constants or{}).gen3EmeraldBirch)or false
end
function M.new(game,opts)
  assert(M.available(game.data))
  local self=setmetatable({game=game},M)
  self.onDone=type(opts)=='function'and opts or type(opts)=='table'and opts.onDone
  local spec=game.data.constants.gen3EmeraldBirch
  self.naming=require('src.ui.Gen3EmeraldBirchNaming').new(game)
  local context
  local text={}
  function text.ir(key)return assert(spec.textIR[aliases[key]or key],'Missing own Emerald intro label '..key)end
  function text.plain(key,values)return context.load('src.core.game3.scripting.text_ir').toAscii(text.ir(key),values)end
  function text.at(key,index)
    assert(key=='gMenuYesNoItems'and(index==0 or index==1))
    return text.plain(index==0 and 'gText_Yes'or 'gText_No')
  end
  text.translate=function(value)return value end
  text.has=function(key)return spec.textIR[aliases[key]or key]~=nil end
  local songs=game.data.constants.gen3EmeraldPresentation.songIds
  local constants={of=function(version)
    assert(version=='emerald')
    return {require=function(_,family,key)assert(family=='songs');return assert(songs[key])end}
  end}
  -- Emerald uses the text selector glyph, not RS's segmented OAM bar.
  local cursor={draw=function(x,y,_,fx)
    local font=context.load('src.ui.game3.frlg_font')
    local kit=context.load('src.ui.game3.rse.scene_kit')
    context.load('src.core.game3.gba_fx').draw(function()
      font.drawGlyph(0xEF,x,y+1,{colors=kit.messageColors('std_menu')})
    end,fx)
  end}
  local hall=game.data.constants.gen3EmeraldHall
  local root=require('src.import.Gen3EmeraldHallAssets').ROOT
  local ui={frames={manifest=hall.manifest,userCount=20,user=root..'frame_%d.rgba',std='user',sign=false,
    dialogue={path=root..'message_box.rgba',layout='message_box',manifestKey='message_box'},
    dialogueWindow=spec.windows.dialogue,
    arrow={path=spec.arrow,delay=6,period=6,lastPage=false}}}
  context=require('src.ui.Gen3EmeraldSceneContext').new(game,{ui=ui,textIR=spec.textIR,
    bindings={['src.ui.game3.naming']=self.naming,['src.core.game3.rom_text']=text,
      ['src.core.game3.constants']=constants,['src.ui.game3.rs.menu_cursor']=cursor}})
  self.load,self.canvas=context.load,context.canvas
  local speed=(game.save.options or{}).textSpeed or 3
  self.scene=require('src.ui.Gen3EmeraldBirchScene').new(context,spec,{
    textSpeed=speed>=5 and 0 or speed>=3 and 1 or 2,
    frameType=math.max(0,((game.save.options or{}).gen3Frame or 1)-1)})
  return self
end
function M:enter()require('src.mods.Runtime').emit('intro.birch_speech.started',{speech=self})end
function M:uiSize()return 240,160 end
function M:wantsFillScale()return true end
function M:wantsEdgeBleed()return false end
function M:sgbPalettes()return {require('src.render.PaletteFX').trueColorZone(0,0,29,19)}end
function M:update(dt)
  local result=self.scene:update(self.game.input,dt)
  if type(result)~='table'then return end
  assert(result.action=='new_game'and result.fieldCallback=='truck')
  local player=self.game.save.player
  player.name=result.name;player.gender=result.gender==1 and 'girl'or 'boy'
  player.rival=result.gender==1 and 'BRENDAN'or 'MAY'
  require('src.mods.Runtime').emit('intro.birch_speech.finished',{
    speech=self,answers={name=player.name,gender=player.gender}})
  local done=self.onDone
  self.game.stack:pop()
  if done then done()end
end
function M:draw()
  local g=love.graphics
  local ok,why=require('src.render.GraphicsScope').call(function()
    g.setCanvas(self.canvas);g.origin();g.setScissor();g.setShader();g.clear(0,0,0,1)
    self.scene:draw()
  end)
  if not ok then error(why,0)end
  g.setColor(1,1,1,1);g.draw(self.canvas,0,0)
end
function M:exit()
  if self.scene then self.scene:destroy()end
  if self.canvas then self.canvas:release()end
  self.scene,self.load,self.canvas,self.naming=nil,nil,nil,nil
end
return M
