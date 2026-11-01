-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Original Emerald cable-car layers, OAM and complete native actor arrays.
local M={ROOT='data/generated/gba/cable_car/'}
local actors={
 {'OBJ_EVENT_GFX_RIVAL_BRENDAN_NORMAL',100}, {'OBJ_EVENT_GFX_RIVAL_MAY_NORMAL',105},
 {'OBJ_EVENT_GFX_HIKER',55}, {'OBJ_EVENT_GFX_CAMPER',31},
 {'OBJ_EVENT_GFX_PICNICKER',32}, {'OBJ_EVENT_GFX_ZIGZAGOON_1',98},
}
local files={'manifest.lua','bg_tiles.4bpp','cable_car.png','door.png','cable.png','ash.png'}
function M.resources()
 local out={};for _,name in ipairs(files)do out[#out+1]=M.ROOT..name end
 for _,row in ipairs(actors)do out[#out+1]=M.ROOT..'actors/actor_'..row[2]..'.png'end
 return out
end
function M.extract(x)
 assert(x.version=='emerald','Original Emerald cable-car assets require Emerald')
 x:beginStage('Emerald original cable-car ride')
 local load=require('compat.gen1-rs.Loader').new('emerald',{__package={loaded={}}})
 local K=load('src.import.gba.rse.boot_gfx');local S=load('src.import.gba.syms').of('emerald')
 local rom={id='emerald'}
 function rom:get(off)return x.rom:u8(off)end
 function rom:u16(off)return x.rom:u16(off)end
 function rom:u32(off)return x.rom:u32(off)end
 function rom:readString(off,size)
  assert(off>=0 and off+size<=x.rom.size,'Emerald cable-car resource outside cartridge')
  return x.rom.data:sub(off+1,off+size)
 end
 local cache={write=function(_,path,bytes)
  local ok,why=require('src.import.CacheFs').write(path,bytes);assert(ok,why);return true
 end}
 local c=K.context(rom,cache,{},'cable_car')
 local function words(bytes)
  assert(#bytes%2==0,'Incomplete Emerald cable-car tilemap word')
  local out={};for i=1,#bytes,2 do out[#out+1]=bytes:byte(i)+bytes:byte(i+1)*256 end;return out
 end
 local gfx=c:lz('gCableCarBg_Gfx');assert(#gfx>0 and #gfx%32==0)
 c:write('bg_tiles.4bpp',gfx)
 local bg=c:pal('gCableCarBg_Pal',64);local car=c:pal('gCableCar_Pal',16);local fog=c:pal('gFogPalette',16)
 local sprites={
  car=c:strip('cable_car',c:lz('gCableCar_Gfx'),64,64,1,car),
  door=c:strip('door',c:lz('gCableCarDoor_Gfx'),16,8,1,car),
  cable=c:strip('cable',c:lz('gCableCarCable_Gfx'),16,16,1,car),
  ash=c:strip('ash',c:raw('gWeatherAshTiles'),64,64,2,fog),
 }
 local templates={car=S.off('sSpriteTemplates_CableCar'),door=S.off('sSpriteTemplates_CableCar')+24,cable=S.off('sSpriteTemplate_Cable')}
 for key,at in pairs(templates)do
  local oam=c:readOam(c:ptr(at+4));local sprite=sprites[key]
  sprite.priority,sprite.affineMode,sprite.objMode=oam.priority,oam.affineMode,oam.objMode
  sprite.tileTag,sprite.paletteTag=c:u16(at),c:u16(at+2)
 end
 c:finish({screen='cable_car',layout='emerald',assetLayout='emerald',build='emerald',
  bgTiles=c:path('bg_tiles.4bpp'),bgTileCount=#gfx/32,
  tilemaps={ground=words(c:lz('sGround_Tilemap')),trees=words(c:lz('cable_car.o:sTrees_Tilemap')),
   bgMountains=words(c:lz('sBgMountains_Tilemap')),pylonTop=words(c:raw('sPylonTop_Tilemap')),
   pylonPole=words(c:lz('sPylonPole_Tilemap'))},sprites=sprites,
  palettes={bg=K.palList(bg,0,64),car=K.palList(car,0,16),fog=K.palList(fog,0,16)}})
 local palettes=x:objectGfxPalettes(assert(x:symbol('sObjectEventSpritePalettes')),x:layoutValue('objectEventPaletteCount',0))
 local ac=K.context(rom,cache,{},'cable_car/actors')
 local spec={format=1,version='emerald',actors={},graphics={},resources=M.resources(),
  source='ROM: Emerald cable-car layers, OAM, palettes and complete original actor picture arrays'}
 for _,entry in ipairs(actors)do
  local name,id=entry[1],entry[2]
  local info=assert(x.rom:pointer(S.off('gObjectEventGraphicsInfoPointers')+id*4))
  local pictures=assert(x.rom:pointer(info+28));local count
  for _,label in ipairs(S.namesAt(pictures))do if label:match('^sPicTable_')then count=S.count(label,8);break end end
  assert(count and count>=9 and count<64,('Incomplete Emerald cable-car actor %s (%d) at %X: %s'):format(name,id,pictures,tostring(count)))
  local w,h=x.rom:u16(info+8),x.rom:u16(info+10)
  assert((w==16 or w==32)and(h==16 or h==32),'Unsupported Emerald cable-car actor geometry')
  local tag=x.rom:u16(info+2);local palette={}
  for i,rgb in ipairs(assert(palettes[tag]))do
   palette[i-1]=math.floor(rgb[1]/8)+math.floor(rgb[2]/8)*32+math.floor(rgb[3]/8)*1024
  end
  local indices={};local subsprites=x.rom:pointer(info+20)
  for frame=0,count-1 do
   local at=assert(x.rom:pointer(pictures+frame*8));local size=x.rom:u16(pictures+frame*8+4)
   assert(size==w*h/2,'Invalid original Emerald cable-car actor picture size')
   local px=x:overworldFramePixels(x.rom:bytes(at,size),w,h,subsprites)
   for y=1,h do for column=1,w do indices[#indices+1]=px[y][column]end end
  end
  local png=ac:png('actor_'..id..'.png',w,h*count,indices,palette,true)
  spec.actors[id]={w=w,h=h,frames=count,png=png,palette=K.palList(palette,0,16),paletteTag=tag}
  spec.graphics[name]=id
 end
 x._constants.gen3EmeraldCableCar=spec
end
function M.valid(spec,version)
 if version~='emerald'or type(spec)~='table'or spec.format~=1 or spec.version~='emerald'
  or type(spec.resources)~='table'or #spec.resources~=12 or type(spec.actors)~='table'or type(spec.graphics)~='table'then return false end
 for i,path in ipairs(M.resources())do if spec.resources[i]~=path then return false end end
 for _,entry in ipairs(actors)do
  local name,id=entry[1],entry[2];local row=spec.actors[id]
  if spec.graphics[name]~=id or type(row)~='table'or row.png~=M.ROOT..'actors/actor_'..id..'.png'
   or type(row.palette)~='table'or#row.palette~=16 or type(row.frames)~='number'or row.frames<9
   or(row.w~=16 and row.w~=32)or(row.h~=16 and row.h~=32)then return false end
 end
 return true
end
function M.missing()
 local Fs=require('src.import.CacheFs')
 local function read(path)
  local raw=Fs.read(path);local chunk=raw and loadstring(raw);if chunk then setfenv(chunk,{})end
  local ok,data=false,nil;if chunk then ok,data=pcall(chunk)end
  return ok and type(data)=='table'and data or nil
 end
 local spec=(read('data/generated/constants.lua')or{}).gen3EmeraldCableCar
 if not M.valid(spec,'emerald')then return{'<emerald:native-cable-car>'}end
 local out={};for _,path in ipairs(spec.resources)do if not Fs.exists(path)then out[#out+1]=path end end
 local art=read(M.ROOT..'manifest.lua')
 if not art or art.format~=1 or art.game~='emerald'or art.assetLayout~='emerald'
  or art.build~='emerald'or type(art.tilemaps)~='table'or type(art.sprites)~='table'
  or type(art.palettes)~='table'then out[#out+1]=M.ROOT..'manifest.lua'end
 return out
end
return M
