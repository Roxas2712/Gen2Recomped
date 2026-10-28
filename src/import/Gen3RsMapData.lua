local M={}
local Loader=require('compat.gen1-rs.Loader')
-- RS has a full show-name byte, not Emerald's movement/name bitfield.
-- Movement policy follows pokeruby overworld.c, item_use.c and bike.c;
-- the four cycling exceptions are header identities from the sized symbols.
function M.header(x,at,def)
  if not x._rsCyclingHeaders then
    local S=Loader.new(x.version)('src.import.gba.syms').of(x.version)
    x._rsCyclingHeaders={
      [S.off('Route110_SeasideCyclingRoadSouthEntrance')]=true,
      [S.off('Route110_SeasideCyclingRoadNorthEntrance')]=true,
      [S.off('SeafloorCavern_Room9')]=false,[S.off('CaveOfOrigin_B4F')]=false}
  end
  local kind=x.rom:u8(at+23)
  local cycling=kind~=8 and kind~=9 and kind~=5
  if x._rsCyclingHeaders[at]~=nil then cycling=x._rsCyclingHeaders[at]end
  def.allowCycling=cycling;def.allowEscaping=kind==4;def.allowRunning=kind~=8
  def.showMapName=x.rom:u8(at+26)~=0
  return def
end
function M.metadata(x)
  local load=Loader.new(x.version);local S=load('src.import.gba.syms').of(x.version)
  local at=S.off('gRegionMapEntries');local count=S.count('gRegionMapEntries',8)
  assert(count==88,'Native RS map-section count')
  local sections,rects,onMap,cells={},{},{},{}
  for i=0,count-1 do
    local o=at+i*8;local p=assert(x.rom:pointer(o+4))
    sections[i]=assert(x:readText(p,32,nil,{rsNameEnd=true}),'Native RS section name '..i)
    rects[i]={x=x.rom:u8(o),y=x.rom:u8(o+1),w=x.rom:u8(o+2),h=x.rom:u8(o+3)}
  end
  local layout=S.off('sRegionMapLayout');assert(S.size('sRegionMapLayout')==28*15)
  for i=0,28*15-1 do local id=x.rom:u8(layout+i);assert(id<=count);cells[i+1]=id end
  for _,map in pairs(x._maps or {})do
    local id=map.regionMapSection;local r=rects[id]
    if r and r.w>0 and r.h>0 and r.x+r.w<=28 and r.y+r.h<=15 then onMap[id]=true end
  end
  local c=x._constants or {};x._constants=c
  c.gen3MapSections=sections;c.gen3MapSectionRects=rects;c.gen3RegionMapPlaces=onMap
  c.gen3RegionMapGrid={width=28,height=15}
  c.gen3RegionMapLayout={width=28,height=15,cursorX=1,cursorY=2,none=count,cells=cells,
    source=('ROM:sRegionMapLayout %07X'):format(layout)}
  c.gen3MapSectionSource=('ROM:gRegionMapEntries %07X, %d native RS sections'):format(at,count)
  x:write('constants',c)
  require('src.core.Logger').info('Gen3 map sections (RS): %d native names and 420 cursor cells',count)
end
function M.presentation(x,load,rom,cache)
  x:beginStage('Ruby/Sapphire native region map')
  local C=require('compat.gen1-rs.Constants').new(load)
  local V=load('src.import.gba.versions')
  local S=V.SYMS
  V.REGION_MAP_ENTRIES=S.off('gRegionMapEntries');V.REGION_MAP_ENTRY_COUNT=S.count('gRegionMapEntries',8)
  -- Loader's versions fallback is a value factory; bind this one configured
  -- object for the original extractor and all of its private dependencies.
  local nativeLoad=Loader.new(x.version,{
    ['src.import.gba.versions']=V,
    ['src.core.game3.constants']={of=function()return C end},
  })
  nativeLoad('src.import.gba.rs.assets').text=function(_,off)return x:readText(off,1024,nil,{rsNameEnd=true})end
  assert(nativeLoad('src.import.gba.rs.extract_region_map').run(rom,cache))
  local text={}
  for _,key in ipairs({'gOtherText_FlyToWhere','gOtherText_Hoenn'})do text[key]=assert(x:readText(S.off(key)))end
  x._constants.gen3RsMap={version=x.version,format=1,map='data/generated/gba/rse/region_map/manifest.lua',
    sections='data/generated/gba/region_map/map_sections.lua',text=text}
end
function M.missing(version)
  local Fs=require('src.import.CacheFs');local missing={}
  for _,path in ipairs({'data/generated/gba/rse/region_map/manifest.lua','data/generated/gba/region_map/map_sections.lua'})do
    local raw=Fs.read(path);local chunk=raw and loadstring(raw,'@'..path);if chunk then setfenv(chunk,{})end
    local ok,man=false,nil;if chunk then ok,man=pcall(chunk)end
    if not ok or type(man)~='table' or type(man.sections)~='table'
      or (man.files and (man.assetLayout~='rs'or type(man.layout)~='table'))
      or (not man.files and man.layout~='rs')then missing[#missing+1]=path
    elseif man.files then
      if man.game~=version then missing[#missing+1]=path end
      for _,file in ipairs(man.files)do if not Fs.exists(file)then missing[#missing+1]=file end end
    elseif man.build~=version then missing[#missing+1]=path end
  end
  return missing
end
return M
