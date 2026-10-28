-- Original RS dex resources, selected exclusively from the verified edition.
local M={}
local ROOT='data/generated/gba/'
function M.extract(x,sourceLoad,rom,cache)
  x:beginStage('Ruby/Sapphire native Pokedex')
  local S=sourceLoad('src.import.gba.syms').of(x.version)
  local V={BUILD=x.version,SYMS=S,NUM_SPECIES=S.count('gSpeciesNames',11),
    NATIONAL_DEX_COUNT=S.count('gPokedexEntries',36)-1,
    POKEDEX_ENTRIES=S.off('gPokedexEntries'),SPECIES_TO_NATIONAL=S.off('gSpeciesToNationalPokedexNum'),
    HOENN_TO_NATIONAL=S.off('gHoennToNationalOrder'),
    POKEDEX_ORDERS={alphabetical=S.off('gPokedexOrder_Alphabetical'),
      weight=S.off('gPokedexOrder_Weight'),height=S.off('gPokedexOrder_Height')}}
  local load,chrome
  -- This reference extractor also offers an optional loose-file fallback.
  -- All outputs belong to the host cache; disable only that fallback here.
  local function extractChrome()
    if not chrome then
      local f=assert(love.filesystem.load('compat/gen1-rs/reference/src/import/gba/pokedex_chrome_extract.lua'))
      setfenv(f,setmetatable({require=function(n)return load(n)end,io={open=function()return nil end}},{__index=_G}))
      chrome=f()
    end
    return chrome
  end
  load=require('compat.gen1-rs.Loader').new(x.version,{
    ['src.import.gba.versions']=V,
    ['src.import.gba.layouts.registry']={active=function()return load('src.import.gba.layouts.ruby')end},
    ['src.core.game3.constants']={of=function()
      local species=load('src.core.game3.constants.ruby.species')
      return {require=function(_,family,key)assert(family=='species');return assert(species.byName[key])end}
    end},
    ['src.import.gba.pokedex_chrome_extract']={extractOrders=function(...)return extractChrome().extractOrders(...)end},
  })
  -- Keep the reference RS text decoder: the native selection triangle and
  -- printer controls are meaningful even when no ordinary letters occur.
  assert(load('src.import.gba.rs.extract_pokedex').run(rom,cache,{}))
  assert(load('src.import.gba.rs.extract_pokedex_detail').run(rom,cache,{}))
  assert(extractChrome().extractEntries(rom,cache,ROOT..'pokemon/pokedex'))
  local resources={ROOT..'pokemon/pokedex/entries.lua',ROOT..'pokemon/pokedex/regional.lua'}
  local c=load('src.import.gba.rs.assets').context(rom,cache,{},'pokemon/footprints')
  local tableAt=S.off('sMonFootprintTable')
  for sp=1,V.NUM_SPECIES-1 do
    local off=assert(c:ptr(tableAt+sp*4),'Native RS footprint pointer')
    resources[#resources+1]=c:write(sp..'.rgba',extractChrome().bakeFootprint(rom:readString(off,32),255,255,255))
  end
  c=load('src.import.gba.rs.assets').context(rom,cache,{},'trainers/front')
  for id=0,1 do
    local gfx=c:lzAt(assert(c:ptr(S.off('gTrainerFrontPicTable')+id*8)))
    local pal=c:palFrom(c:lzAt(assert(c:ptr(S.off('gTrainerFrontPicPaletteTable')+id*8))),16)
    local idx={};for y=0,63 do for xx=0,63 do
      local tile=math.floor(y/8)*8+math.floor(xx/8)
      local b=gfx:byte(tile*32+(y%8)*4+math.floor(xx%8/2)+1)
      idx[y*64+xx+1]=xx%2==0 and b%16 or math.floor(b/16)
    end end
    resources[#resources+1]=c:png(id..'.png',64,64,idx,pal,true)
  end
  x._constants.gen3RsPokedex={format=1,version=x.version,resources=resources,
    source='ROM: native RS list/search/info, two description pages, area/cry/size and sorting tables'}
end
function M.missing(version)
  local Fs=require('src.import.CacheFs');local out={}
  local function read(path)
    local raw=Fs.read(path);local f=raw and loadstring(raw);if not f then return end
    setfenv(f,{});local ok,v=pcall(f);return ok and type(v)=='table'and v or nil
  end
  local spec=(read('data/generated/constants.lua')or {}).gen3RsPokedex
  if not spec or spec.version~=version or spec.format~=1 or type(spec.resources)~='table'or #spec.resources<400 then
    return {'<rs:native-pokedex>'}
  end
  for _,path in ipairs(spec.resources)do if not Fs.exists(path)then out[#out+1]=path end end
  for _,sub in ipairs({'pokedex','pokedex_detail'})do
    local path=ROOT..'rse/'..sub..'/manifest.lua';local man=read(path)
    if not man or man.game~=version or man.assetLayout~='rs'or type(man.files)~='table'or #man.files==0
      or (sub=='pokedex_detail'and(type(man.strings)~='table'or not man.strings.RightPointingTriangle))then
      out[#out+1]=path
    else for _,file in ipairs(man.files)do if not Fs.exists(file)then out[#out+1]=file end end end
  end
  return out
end
return M
