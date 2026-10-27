-- Native RS Pokédex in a private reference context. Host dex keys and the
-- original save tables remain authoritative; native species numbers are views.
local M={};M.__index=M;M.isOpaque=true;M.holdsUIAnchors=true;M.screenId='Gen3RsPokedex'
local cursors=setmetatable({},{__mode='k'})
function M.available(game)
  local v=require('src.core.GameVersion').get()
  local s=game and game.data and game.data.constants and game.data.constants.gen3RsPokedex
  return (v=='ruby'or v=='sapphire')and type(s)=='table'and s.version==v and s.format==1
end
function M.new(game,opts)
  assert(M.available(game));opts=opts or {}
  local data,save=game.data,game.save
  local mapKit=require('src.ui.Gen3RsMapKit').new(game);local session,C=mapKit.session,mapKit.constants
  local basic=require('compat.gen1-rs.Loader').new(require('src.core.GameVersion').get())
  C.species=basic('src.core.game3.constants.ruby.species')
  C.trainer_classes=basic('src.core.game3.constants.ruby.trainer_classes')
  function C:map(key)return self:require('map_groups',key)end
  local byNumber,byNational={},{}
  for id,row in pairs(data.pokemon)do
    if row.index then byNumber[row.index]={id=id,def=row}end
    if row.dex and row.dex>=1 and row.dex<=386 then
      local old=byNational[row.dex]
      if not old or row.index<old then byNational[row.dex]=row.index end
    end
  end
  local function row(number)return assert(byNumber[tonumber(number)],'Unknown native RS dex species '..tostring(number))end
  local function bitset(bits,number)
    local r=byNumber[number];return r and bits and (bits[r.id]==true or bits[r.id]==1)or false
  end
  local hostDex=save.pokedex or {};session.dex={}
  for _,key in ipairs({'seen','owned','caught'})do
    local source=hostDex[key]or (key=='caught'and hostDex.owned)or {}
    session.dex[key]=setmetatable({},{__index=function(_,number)return bitset(source,number)end})
  end
  session.dex.unownPersonality=hostDex.unownPersonality
  session.dex.spindaPersonality=hostDex.spindaPersonality
  session.name=(save.player or {}).name or '';session.options={}
  for key,value in pairs(save.options or {})do session.options[key]=value end
  -- Host NORMAL/LR/L=A are 1/2/3; the native cartridge stores 0/1/2.
  session.options.buttonMode=math.max(0,(tonumber(session.options.gen3ButtonMode)or 1)-1)
  local prefs=save.gen3RsPokedex or {};session.pokedex={mode=prefs.mode,order=prefs.order}
  local function readLua(path)
    local f=assert(love.filesystem.load(path),'Missing native RS dex resource '..path);setfenv(f,{});return f()
  end
  local encounters={}
  for _,header in pairs(data.encounters or {})do
    if header.group and header.number then
      local h={mapGroup=header.group,mapNum=header.number}
      for hostKind,nativeKind in pairs({grass='land',water='water',fish='fishing',rock='rocks'})do
        local raw=header[hostKind]
        if raw then h[nativeKind]={slots={}};for i,slot in ipairs(raw.slots or {})do
          local def=data.pokemon[slot.species];h[nativeKind].slots[i]={species=def and def.index or tonumber(slot.species)}
        end end
      end
      encounters[header.group..':'..header.number]=h
    end
  end
  local maps={};for id,def in pairs(data.maps)do maps[id]=mapKit.mapView(def)end
  local function mapId(g,n)return ('MAP_G%02d_N%02d'):format(g,n)end
  local cry,heldMusic=false,false
  local Sound=require('src.core.Sound')
  local audio={}
  function audio.stopCry()if cry then cry:stop();cry=false end end
  function audio.playCry(number)
    audio.stopCry();cry=Sound.playCry(data,row(number).id,{isolated=true});return cry
  end
  function audio.isCryFinished()return not(cry and cry:isPlaying())end
  function audio.playSe(id)return Sound.playId(data,id)end
  function audio.pauseBgm()require('src.core.ChipAudio').holdMusic(true);heldMusic=true end
  function audio.resumeBgm()if heldMusic then require('src.core.ChipAudio').holdMusic(false);heldMusic=false end end
  local songs=data.constants.gen3RsPresentation.songIds
  local function front(number,_,shiny,pid)
    local r=row(number)
    local path=require('src.pokemon.Sprites').path(data,r.id,'front',{
      kind='dex',mon={species=r.id,personality=pid or 0,shiny=shiny}})
    return path and {image=require('src.render.Assets').image(path)}or nil
  end
  -- The host synthesizer supplies the same cry recording for both playback
  -- and the native oscilloscope; never invent a waveform from frame counters.
  local pcm={}
  local function cryPcm(number)
    if pcm[number]then return pcm[number]end
    local def=(data.audio.cries or {})[row(number).id]
    local sd=def and require('src.core.M4ASynth').renderCry(data,def.m4a)
    if not sd then return nil end
    local out={};for i=0,sd:getSampleCount()-1 do
      local v=math.max(-128,math.min(127,math.floor(sd:getSample(i,1)*127)))
      out[#out+1]=string.char(v%256)
    end
    pcm[number]=table.concat(out);return pcm[number]
  end
  audio._pack={index={cries=setmetatable({},{__index=function(_,n)return {sampleId=n}end})},
    samples=setmetatable({},{__index=function(_,n)return {species=n,freq=44100}end})}
  local self
  local bindings={
    ['src.core.Strings']=require('src.core.Strings'),
    -- RS search text is carried verbatim in its own ROM manifests. The
    -- shared controller also constructs optional Emerald text-list keys.
    ['src.core.game3.rom_text']={has=function()return false end,
      key=function(name,index)return name..':'..index end,
      plain=function(name)error('Missing native RS dex text '..tostring(name))end},
    ['src.core.game3.constants']={of=function()return C end},
    ['src.core.game3.audio']=audio,['src.core.game3.se_ids']=songs,
    ['src.core.game3.m4a_player']={startCry=function(_,n)return {info={cryIndex=n}}end},
    ['src.core.game3.m4a_sample']={loadPcm=function(_,meta)return cryPcm(meta.species)end},
    ['src.core.game3.m4a_mix']={waveRate=function(freq)return freq end},
    ['src.core.game3.dex']={isSeen=function(d,n)return d.seen[n]==true end,
      isCaught=function(d,n)return d.caught[n]==true or d.owned[n]==true end,
      nationalEnabled=function()return save.nationalDex==true end},
    ['src.core.game3.pokemon']={speciesFromNational=function(n)return byNational[n]end,
      national=function(n)return row(n).def.dex end,name=function(n)return row(n).def.name end,
      picSpecies=function(n)return n end,frontPic=front},
    ['src.ui.game3.stack']={push=function()end,pop=function()end},
    ['src.ui.game3.rse.mapsec']={readLua=function(rel)
      return rel=='encounters.lua'and encounters or readLua('data/generated/gba/'..rel)
    end,entry=function(n)return mapKit:manifest().sections[n]end},
    ['src.core.game3.scripting.flags']={getFlag=function(_,_,n)return session.flags[n]end},
    ['src.core.game3.rse.init']={mapGroupNum=function(id)
      local d=data.maps[id];return d and d.group,d and d.number
    end},
    ['src.import.gba.map_catalog']={mapIdFor=mapId,groupNumFor=function(id)
      local d=data.maps[id];return d and d.group,d and d.number
    end},
  }
  self=setmetatable(require('src.ui.Gen3RsSceneContext').new(game,{bindings=bindings,
    packageLoaded={['src.core.game3.scripting.space']=false,
      ['src.core.game3.runtime']={_game={data={maps=maps}}},
      ['src.core.game3.map']={currentDef=function()return maps[session.map]end},
      ['src.core.game3.player']=setmetatable({},{__index=function(_,key)
        return key=='cellX'and session.x or key=='cellY'and session.y or nil
      end})}}),M)
  self.session=session;self.audio=audio;self.mapKit=mapKit
  self.scene=self.load('src.ui.game3.rs.pokedex')
  local version=require('src.core.GameVersion').get()
  cursors[game]=cursors[game]or {}
  local previous=cursors[game][version]
  if previous and previous.save==save then
    self.scene.lastSelected,self.scene.lastRotation=previous.selected,previous.rotation
  end
  local function close()
    if self.closed then return end
    if not opts.caught then
      cursors[game][version]={save=save,selected=self.state.selected,rotation=self.state.pokeBallRotation}
    end
    if not opts.caught and (prefs.mode~=session.pokedex.mode or prefs.order~=session.pokedex.order)then
      local target=save.gen3RsPokedex or {};save.gen3RsPokedex=target
      target.mode=session.pokedex.mode;target.order=session.pokedex.order
    end
    game.stack:pop();if opts.onCancel then opts.onCancel()end
  end
  if opts.caught then
    local r=assert(data.pokemon[opts.species],'Unknown caught host species')
    self.state=self.scene.showCaughtMon(r.index,{session=session,personality=opts.personality or 0,
      shiny=opts.shiny,onDone=close})
  else self.state=self.scene.show(session.dex,{session=session,onClose=close})end
  -- The silhouette image uses the extracted RS trainer PNG, while the native
  -- controller asks for its raw RGBA equivalent.
  local kit=self.load('src.ui.game3.rse.scene_kit');local rgba=kit.rgbaImage
  kit.rgbaImage=function(path,w,h)
    local id=path:match('trainers/front/(%d+)%.rgba$')
    if id then return kit.image('data/generated/gba/trainers/front/'..id..'.png')end
    return rgba(path,w,h)
  end
  return self
end
function M:uiSize()return 240,160 end
function M:wantsFillScale()return true end
function M:wantsEdgeBleed()return false end
function M:sgbPalettes()return {require('src.render.PaletteFX').trueColorZone(0,0,29,19)}end
function M:update(dt)
  if self.closed then return end
  self.scene.Host.handleInput(self.game.input);self.scene.Host.update(dt or 1/60)
end
function M:draw()
  local g=love.graphics
  local ok,why=require('src.render.GraphicsScope').call(function()
    g.setCanvas(self.canvas);g.origin();g.setScissor();g.setShader();g.clear(0,0,0,0)
    self.scene.Host.draw()
  end)
  if not ok then error(why,0)end
  g.setColor(1,1,1,1);g.draw(self.canvas,0,0)
end
function M:exit()
  self.closed=true;self.audio.stopCry();self.audio.resumeBgm()
  if self.scene then self.scene.reset()end
  if self.canvas then self.canvas:release()end
  self.canvas,self.load,self.scene=nil,nil,nil
end
return M
