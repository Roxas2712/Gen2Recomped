-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- FRLG's six avatar states differ from Hoenn's bike/dive state layout.
local M={}
local supported={firered=true,leafgreen=true}
local ids={boy=0,girl=7,boyBike=1,girlBike=8,boySurf=2,girlSurf=9,
 boyFieldMove=3,girlFieldMove=10}
-- sPlayerAvatarGfxIds: normal, bike, ride, field move, fish, VS Seeker.
local signature=string.char(0,7,1,8,2,9,3,10,4,11,5,12)
function M.avatars(x)
 if not supported[x.version]then return nil end
 local rom=x.rom;local first=rom.data:find(signature,1,true)
 assert(first and not rom.data:find(signature,first+1,true),'Missing or ambiguous native FRLG avatar states')
 local tableAt=assert(x:symbol('gObjectEventGraphicsInfoPointers'))
 for gender=0,1 do
  local palette
  for state=0,5 do
   local id=rom:u8(first-1+state*2+gender)
   local at=assert(rom:pointer(tableAt+id*4),'Missing native FRLG avatar graphics')
   local width,height=rom:u16(at+8),rom:u16(at+10)
   assert(width==((state==1 or state==4)and 32 or 16)and height==32,'Invalid native FRLG avatar dimensions')
   local tag=rom:u16(at+2);palette=palette or tag
   assert(rom:u8(at+12)%16==0,'Native FRLG avatar does not own OBJ palette slot zero')
   -- Green's VS Seeker row deliberately names Red's palette in the ROM.
   if state<5 then assert(tag==palette,'Native FRLG avatar palette disagrees with gender')end
   if state==1 then assert(rom:u8(at+13)==2,'Native FRLG bicycle lacks tyre tracks')end
   if state==2 then assert(rom:u8(at+12)>=128,'Native FRLG ride lacks reflection override')end
  end
 end
 local record={format=1,version=x.version,avatarTable=first-1,graphicsTable=tableAt,
  source=('ROM:sPlayerAvatarGfxIds %07X, FRLG normal/bike/ride/field-move states'):format(first-1)}
 for key,id in pairs(ids)do record[key]=('SPRITE_G3_%03d'):format(id)end
 return record
end
function M.surfPalette(x,used)
 local tableAt=assert(x:symbol('gObjectEventGraphicsInfoPointers'))
 local palettes=x:objectGfxPalettes(assert(x:symbol('sObjectEventSpritePalettes')),
  x:layoutValue('objectEventPaletteCount',0))
 local boy=assert(x.rom:pointer(tableAt));local girl=assert(x.rom:pointer(tableAt+7*4))
 local tag=x.rom:u16(boy+2);local colors=assert(palettes[tag])
 local other=assert(palettes[x.rom:u16(girl+2)])
 -- FldEff_SurfBlob selects OBJ palette zero, the player's own palette.
 -- Both genders share the colors used by this independently drawn sprite.
 for index in pairs(used)do if index~=0 then
  for c=1,3 do assert(colors[index+1]and other[index+1]
   and colors[index+1][c]==other[index+1][c],'Native FRLG mount colors disagree between player palettes')end
 end end
 return colors,tag
end
function M.valid(record,blob,version)
 if not supported[version]then return true end
 if not(type(record)=='table'and record.format==1 and record.version==version
  and type(record.avatarTable)=='number'and type(record.graphicsTable)=='number')then return false end
 for key,id in pairs(ids)do if record[key]~=('SPRITE_G3_%03d'):format(id)then return false end end
 return type(blob)=='table'and blob.frames==6 and blob.frameWidth==32 and blob.frameHeight==32
  and blob.paletteSource=='FRLG player OBJ palette slot 0'
  and blob.image=='assets/generated/overworld/g3_surf_blob.png'
end
function M.missing(version)
 if not supported[version]then return{}end
 local Fs=require('src.import.CacheFs');local raw=Fs.read('data/generated/constants.lua')
 local f=raw and loadstring(raw);if f then setfenv(f,{})end
 local ok,t=false,nil;if f then ok,t=pcall(f)end
 if not(ok and type(t)=='table'and M.valid(t.gen3PlayerSprites,t.gen3SurfBlob,version))then
  return{'<'..version..':native-player-forms-and-surf-mount>'}
 end
 if not Fs.exists(t.gen3SurfBlob.image)then return{t.gen3SurfBlob.image}end
 return{}
end
return M
