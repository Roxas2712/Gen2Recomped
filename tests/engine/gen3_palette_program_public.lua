package.path="./?.lua;./?/init.lua;"..package.path
local T=require("tests.modkit")
local F=require("tests.palette_programs.fixture")
local World=require("tests.terrain_animation.fixture")
local Import=require("src.import.Gen3PalettePrograms")
local Writer=require("src.import.LuaWriter")
local Renderer=require("src.render.TileRenderer")
local Tiles=require("src.render.Gen3Tiles")
local Copy=require("src.mods.Merge").deepCopy
local function pixels(decoder,mid,layer)
  local out={};for i=1,256 do out[i]="\0\0\0\0" end
  decoder:drawLayer(mid,layer,0,0,function(x,y,r,g,b) out[y*16+x+1]=string.char(r,g,b,255) end)
  return table.concat(out)
end
for _,game in ipairs({"emerald","firered"}) do for _,api in ipairs({1,2}) do
  local rom=F.new(game)
  local f=World.new(game,api,true)
  local s,e=f.state,f.exports
  f.records.P.secondary=false;f.records.P.callback=rom.sets.general.callback
  f.records.S.secondary=true;f.records.S.callback=rom.sets[game=="emerald" and "battle-dome-floor" or "celadon"].callback
  f.records.T.secondary=true;f.records.T.callback=0
  for _,record in pairs(f.records) do
    local entries={}
    for at=1,#record.metatiles,2 do
      local word=record.metatiles:byte(at)+record.metatiles:byte(at+1)*256
      entries[#entries+1]=F.le(word%4096+8*4096,2)
    end
    record.metatiles=table.concat(entries)
  end
  local report=Import.extract(rom.rom,f.records,rom.manifest,rom.manifest.romSha1)
  T.eq(report.unavailable,0,"both map banks and resident neighbor were imported completely")
  local cache=assert(loadstring(Writer.encode(f.records)))()
  s.game.data.map_tilesets=cache
  local base=assert(e.base(s.mapId))
  local expectedP,expectedS=Copy(cache.P),Copy(cache.S)
  local clock=Renderer.animFrame
  local firstKey,changedKey
  for tick=0,31 do
    Renderer.animFrame=function() return tick end
    local data=assert(e.colors(1,s.mapId))
    if game=="emerald" then
      local frame=math.floor(tick/4)%4+1
      for c=1,16 do expectedS.palettes[9][c]={rom.frames[frame]:byte(c*3-2,c*3)} end
      T.eq(data.paletteAnimation.secondaryFrames[1],frame-1,"read ROM program drives public selected picture")
    else
      T.eq(#data.paletteAnimation.secondaryFrames,0,"FireRed has no invented palette animation")
    end
    local native=Tiles.new({primary=expectedP,secondary=expectedS},base.layout)
    native:setAnimFrame(data.animation.frame)
    for _,mid in ipairs({0,1,2,s.split,s.split+1,s.split+2}) do for layer=1,2 do
      T.eq(e.layer(data,mid,layer),pixels(native,mid,layer),"ROM-to-cache-to-public complete RGBA pixel parity")
    end end
    T.eq(data.secondary.paletteProgram,nil,"import diagnostics do not leak engine internals to public graphics")
    T.eq(data.secondary.callback,nil,"raw cartridge code pointer not exposed")
    T.same(assert(e.base(s.mapId)).secondary.palettes,base.secondary.palettes,"base API remains base after automatic cycle import")
    if tick==0 then firstKey=data.contentKey end
    if tick==4 then changedKey=data.contentKey end
  end
  Renderer.animFrame=clock
  if game=="emerald" then T.check(changedKey~=firstKey,"imported palette program visibly changes source content") end
  local nb=assert(e.colors(1,s.mapId,s.neighborId))
  T.eq(#nb.paletteAnimation.secondaryFrames,0,"null-callback neighbor remains explicitly static")
  cache.S.callback=rom.sets.unknown.callback
  Import.extract(rom.rom,cache,rom.manifest,rom.manifest.romSha1)
  local v,reason=e.colors(1,s.mapId)
  T.eq(v,nil,"unknown reimport cannot retain a former usable palette program")
  T.eq(reason,"palette animation data unavailable","native fallback reason reaches public consumer")
  T.check(e.base(s.mapId)~=nil,"base terrain remains usable after incomplete reimport")
  f.run.release()
end end
T.finish("Imported ROM palettes through public API 1/2 for Emerald and FireRed")
