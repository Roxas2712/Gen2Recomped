-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Original common Emerald rows; host slots, mod rows and callbacks stay owned.
local Rs=require('src.ui.Gen3RsMainMenu')
local M=setmetatable({},{__index=Rs});M.__index=M
local keys={continue='CONTINUE',newGame='NEW_GAME',option='OPTION',exit='EXIT'}
local labels={continue='CONTINUE',newGame='NEW GAME',option='OPTION',exit='EXIT GAME'}
function M.available(owner)
  if not require('src.import.Gen3EmeraldMainMenuAssets').valid(
    (owner.game.data.constants or{}).gen3EmeraldMainMenu,require('src.core.GameVersion').get())then return false end
  local seen={}
  for _,item in ipairs(owner.items)do
    if not keys[item.key]or seen[item.key]or item.onSelect
      or item.label~=require('src.core.Strings')(labels[item.key])then return false end
    seen[item.key]=true
  end
  return seen.newGame and seen.option and seen.exit or false
end
function M.snapshot(game,save)
  if type(save)~='table'then return nil end
  local load=require('compat.gen1-rs.Loader').new('emerald')
  local flags=load('src.core.game3.constants.emerald.flags').byName
  local vars=load('src.core.game3.constants.emerald.vars').byName
  local C={flag=function(_,name)return assert(flags[name])end,var=function(_,name)return assert(vars[name])end}
  local info=Rs.snapshot(game,save,C)
  local n=assert(flags.FLAG_SYS_POKEDEX_GET);local v=(save.flags or{})[n]
  if v==nil then v=(save.flags or{})[('FLAG_G3_%04X'):format(n)]end
  info.hasDex=v==true or v==1
  return info
end
function M.new(owner)
  assert(M.available(owner));local game=owner.game;local save
  for _,item in ipairs(owner.items)do if item.key=='continue'then
    save=require('src.core.SaveData').load('emerald');break
  end end
  local root=require('src.import.Gen3EmeraldHallAssets').ROOT
  local hall=game.data.constants.gen3EmeraldHall
  local ui={frames={manifest=hall.manifest,userCount=20,user=root..'frame_%d.rgba',std='user',sign=false,
    dialogue={path=root..'message_box.rgba',layout='message_box',manifestKey='message_box'},
    dialogueWindow={left=2,top=15,width=26,height=4}}}
  local self=setmetatable(require('src.ui.Gen3EmeraldSceneContext').new(game,{
    textIR=game.data.constants.gen3EmeraldMainMenu.textIR,ui=ui,bindings={
      -- The platform clock already supplies the host RTC without a cart battery.
      ['src.core.game3.rtc']={ERR={FLAG_MASK=255},errorStatus=function()return 0 end},
      ['src.core.game3.constants']={},['src.core.game3.scripting.flags']={},
      ['src.ui.game3.screens']={},['src.ui.game3.stack']={top=function()return nil end},
    }}),M)
  self.owner,self.saved=owner,save
  local info=M.snapshot(game,save)
  self.scene=self.load('src.ui.game3.rse.main_menu_rse').new({hasContinue=save~=nil,continueInfo=info,
    textSpeed=1})
  self.scene.items={}
  for _,item in ipairs(owner.items)do self.scene.items[#self.scene.items+1]=keys[item.key]end
  self.scene._openOptions=function(scene)
    self.waitingOptions=true;scene.state='host_options';owner:choose({key='option'})
  end
  self:setFrame(info and info.frameType or 0)
  return self
end
function M:setFrame(frame)
  self.scene.frameType=frame
  self.load('src.ui.game3.chrome').setFrameType(frame)
end
return M
