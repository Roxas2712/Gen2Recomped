-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Shared private font/cache/audio context for the original FR/LG ending scenes.
local M={}
function M.new(game,session,runtime)
 local data=game.data;local version=session.version;local songs=data.constants.gen3FrlgHall.songIds
 local species={};for id,def in pairs(data.pokemon)do if def.index then species[def.index]={id=id,def=def}end end
 local function row(n)return assert(species[tonumber(n)],'Unknown native FR/LG species '..tostring(n))end
 local gv={current=version,get=function()return version end}
 local profile={id=version,family='frlg'}
 local profiles={forSession=function()return profile end,of=function()return profile end,active=function()return profile end,family=function()return'frlg'end}
 local function readLua(path)local f=assert(love.filesystem.load(path));setfenv(f,{});return f()end
 local fs={readActive=function(path)return love.filesystem.read(path)end,loadActive=readLua};fs.read=fs.readActive
 local audio={}
 function audio.playSong(id)return require('src.core.Music').play(data,('SONG_%03X'):format(tonumber(id)or assert(songs[id])))end
 function audio.playSe(id)return require('src.core.Sound').playId(data,tonumber(id)or assert(songs[id]))end
 function audio.playCry(n)return require('src.core.Sound').playCry(data,row(n).id)end
 audio.isCryFinished=require('src.core.Sound').isCryFinished;audio.fadeOutBgm=require('src.core.Music').fadeOutM4a
 local bindings={__package={loaded={['src.core.GameVersion']=gv,['src.core.game3.profile']=profiles,
  ['src.core.game3.runtime']=runtime or{session=session}}},
  ['src.core.GameVersion']=gv,['src.core.game3.profile']=profiles,
  ['src.core.Logger']=require('src.core.Logger'),['src.mods.Runtime']=require('src.mods.Runtime'),
  ['src.render.Font']=require('src.render.Font'),['src.import.CacheFs']=fs,
  ['src.import.CacheBlob']={readFs=fs.readActive,decode=function(_,bytes)return bytes end},
  ['src.import.gba.extract_island1']={CACHE_ROOT='data/generated/gba'},
  ['src.core.game3.dataset']={cache=function()return{read=function(_,path)return love.filesystem.read(path)end}end},
  ['src.ui.game3.stack']={push=function()end,pop=function()end},
  ['src.core.game3.display']={W=240,H=160,TILE=8,COLS=30,ROWS=20},
  ['src.core.game3.audio']=audio,['src.core.game3.song_ids']=songs,['src.core.game3.se_ids']=songs}
 return bindings,audio,row
end
return M
