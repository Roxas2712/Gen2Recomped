-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Emerald's own weather OAM, graphics, palettes and four-day route cycles.
local M={ROOT='data/generated/gba/weather/'}
local NAMES={[0]='NONE','SUNNY_CLOUDS','SUNNY','RAIN','SNOW','RAIN_THUNDERSTORM',
 'FOG_HORIZONTAL','VOLCANIC_ASH','SANDSTORM','FOG_DIAGONAL','UNDERWATER',
 'SHADE','DROUGHT','DOWNPOUR','UNDERWATER_BUBBLES','ABNORMAL'}
NAMES[20]='ROUTE119_CYCLE';NAMES[21]='ROUTE123_CYCLE'
local blobs={
 {'fog_h','fog_horizontal','gWeatherFogHorizontalTiles','sFogHorizontalSpriteTemplate','fog'},
 {'fog_d','fog_diagonal','gWeatherFogDiagonalTiles','sFogDiagonalSpriteTemplate','fog'},
 {'cloud','cloud','gWeatherCloudTiles','sCloudSpriteTemplate','clouds'},
 {'rain','rain','gWeatherRainTiles','sRainSpriteTemplate','fog'},
 {'snow_1','snow_1','gWeatherSnow1Tiles','sSnowflakeSpriteTemplate','fog'},
 {'snow_2','snow_2','gWeatherSnow2Tiles','sSnowflakeSpriteTemplate','fog'},
 {'ash','ash','gWeatherAshTiles','sAshSpriteTemplate','fog'},
 {'sandstorm','sandstorm','gWeatherSandstormTiles','sSandstormSpriteTemplate','sandstorm'},
 {'bubble','bubble','gWeatherBubbleTiles','sBubbleSpriteTemplate','fog'},
}
function M.resources()
 local out={M.ROOT..'manifest.lua',M.ROOT..'default.gbapal',M.ROOT..'clouds.gbapal',
  M.ROOT..'sandstorm.gbapal',M.ROOT..'drought_colors.bin'}
 for _,row in ipairs(blobs)do for _,ext in ipairs{'.4bpp','.idx','.rgba'}do
  out[#out+1]=M.ROOT..row[2]..ext
 end end
 table.sort(out);return out
end
function M.configure(S)
 local W={palettes={fog=S.off('gFogPalette'),clouds=S.off('gCloudsWeatherPalette'),
  sandstorm=S.off('gSandstormWeatherPalette')},blobs={},cycles={},
  color_map_types=S.off('sBasePaletteColorMapTypes'),color_map_types_size=S.size('sBasePaletteColorMapTypes'),
  drought_colors=S.off('sDroughtWeatherColors'),drought_colors_size=S.size('sDroughtWeatherColors')}
 assert(W.color_map_types_size==32 and W.drought_colors_size==0xc000,'Incomplete original Emerald weather tables')
 for _,row in ipairs(blobs)do W.blobs[#W.blobs+1]={key=row[1],file=row[2],
  tiles=S.off(row[3]),size=S.size(row[3]),template=S.off(row[4]),pal=row[5]}end
 for _,name in ipairs{'route119','route123'}do
  local symbol='sWeatherCycleRoute'..name:sub(6)
  W.cycles[name]={off=S.off(symbol),count=S.size(symbol)}
 end
 return W
end
function M.extract(x)
 assert(x.version=='emerald','Emerald weather requires its own cartridge')
 x:beginStage('Emerald native field weather')
 local V={BUILD='emerald',FAMILY='rse'}
 local Writer=require('src.import.LuaWriter')
 local load=require('compat.gen1-rs.Loader').new('emerald',{
  ['src.import.gba.versions']=V,
  ['src.import.gba.extract_scripts']={serialize_lua=function(v)return Writer.encode(v):sub(8)end}})
 local S=load('src.import.gba.syms').of('emerald');V.SYMS=S;V.WEATHER_GFX=M.configure(S)
 local rom={id='emerald'}
 function rom:get(off)return x.rom:u8(off)end
 function rom:u16(off)return x.rom:u16(off)end
 function rom:u32(off)return x.rom:u32(off)end
 function rom:readString(off,size)
  assert(off>=0 and off+size<=x.rom.size,'Emerald weather resource outside cartridge')
  return x.rom.data:sub(off+1,off+size)
 end
 local Fs=require('src.import.CacheFs')
 local cache={write=function(_,path,bytes)local ok,why=Fs.write(path,bytes);assert(ok,why);return true end}
 assert(load('src.import.gba.weather_extract').run(rom,cache,{}))
 local raw=assert(Fs.read(M.ROOT..'manifest.lua'));local f=assert(loadstring(raw));setfenv(f,{})
 local manifest=f();manifest.game='emerald';assert(Fs.write(M.ROOT..'manifest.lua',Writer.encode(manifest)))
 local spec={format=1,version='emerald',resources=M.resources(),objectPaletteSlots={},cycles={},
  source='ROM: Emerald weather OAM, graphics, palettes, raw drought tables and four-day route cycles'}
 for i=0,S.count('gObjectEventGraphicsInfoPointers',4)-1 do
  local info=x.rom:pointer(S.off('gObjectEventGraphicsInfoPointers')+i*4)
  if info then spec.objectPaletteSlots[i]=x.rom:u8(info+12)%16 end
 end
 local cycles={length=4,source=spec.source}
 for key,row in pairs(V.WEATHER_GFX.cycles)do
  assert(row.count==4,'Emerald route weather must have four daily stages')
  local values,names={},{}
  for i=0,3 do local value=rom:get(row.off+i);assert(value<=14 and NAMES[value])
   values[i+1]=value;names[i+1]=NAMES[value]
  end
  spec.cycles[key]=values;cycles[key=='route119'and'ROUTE119_CYCLE'or'ROUTE123_CYCLE']=names
 end
 local constants=assert(x._constants)
 constants.gen3EmeraldWeather=spec;constants.gen3WeatherNames=NAMES;constants.gen3WeatherCycles=cycles
 constants.gen3BattleWeather={RAIN='RAIN',RAIN_THUNDERSTORM='RAIN',DOWNPOUR='RAIN',
  DROUGHT='SUN',SANDSTORM='SANDSTORM',SNOW='HAIL'}
end
function M.valid(spec,version)
 if version~='emerald'or type(spec)~='table'or spec.version~='emerald'or spec.format~=1
  or type(spec.resources)~='table'or#spec.resources~=32 or type(spec.cycles)~='table'
  or type(spec.objectPaletteSlots)~='table'or spec.objectPaletteSlots[0]==nil then return false end
 for i,path in ipairs(M.resources())do if spec.resources[i]~=path then return false end end
 for _,key in ipairs{'route119','route123'}do
  local cycle=spec.cycles[key];if type(cycle)~='table'or#cycle~=4 then return false end
  for _,v in ipairs(cycle)do if type(v)~='number'or v%1~=0 or v<0 or v>14 then return false end end
 end
 for _,v in pairs(spec.objectPaletteSlots)do
  if type(v)~='number'or v%1~=0 or v<0 or v>15 then return false end
 end
 return true
end
function M.missing()
 local Fs=require('src.import.CacheFs')
 local function read(path)
  local raw=Fs.read(path);local f=raw and loadstring(raw);if f then setfenv(f,{})end
  local ok,value=false,nil;if f then ok,value=pcall(f)end
  return ok and type(value)=='table'and value or nil
 end
 local spec=(read('data/generated/constants.lua')or{}).gen3EmeraldWeather
 if not M.valid(spec,'emerald')then return{'<emerald:native-field-weather>'}end
 local out={};for _,path in ipairs(spec.resources)do if not Fs.exists(path)then out[#out+1]=path end end
 local m=read(M.ROOT..'manifest.lua')
 if not m or m.format~=1 or m.game~='emerald'or m.family~='rse'
  or type(m.blobs)~='table'or type(m.palettes)~='table'then out[#out+1]=M.ROOT..'manifest.lua'end
 return out
end
return M
