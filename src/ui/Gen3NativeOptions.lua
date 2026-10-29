-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Original Emerald and FR/LG controllers over the shared host option fields.
local Base=require('src.ui.Gen3RsOptions')
local M=setmetatable({},{__index=Base});M.__index=M
function M.record(game)
 local version=require('src.core.GameVersion').get()
 local spec=game and game.data and game.data.constants and game.data.constants.gen3NativeOptions
 if require('src.import.Gen3NativeOptionsAssets').valid(spec,version)then return spec end
end
function M.new(owner,spec)
 local game=owner.game;local version=spec.version;local Values=require('src.core.Gen3RsOptionValues')
 local options=game.save.options or{};game.save.options=options
 local self=setmetatable({owner=owner,game=game,record=spec},M)
 local function read()
  local values=Values.read(options);values.frameType=math.min(values.frameType,spec.frameCount-1);return values
 end
 local proxy={options=options}
 function proxy:writeOptions()
  if game.applyOptions then game:applyOptions(options)end
  return require('src.core.SaveData').saveOptions(options)
 end
 local session={version=version};local opened=false
 local bindings={
  ['src.core.game3.options']={engine=function()return options end,bind=read,
   block=read,set=function(_,key,value)Values.set(options,key,value)end},
  ['src.ui.game3.shaderfx_menu']={isOpen=function()return false end,close=function()end,update=function()end},
  ['src.ui.game3.stack']={push=function(id)assert(id=='option');opened=true end,pop=function(id)
   assert(id=='option'and game.stack:top()==owner);opened=false;owner:close()
  end},
  ['src.ui.game3.screens']={openFlag=function()return function()return opened end end,redirect=function()end},
 }
 local function withCart(native,category)return require('src.ui.Gen3OptionRows').withCart(owner,native,category)end
 bindings['src.ui.game3.option_rows']={withCart=function(_,native,category)return withCart(native,category)end}
 if version=='emerald'then
  local root=require('src.import.Gen3EmeraldHallAssets').ROOT
  local ui={frames={manifest=game.data.constants.gen3EmeraldHall.manifest,userCount=20,user=root..'frame_%d.rgba',std='user',sign=false,
   dialogue={path=root..'message_box.rgba',layout='message_box',manifestKey='message_box'},dialogueWindow={left=2,top=15,width=26,height=4}}}
  local context=require('src.ui.Gen3EmeraldSceneContext').new(game,{ui=ui,textIR=spec.textIR,bindings=bindings,
   packageLoaded={['src.core.game3.runtime']={_game=proxy}}})
  self.load,self.canvas=context.load,context.canvas
  self.load('src.ui.game3.rse.bag_chrome').manifest=function()return{sprites={arrows=spec.arrow}}end
 else
  local common=require('src.ui.Gen3FrlgSceneBindings').new(game,session,{_game=proxy,session=session})
  for key,value in pairs(bindings)do common[key]=value end
  local text={}
  function text.ir(key)return assert(spec.textIR[key],'Missing native option label '..key)end
  function text.plain(key,ctx)return self.load('src.core.game3.scripting.text_ir').toAscii(text.ir(key),ctx)end
  function text.at(key,index)assert(key=='sOptionMenuItemsNames'and index==6);return text.plain('gText_OptionMenuCancel')end
  common['src.core.game3.rom_text']=text
  -- The reference help bar only needs this font operation, not the live dex.
  common['src.ui.game3.pokedex_chrome']={drawControlInfo=function(str,right,y)
   local font=self.load('src.ui.game3.frlg_font');local small={small=true}
   font.draw(str,(right or 236)-font.measure(str,small),y or 146,
    {small=true,colors={fg={1,1,1,1},shadow={98/255,98/255,98/255,1}}})
  end}
  common['src.ui.game3.option_rows']={build=function()return{}end,group=function(_,category)
   local native={};local definitions=require('src.import.Gen3NativeOptionsAssets').rows
   for _,def in ipairs(definitions)do
    local key=def[1];local choices={};for i=3,#def do choices[#choices+1]=def[i]end
    if key=='buttonMode'then choices={'gText_ButtonTypeHelp','gText_ButtonTypeLR','gText_ButtonTypeLEqualsA'}end
    local count=key=='frameType'and 10 or#choices
    native[key]={id=key,label=text.plain(def[2]),value=function()
     local n=read()[key]
     if key=='frameType'then return text.plain('gText_FrameType')..('%2d'):format(n+1)end
     return text.plain(assert(choices[n+1]))
    end,step=function(_,dir)
     local n=(read()[key]+dir)%count;Values.set(options,key,n)
     if key=='frameType'then self.load('src.ui.game3.chrome').setFrameType(n)end
     return true
    end}
   end
   return withCart(native,category)
  end}
  self.load=require('compat.gen1-rs.Loader').new(version,common)
  self.canvas=love.graphics.newCanvas(240,160,{dpiscale=1});self.canvas:setFilter('nearest','nearest')
 end
 local audio=self.load('src.core.game3.audio')
 audio.applyOptions=function()return require('src.core.Sound').applyOptions(options,game.data)end
 self.load('src.ui.game3.chrome').setFrameType(math.max(0,math.min(spec.frameCount-1,(options.gen3Frame or 1)-1)))
 self.scene=self.load(version=='emerald'and'src.ui.game3.rse.option_menu'or'src.ui.game3.option_menu')
 self.scene.show({session=session,game=proxy})
 return self
end
return M
