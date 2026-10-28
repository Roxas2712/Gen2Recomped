-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- The reference battle layer separates each row's repeated wallpaper tile.
-- Keep its native tile/palette/flip entry; never paint over platform pixels.
local M={PATH='assets/generated/battle/bg/evolution_building.png'}
function M.tilemap(bytes)
 local out={}
 for y=0,19 do
  local counts,entries={},{}
  for x=0,31 do
   local i=(y*32+x)*2+1;local entry=assert(bytes[i])+assert(bytes[i+1])*256
   entries[x]=entry;local id=entry%1024;counts[id]=(counts[id]or 0)+1
  end
  local selected,count
  for id,n in pairs(counts)do if not count or n>count or(n==count and id<selected)then selected,count=id,n end end
  local entry
  for x=0,31 do if entries[x]%1024==selected then entry=entries[x];break end end
  for x=0,31 do local i=(y*32+x)*2+1;out[i],out[i+1]=entry%256,math.floor(entry/256)end
 end
 return out
end
function M.extract(x,tiles,map,colors)
 local image=assert(x:battleBackgroundImage(tiles,M.tilemap(map),colors))
 x:saveImage(image,'battle/bg/evolution_building.png');return M.PATH
end
function M.missing()
 local Fs=require('src.import.CacheFs');local raw=Fs.read('data/generated/constants.lua')
 local f=raw and loadstring(raw);if f then setfenv(f,{})end
 local ok,c=false,nil;if f then ok,c=pcall(f)end
 local bg=ok and type(c)=='table'and c.gen3BattleTerrain;local text=ok and type(c)=='table'and c.gen3Evolution
 if not(type(bg)=='table'and bg.evolutionBackground==M.PATH and type(text)=='table'
  and type(text.evolving)=='string'and type(text.congratulations)=='string'and type(text.stopped)=='string')then
  return{'<gba:reference-evolution>'}
 end
 return Fs.exists(M.PATH)and{}or{M.PATH}
end
return M
