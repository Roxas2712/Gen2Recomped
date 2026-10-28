-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local M=require('src.import.Gen3EvolutionBackground');local S=require('src.core.SaveSerializer')
local original,expected={},{}
for y=0,19 do
 local wallpaper=(y%4)+1;local entry=wallpaper+0xC00+(2+y%3)*4096;expected[y]=entry
 for x=0,31 do
  -- Platforms occupy varied native tile IDs. The two columns beyond the
  -- 240px view still participate in selecting the original wallpaper.
  local value=(x>=8 and x<=20)and(30+x+y*32+8192)or entry
  local i=(y*32+x)*2+1;original[i],original[i+1]=value%256,math.floor(value/256)
 end
end
local before=S.encode(original);local clean=M.tilemap(original)
T.eq(S.encode(original),before,'splitting leaves original battle map untouched')
for y=0,19 do for x=0,31 do
 local i=(y*32+x)*2+1
 T.eq(clean[i]+clean[i+1]*256,expected[y],'wallpaper keeps native tile ID, flip and palette entry')
end end
local F,W=require('src.import.CacheFs'),require('src.import.LuaWriter');local read,exists=F.read,F.exists
local constants={gen3BattleTerrain={evolutionBackground=M.PATH},gen3Evolution={evolving='START',congratulations='END',stopped='STOP'}}
F.read=function()return W.encode(constants)end;F.exists=function()return true end
T.eq(#M.missing(),0,'native clean layer and original scene text are ready')
F.exists=function()return false end;T.eq(M.missing()[1],M.PATH,'lost layer invalidates the cache')
constants.gen3BattleTerrain.evolutionBackground='FULL_TERRAIN_WITH_PLATFORMS.png';F.exists=function()return true end
T.eq(M.missing()[1],'<gba:reference-evolution>','old combined terrain never satisfies readiness')
F.read,F.exists=read,exists
T.finish('native evolution wallpaper keeps tile/palette/flip rows and excludes battle platforms')
