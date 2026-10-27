-- Native RS ride layers and original-order actor pictures for the GBA scene.
local M={};local ROOT='data/generated/gba/cable_car/'
local NAMES={'OBJ_EVENT_GFX_RIVAL_BRENDAN_NORMAL','OBJ_EVENT_GFX_RIVAL_MAY_NORMAL',
  'OBJ_EVENT_GFX_HIKER','OBJ_EVENT_GFX_CAMPER','OBJ_EVENT_GFX_PICNICKER','OBJ_EVENT_GFX_POOCHYENA'}
function M.extract(x,load,rom,cache)
  x:beginStage('Ruby/Sapphire native cable-car ride')
  local reader=load('src.import.gba.rs.extract_cable_car')
  assert(reader.run(rom,cache,{}))
  local A=load('src.import.gba.rs.assets');local K=load('src.import.gba.rse.boot_gfx')
  local c=A.context(rom,cache,{},'cable_car/actors')
  local S=load('src.import.gba.syms').of(x.version)
  local ids=load('src.core.game3.constants.ruby.event_objects').byName
  local palettes=x:objectGfxPalettes(assert(x:symbol('sObjectEventSpritePalettes')),
    x:layoutValue('objectEventPaletteCount',0))
  local spec={format=1,version=x.version,actors={},graphics={},resources={ROOT..'manifest.lua'},
    source='ROM: RS cable-car layers, OAM, palettes and complete native actor picture arrays'}
  for _,file in ipairs(reader.FILES)do spec.resources[#spec.resources+1]=ROOT..file end
  for _,name in ipairs(NAMES)do
    local id=assert(ids[name]);local info=assert(x.rom:pointer(S.off('gObjectEventGraphicsInfoPointers')+id*4))
    local pictures=assert(x.rom:pointer(info+28));local count
    for _,label in ipairs(S.namesAt(pictures))do
      if label:match('^gObjectEventPicTable_')then count=S.count(label,8);break end
    end
    assert(count and count>=9 and count<32,'Incomplete native cable-car actor')
    local w,h=x.rom:u16(info+8),x.rom:u16(info+10)
    assert((w==16 or w==32)and h==32,'Unsupported native cable-car actor geometry')
    local tag=x.rom:u16(info+2);local colors=assert(palettes[tag]);local palette={}
    for i,rgb in ipairs(colors)do
      palette[i-1]=math.floor(rgb[1]/8)+math.floor(rgb[2]/8)*32+math.floor(rgb[3]/8)*1024
    end
    local indices={};local subsprites=x.rom:pointer(info+20)
    for frame=0,count-1 do
      local at=assert(x.rom:pointer(pictures+frame*8));local bytes=x.rom:u16(pictures+frame*8+4)
      assert(bytes==w*h/2,'Unsupported native cable-car actor picture size')
      local px=x:overworldFramePixels(x.rom:bytes(at,bytes),w,h,subsprites)
      for y=1,h do for col=1,w do indices[#indices+1]=px[y][col]end end
    end
    local png=c:png('actor_'..id..'.png',w,h*count,indices,palette,true)
    spec.actors[id]={w=w,h=h,frames=count,png=png,palette=K.palList(palette,0,16),paletteTag=tag}
    spec.graphics[name]=id;spec.resources[#spec.resources+1]=png
  end
  x._constants.gen3RsCableCar=spec
end
function M.valid(spec,version)
  if(version~='ruby'and version~='sapphire')or type(spec)~='table'or spec.format~=1
    or spec.version~=version or type(spec.resources)~='table'or #spec.resources~=12
    or type(spec.actors)~='table'or type(spec.graphics)~='table'then return false end
  for _,name in ipairs(NAMES)do
    local id=spec.graphics[name];local row=id and spec.actors[id]
    if type(row)~='table'or type(row.png)~='string'or type(row.palette)~='table'
      or #row.palette~=16 or type(row.frames)~='number'or row.frames<9 then return false end
  end
  return true
end
function M.missing(version)
  local Fs=require('src.import.CacheFs');local bytes=Fs.read('data/generated/constants.lua')
  local f=bytes and loadstring(bytes);if f then setfenv(f,{})end
  local ok,data=false,nil;if f then ok,data=pcall(f)end
  local spec=ok and data.gen3RsCableCar
  if not M.valid(spec,version)then return{'<rs:native-cable-car>'}end
  local missing={}
  for _,path in ipairs(spec.resources)do if not Fs.exists(path)then missing[#missing+1]=path end end
  return missing
end
return M
