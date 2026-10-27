-- Original RS weather graphics, palettes, daily cycles and object palette slots.
local M={};local ROOT='data/generated/gba/weather/'
local NAMES={[0]='NONE','SUNNY_CLOUDS','SUNNY','RAIN','SNOW','RAIN_THUNDERSTORM',
  'FOG_HORIZONTAL','VOLCANIC_ASH','SANDSTORM','FOG_DIAGONAL','UNDERWATER',
  'SHADE','DROUGHT','DOWNPOUR','UNDERWATER_BUBBLES'}
NAMES[20]='ROUTE119_CYCLE';NAMES[21]='ROUTE123_CYCLE'
function M.extract(x,_,rom,cache)
  x:beginStage('Ruby/Sapphire native field weather')
  local V={BUILD=x.version,FAMILY='rse'}
  local load=require('compat.gen1-rs.Loader').new(x.version,{
    ['src.import.gba.versions']=V,
    ['src.import.gba.extract_scripts']={serialize_lua=function(value)
      return require('src.import.LuaWriter').encode(value):sub(8)
    end}})
  V.SYMS=load('src.import.gba.syms').of(x.version)
  V.sym=V.SYMS.off;V.count=V.SYMS.count
  load('src.import.gba.games.rs.field')(V)
  assert(load('src.import.gba.weather_extract').run(rom,cache,{}))
  local spec={format=1,version=x.version,resources={ROOT..'manifest.lua'},objectPaletteSlots={},
    cycles={},source='ROM: native RS weather OAM, graphics, palettes, drought deltas and daily cycles'}
  for key in pairs(V.WEATHER_GFX.palettes)do
    spec.resources[#spec.resources+1]=ROOT..(key=='fog'and'default'or key)..'.gbapal'
  end
  for _,row in ipairs(V.WEATHER_GFX.blobs)do
    for _,ext in ipairs({'.4bpp','.idx','.rgba'})do
      spec.resources[#spec.resources+1]=ROOT..row.file..ext
    end
  end
  spec.resources[#spec.resources+1]=ROOT..'drought_colors.bin'
  local S=V.SYMS;local at=S.off('gObjectEventGraphicsInfoPointers')
  for i=0,S.count('gObjectEventGraphicsInfoPointers',4)-1 do
    local info=x.rom:pointer(at+i*4)
    if info then spec.objectPaletteSlots[i]=x.rom:u8(info+12)%16 end
  end
  local cycles={length=4,source=spec.source}
  for key,row in pairs(V.WEATHER_GFX.cycles)do
    assert(row.count==4,'Native RS daily weather cycle must have four entries')
    local values,names={},{}
    for i=0,3 do
      local value=rom:get(row.off+i);assert(value<=14 and NAMES[value])
      values[i+1]=value;names[i+1]=NAMES[value]
    end
    spec.cycles[key]=values;cycles[key=='route119'and'ROUTE119_CYCLE'or'ROUTE123_CYCLE']=names
  end
  table.sort(spec.resources)
  local constants=assert(x._constants)
  constants.gen3RsWeather=spec;constants.gen3WeatherNames=NAMES;constants.gen3WeatherCycles=cycles
  constants.gen3BattleWeather={RAIN='RAIN',RAIN_THUNDERSTORM='RAIN',DOWNPOUR='RAIN',
    DROUGHT='SUN',SANDSTORM='SANDSTORM',SNOW='HAIL'}
end
function M.valid(spec,version)
  return(version=='ruby'or version=='sapphire')and type(spec)=='table'and spec.version==version
    and spec.format==1 and type(spec.resources)=='table'and #spec.resources==32
    and type(spec.cycles)=='table'and type(spec.cycles.route119)=='table'and #spec.cycles.route119==4
    and type(spec.cycles.route123)=='table'and #spec.cycles.route123==4
    and type(spec.objectPaletteSlots)=='table'and spec.objectPaletteSlots[0]~=nil
end
function M.missing(version)
  local Fs=require('src.import.CacheFs');local bytes=Fs.read('data/generated/constants.lua')
  local f=bytes and loadstring(bytes);if f then setfenv(f,{})end
  local ok,data=false,nil;if f then ok,data=pcall(f)end
  local spec=ok and data.gen3RsWeather
  if not M.valid(spec,version)then return{'<rs:native-field-weather>'}end
  local missing={}
  for _,path in ipairs(spec.resources)do if not Fs.exists(path)then missing[#missing+1]=path end end
  return missing
end
return M
