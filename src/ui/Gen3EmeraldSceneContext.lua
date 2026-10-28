-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Original Emerald movie resources/font/audio in a private native context.
local M={}
function M.new(game,opts)
  opts=opts or{};assert(require('src.core.GameVersion').get()=='emerald')
  local self={game=game,version='emerald'}
  local spec=assert(game.data.constants.gen3EmeraldCredits)
  local songs=assert(game.data.constants.gen3EmeraldPresentation.songIds)
  local gv=require('src.import.Gen3EmeraldCreditsAssets').versionBinding()
  local function readLua(path)
    local f=assert(love.filesystem.load(path),'Missing Emerald movie resource '..path);setfenv(f,{});return f()
  end
  local fs={readActive=function(path)return love.filesystem.read(path)end,loadActive=readLua}
  fs.read=fs.readActive
  local audio={}
  function audio.playSong(name,options)
    local id=tonumber(name)or assert(songs[name],'Missing Emerald movie song '..tostring(name))
    if options and options.restart then require('src.core.Music').stop()end
    return require('src.core.Music').play(game.data,('SONG_%03X'):format(id))
  end
  function audio.playSe(id)return require('src.core.Sound').playId(game.data,tonumber(id)or songs[id])end
  audio.fadeOutBgm=require('src.core.Music').fadeOutM4a
  local profile={id='emerald',family='rse'}
  local profiles={forSession=function()return profile end,active=function()return profile end,
    of=function()return profile end,family=function()return'rse'end}
  local packages={loaded={['src.core.GameVersion']=gv,['src.core.game3.profile']=profiles,
    ['src.core.game3.runtime']={_game=game,session={version='emerald'}}}}
  local bindings={__package=packages,['src.core.GameVersion']=gv,
    ['src.core.Logger']=require('src.core.Logger'),['src.mods.Runtime']=require('src.mods.Runtime'),
    ['src.render.Font']=require('src.render.Font'),['src.import.CacheFs']=fs,
    ['src.import.CacheBlob']={readFs=fs.readActive,decode=function(_,bytes)return bytes end},
    ['src.import.gba.versions']={BUILD='emerald',active=function()return'emerald'end},
    ['src.core.game3.profile']=profiles,['src.core.game3.audio']=audio,
    ['src.core.game3.song_ids']=songs,['src.core.game3.se_ids']={resolve=function(id)return tonumber(id)or songs[id]end},
    ['src.ui.game3.stack']={push=function()end,pop=function()end},
  }
  for key,value in pairs(opts.bindings or{})do bindings[key]=value end
  self.load=require('compat.gen1-rs.Loader').new('emerald',bindings)
  profile.font=self.load('src.core.game3.profiles.emerald.font')
  profile.font.dir=spec.fonts;profile.font.metrics=spec.fonts..'metrics.lua'
  profile.font.palette={file=spec.fonts..'palette.lua'}
  self.load('src.core.game3.rng').SeedRng(os.time()%65536)
  self.canvas=love.graphics.newCanvas(240,160,{dpiscale=1});self.canvas:setFilter('nearest','nearest')
  return self
end
return M
