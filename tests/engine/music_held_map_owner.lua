-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local V=require('src.core.GameVersion')
local sources={};local previous=love.audio
love.audio={newSource=function()
 local s={playing=false};sources[#sources+1]=s
 function s:play()self.playing=true end
 function s:stop()self.playing=false end
 function s:pause()self.playing=false end
 function s:isPlaying()return self.playing end
 function s:setVolume()end
 function s:setLooping()end
 function s:setFilter()end
 function s:setPitch()end
 return s
end}
local M=require('src.core.Music');local original=V.get()
for _,version in ipairs{'ruby','sapphire','emerald','firered','leafgreen'}do
 V.set(version);M.reload()
 local data={maps={A={music=0x100},B={music=0x101}},audio={songs={
  SONG_100={file='a.wav'},SONG_101={file='b.wav'},SONG_102={file='voyage.wav'}},mapSongs={A='SONG_100',B='SONG_101'}}}
 local ctx={game={data=data},overworld={map={id='B'}}}
 M.playMap(data,'A',false,false);T.eq(M.current(),'SONG_100')
 M.nativeCommand(data,'playbgm',0x102,nil,ctx);T.eq(M.current(),'SONG_102')
 local before=#sources;local live=sources[before]
 T.eq(M.rememberMap(data,'B',false,false),'SONG_101')
 T.eq(M.current(),'SONG_102',version..' remembered seam cannot take playback from sailing')
 T.eq(M.mapSong(),'SONG_101','public restorable cue follows the destination')
 T.eq(M.nativeSnapshot().mapSong,0x101,'native default BGM follows the same destination')
 T.eq(#sources,before,'remembering never constructs an audio source')
 T.eq(live:isPlaying(),true,'script-owned source keeps playing')
 M.nativeCommand(data,'fadedefaultbgm',nil,nil,ctx)
 T.eq(M.current(),'SONG_101',version..' original default command restores destination instead of old departure music')
 T.eq(M.mapSong(),'SONG_101','restoring playback keeps the destination owner')
 M.stop()
end
V.set(original);love.audio=previous
T.finish('Five-edition held playback remembers destination map ownership and restores native default BGM')
