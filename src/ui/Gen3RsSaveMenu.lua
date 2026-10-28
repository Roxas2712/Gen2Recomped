-- Original RS save controller; the host keeps its active slot and atomic IO.
local M={};M.__index=M;M.isOpaque=false;M.holdsUIAnchors=true;M.screenId='Gen3RsSaveMenu'
local SaveData=require('src.core.SaveData')
function M.available(game)
  return require('src.import.Gen3RsSaveAssets').valid(game and game.data and game.data.constants
    and game.data.constants.gen3RsSave,require('src.core.GameVersion').get())
end
function M.session(game)
  local save=game.save;local player=save.player or{}
  local function flag(id)
    local flags=save.flags or{};local v=flags[id]
    if v==nil and type(id)=='number'then v=flags[('FLAG_G3_%04X'):format(id)]end
    return v==true or v==1
  end
  local session={version=require('src.core.GameVersion').get(),name=player.name or'',
    gender=player.gender,flags=setmetatable({},{__index=function(_,id)return flag(id)end}),
    vars=setmetatable({},{__index=function(_,id)return(save.gen3Vars or{})[id]or 0 end}),
    dex={caught={},owned={},national=save.nationalDex==true}}
  session.store={flags=session.flags,vars=session.vars}
  for _,key in ipairs({'caught','owned'})do
    for id,on in pairs((save.pokedex or{})[key]or{})do
      local def=game.data.pokemon[id]
      if def and def.index and on and on~=0 then session.dex[key][def.index]=true end
    end
  end
  return session
end
function M.new(game,owner)
  assert(M.available(game)and game.stack:top()==owner)
  local version=require('src.core.GameVersion').get()
  local self=setmetatable({game=game,owner=owner,session=M.session(game),nativeSaveKind='rs'},M)
  local base=require('compat.gen1-rs.Loader').new(version)
  local C=require('compat.gen1-rs.Constants').new(base)
  local songs=game.data.constants.gen3RsPresentation.songIds
  local function close()
    if self.closed then return end
    self.closed=true;assert(game.stack:top()==self);game.stack:pop()
  end
  local function write()
    assert(self.savingDrawn,'The saving message must reach the renderer before IO')
    local save=game.save;local previous=save.gen3Stats and save.gen3Stats[0]
    require('src.pokemon.Gen3GameStats').increment(save,0)
    local ok,written=pcall(function()
      if game.writeSave then return game:writeSave()end
      return SaveData.save(save)
    end)
    if not ok or written~=true then
      save.gen3Stats[0]=previous
      if not next(save.gen3Stats)then save.gen3Stats=nil end
      if not ok then error(written,0)end
      return false
    end
    self.wrote=true;return true
  end
  local runtime={_game={saveGame=write}}
  local bindings={
    ['src.core.Strings']=require('src.core.Strings'),
    ['src.core.game3.constants']={of=function(v)assert(v==version);return C end},
    ['src.import.gba.map_sections_extract']={},
    ['src.core.SaveData']={load=function(v)
      assert(v==version);return SaveData.saveFileExists(version)==true and{}or nil
    end},
    ['src.core.game3.runtime']=runtime,['src.core.game3.bridge']={},
    ['src.core.game3.rse.init']={system=function()return nil end,call=function(system,action)
      assert(system=='pyramid'and action=='pause') -- RS has no Battle Pyramid.
    end},
    ['src.core.game3.se_ids']={resolve=function(id)return type(id)=='number'and id or assert(songs[id])end},
    ['src.core.game3.scripting.flags']={
      getFlag=function(store,_,id)return store.flags[id]==true end,
      countBadges=function(store)
        local n=0;local first=C:flag('FLAG_BADGE01_GET')
        for id=first,first+7 do if store.flags[id]then n=n+1 end end;return n
      end},
    ['src.ui.game3.screens']={flags=function()return{IDS={SYS_POKEDEX_GET=C:flag('FLAG_SYS_POKEDEX_GET')}}end},
    ['src.core.game3.pokemon']={currentMapSec=function()
      local ow=game.overworld;local def=ow and ow.map and ow.map.def or game.data.maps[(game.save.player or{}).map]
      return def and(def.regionMapSectionId or def.regionMapSection)
    end},
    ['src.ui.game3.stack']={push=function(id)assert(id=='save')end,
      pop=function(id)assert(id=='save');close()end},
    ['src.ui.game3.start_menu']={isOpen=function()return game.stack:top()==owner end,
      close=function()assert(self.wrote and game.stack:top()==owner);owner:close()end},
  }
  local context=require('src.ui.Gen3RsSceneContext').new(game,{bindings=bindings,
    textIR=game.data.constants.gen3RsSave.textIR,
    packageLoaded={['src.core.game3.scripting.space']=false,['src.core.game3.runtime']=runtime}})
  self.load,self.canvas=context.load,context.canvas
  local profile=self.load('src.core.game3.profile')
  profile.forSession().ui.saveMenu='rs'
  -- Native dex summary rules over numeric views of the host's stable IDs.
  -- These are the RS profile's national gates and existing ROM regional packs.
  profile.of=function()return{id=version,dex={regionalPack='pokemon/hoenn.lua',
    orderPack='pokemon/regional_dex.lua',national={flag='FLAG_SYS_NATIONAL_DEX',var='VAR_NATIONAL_DEX',
      value=0x302,magic=0xDA,requireAll=true}}}end
  local toHoenn,order={},{}
  for id,number in pairs(game.data.constants.gen3HoennDex.numbers)do
    local def=game.data.pokemon[id]
    if def and def.index then toHoenn[def.index]=number;if number>=1 and number<=202 then order[number]=def.dex end end
  end
  local packs={['pokemon/hoenn.lua']={toHoenn=toHoenn},['pokemon/regional_dex.lua']={count=202,order=order}}
  local dex=self.load('src.core.game3.dex')
  dex.packReader=function(v,path)
    assert(v==version);return require('src.import.LuaWriter').encodeSplit(assert(packs[path]))
  end
  self.scene=self.load('src.ui.game3.save_menu');self.step=self.load('src.ui.game3.rse.scene_kit').stepper()
  self.scene.show({session=self.session,game=game})
  owner.rsSaveModal=true;self:refresh();return self
end
function M:refresh()
  local seconds=math.floor(SaveData.playSeconds(self.game.save))
  self.session.playTime={hours=math.floor(seconds/3600),minutes=math.floor(seconds/60)%60}
  self.phase,self.index=self.scene._phase,self.scene.cursor
end
function M:uiSize()return 240,160 end
function M:wantsFillScale()return true end
function M:wantsEdgeBleed()return false end
function M:sgbPalettes()return{require('src.render.PaletteFX').trueColorZone(0,0,29,19)}end
function M:update(dt)
  if self.closed then return end
  self.step:collect(self.game.input);local scene=self.scene
  self.step:run(dt,function(input)
    if input.new.up or input.new.down then scene.move(1)
    elseif input.new.a then scene.confirm()
    elseif input.new.b then scene.cancel()end
    if self.closed then return true end
    if scene._phase~='saving_msg'or self.savingDrawn then scene.update()end
    if self.closed then return true end
  end)
  if not self.closed then self:refresh()end
end
function M:draw()
  local g=love.graphics
  local ok,why=require('src.render.GraphicsScope').call(function()
    g.setCanvas(self.canvas);g.origin();g.setScissor();g.setShader();g.clear(0,0,0,0)
    self.scene.draw()
  end)
  if not ok then error(why,0)end
  g.setColor(1,1,1,1);g.draw(self.canvas,0,0)
  if self.scene._phase=='saving_msg'then self.savingDrawn=true end
end
function M:exit()
  self.closed=true;self.owner.rsSaveModal=nil
  if self.scene then self.scene.open=false end
  if self.canvas then self.canvas:release()end
  self.scene,self.load,self.canvas,self.step=nil,nil,nil,nil
end
return M
