-- Host-facing lifecycle for the pinned, isolated native RS presentation.
local Loader = require('compat.gen1-rs.Loader')
local Music = require('src.core.Music')
local Screens = require('src.ui.Screens')
local Boot = {}
Boot.__index = Boot
Boot.isOpaque = true

local function releaseTree(value, seen)
  if seen[value] then return end
  seen[value] = true
  if type(value) == 'userdata' then
    pcall(function() value:release() end)
  elseif type(value) == 'table' then
    for _, child in pairs(value) do
      if type(child) == 'table' or type(child) == 'userdata' then releaseTree(child, seen) end
    end
  end
end

function Boot.new(game, kind, opts)
  local self = setmetatable({game=game, kind=kind, opts=opts or {}}, Boot)
  self.version = require('src.core.GameVersion').get()
  local emerald=self.version=='emerald'
  self.introScreen=emerald and 'Gen3EmeraldIntro'or 'Gen3RsIntro'
  self.titleScreen=emerald and 'Gen3EmeraldTitle'or 'Gen3RsTitle'
  local spec = assert(game.data.constants[emerald and 'gen3EmeraldPresentation'or 'gen3RsPresentation'],
    'Re-import this cartridge for its native Hoenn intro')
  assert(spec.version == self.version, 'Hoenn presentation belongs to another edition')
  local audio = {}
  local ownedSounds={}
  function audio.playSong(name, options)
    local id = tonumber(name) or assert(spec.songIds[name], 'Unknown RS song '..tostring(name))
    if options and options.restart then Music.stop() end
    Music.play(game.data, ('SONG_%03X'):format(id))
  end
  function audio.playSe(name)
    if type(name)=='number'then
      local source=require('src.core.Sound').playId(game.data,name)
      if source then ownedSounds[#ownedSounds+1]=source end
      return source
    end
    return require('src.core.Sound').play(game.data, name)
  end
  function audio.playCry(id,options)
    local source=require('src.core.Sound').playCry(game.data,id,options)
    if source then ownedSounds[#ownedSounds+1]=source end
    return source
  end
  function audio.stopAll()
    Music.stop()
    for _,source in ipairs(ownedSounds)do source:stop()end
  end
  audio.fadeOutBgm = emerald and Music.fadeOutM4a or Music.fadeOut
  self.load = Loader.new(self.version, {
    __package={loaded={}},
    ['src.core.GameVersion']={get=function()return self.version end},
    ['src.core.game3.audio'] = audio,
    ['src.core.game3.constants'] = { of=function(version)
      assert(version == self.version)
      return {require=function(_, family, name)
        local values=family=='songs'and spec.songIds or family=='species'and spec.speciesIds
        return assert(values and values[name], 'Missing native Hoenn '..tostring(family)..' '..name)
      end}
    end },
  })
  self.machine = self.load('src.ui.game3.rse.gba_machine').new()
  local options = {audio=audio, coldBoot=self.opts.coldBoot~=false, params={song='MUS_TITLE'}}
  -- The presentation has an isolated native RNG. It never seeds or advances
  -- the host's gameplay RNG, save data or eventual starter choice.
  options.rtcSeed = os.time() % 65536
  options.songFrames = function(id)
    local def = assert(game.data.audio.songs[('SONG_%03X'):format(id)])
    local engine = require('src.core.M4ASynth').newEngine(game.data, def, {allowLoops=false})
    for frame=1,12000 do
      local finished=true
      for _,track in ipairs(engine.tracks) do if not track.ended then finished=false;break end end
      if finished then return frame end
      engine:frame()
    end
    return nil
  end
  local path=emerald and ('src.ui.game3.rse.'..(kind=='intro'and'intro_emerald'or'title_rse'))
    or ('src.ui.game3.rs.'..kind)
  local scene=self.load(path)
  -- The host synthesizes the same song programs but does not store the
  -- reference player's .bin format. Measure its track-end frame directly.
  if emerald and kind=='title'then scene.songFrames=options.songFrames end
  self.scene = scene.new(self.machine, options)
  return self
end

function Boot:uiSize() return 240,160 end
function Boot:wantsFillScale() return true end
function Boot:wantsEdgeBleed() return false end
function Boot:sgbPalettes()
  return {require('src.render.PaletteFX').trueColorZone(0,0,29,19)}
end
function Boot:update()
  local result = self.scene:update(self.game.input)
  if result == 'title' and self.kind == 'intro' then
    local done = self.opts.onDone
    Music.stop()
    self.game.stack:pop()
    if done then done() end
  elseif result == 'menu' then
    local options={}
    for key,value in pairs(self.opts) do options[key]=value end
    options.onCancel=function()
      local game,oldOptions=self.game,self.opts
      game.stack:pop()
      Screens.push(game,self.titleScreen,oldOptions)
    end
    Screens.push(self.game, 'Gen3MainMenu', options)
  elseif result == 'copyright' then
    -- The cartridge repeats its attract sequence after the title song.
    self.game.stack:pop()
    local callback=function()Screens.push(self.game,self.titleScreen,self.opts)end
    if self.version=='emerald'then
      Screens.push(self.game,self.introScreen,{onDone=callback,coldBoot=false})
    else Screens.push(self.game,self.introScreen,callback)end
  elseif type(result)=='table' then
    -- Slot deletion belongs to the host's launcher. An unsupported cartridge
    -- maintenance chord must not strand its title with a stopped callback.
    local game,options=self.game,self.opts
    game.stack:pop()
    Screens.push(game,self.titleScreen,options)
  end
end
function Boot:draw() self.scene:draw() end
function Boot:exit()
  if self.machine then releaseTree(self.machine.ppu, {}) end
  if self.load then self.load('src.core.game3.gba_ppu').clearCache() end
  self.machine,self.scene,self.load = nil,nil,nil
end

return Boot
