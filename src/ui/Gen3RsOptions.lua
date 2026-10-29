-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Byte-exact native RS options; host fields, extra rows and callbacks remain hosted.
local M={};M.__index=M
function M.record(game)
  local version=require('src.core.GameVersion').get()
  if version~='ruby'and version~='sapphire'then return end
  local c=game and game.data and game.data.constants;local party=c and c.gen3RsParty
  if not(party and party.version==version and type(party.menus)=='string')then return end
  local bytes=require('src.import.CacheFs').read(party.menus);local f=bytes and loadstring(bytes)
  if not f then return end;setfenv(f,{})
  local ok,man=pcall(f);local d=ok and type(man)=='table'and man.option
  if not(ok and type(man)=='table'and man.game==version and man.layout=='rs'and type(d)=='table'
    and type(d.rows)=='table'and#d.rows==7 and d.frameCount==20
    and type(d.textPalette)=='table'and#d.textPalette==32 and type(d.nativeWindow)=='table'
    and type(d.title)=='string'and type(d.frameLabel)=='string')then return end
  for i,count in ipairs{3,2,2,2,3,0,0}do
    local r=d.rows[i]
    if not(type(r)=='table'and type(r.text)=='string'and type(r.x)=='number'and type(r.y)=='number'
      and type(r.choices)=='table'and#r.choices==count)then return end
    for _,choice in ipairs(r.choices)do if type(choice.text)~='string'or type(choice.x)~='number'then return end end
  end
  for _,key in ipairs{'foregroundColor','backgroundColor','shadowColor'}do
    local v=d.nativeWindow[key];if type(v)~='number'or v%1~=0 or v<0 or v>15 then return end
  end
  for _,key in ipairs{'selectedStyle','inactiveStyle','titleX','titleY','frameLabelX','frameNumberX','frameY'}do
    if type(d[key])~='number'then return end
  end
  return d
end
function M.new(owner,record)
  local game=owner.game;local Values=require('src.core.Gen3RsOptionValues')
  local options=game.save.options or{};game.save.options=options
  local self=setmetatable({game=game,owner=owner,record=record},M)
  local proxy={options=options}
  function proxy:writeOptions()
    if game.applyOptions then game:applyOptions(options)end
    return require('src.core.SaveData').saveOptions(options)
  end
  local session={version=require('src.core.GameVersion').get()}
  local bindings={
    ['src.core.game3.options']={engine=function()return options end,bind=function()return Values.read(options)end,
      set=function(_,key,value)Values.set(options,key,value)end},
    ['src.ui.game3.shaderfx_menu']={isOpen=function()return false end,close=function()end,update=function()end},
    ['src.render.PixelCanvas']={new=function(w,h)
      local canvas=love.graphics.newCanvas(w,h,{dpiscale=1});self.nativeCanvas=canvas;return canvas
    end},
    ['src.ui.game3.stack']={push=function(id)assert(id=='option')end,pop=function(id)
      assert(id=='option'and game.stack:top()==owner);owner:close()
    end},
    ['src.ui.game3.option_rows']={withCart=function(_,native,category)
      return require('src.ui.Gen3OptionRows').withCart(owner,native,category)
    end},
  }
  local context=require('src.ui.Gen3RsSceneContext').new(game,{bindings=bindings,
    packageLoaded={['src.core.game3.runtime']={_game=proxy}}})
  self.load,self.canvas=context.load,context.canvas
  local audio=self.load('src.core.game3.audio')
  local playSe=audio.playSe
  audio.playSe=function(id)
    if type(id)=='string'then id=assert(game.data.constants.gen3RsPresentation.songIds[id])end
    return playSe(id)
  end
  audio.setCryStereo=function(value)
    -- Preview the selected sound without changing the persisted option early.
    local preview={};for key,v in pairs(options)do preview[key]=v end;preview.stereo=value==1
    require('src.core.Sound').applyOptions(preview,game.data)
  end
  self.scene=self.load('src.ui.game3.rs.option_menu')
  self.scene.show({session=session,game=proxy})
  return self
end
function M:update()
  local scene=self.scene
  if not scene then return end
  scene.handleInput(self.game.input)
  if not self.scene then return end
  scene.update()
  if self.scene then self.owner.index=scene.cursor end
end
function M:draw()
  local g=love.graphics
  local ok,why=require('src.render.GraphicsScope').call(function()
    g.setCanvas(self.canvas);g.origin();g.setScissor();g.setShader();g.clear(0,0,0,0);self.scene.draw()
  end)
  if not ok then error(why,0)end
  g.setColor(1,1,1,1);g.draw(self.canvas,0,0)
end
function M:exit()
  if self.scene then self.scene.open=false end
  if self.nativeCanvas then self.nativeCanvas:release()end
  if self.canvas then self.canvas:release()end
  self.scene,self.load,self.nativeCanvas,self.canvas=nil,nil,nil,nil
end
return M
