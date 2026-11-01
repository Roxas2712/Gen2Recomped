-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Native indexed layers/OAM over the existing pinned GBA scene renderer.
local M={ROOT='data/generated/gba/rayquaza_scene/'}
local layers={'clouds1','clouds2','clouds3','tf_bg','tf_rayquaza','de_light','de_bg','de_bg_top',
 'ch_orbs','ch_rayquaza','ch_streaks','ch_bg','ca_light','ca_bg','ca_ring'}
local sprites={'dfp_groudon','dfp_groudon_shoulder','dfp_groudon_claw','dfp_kyogre','dfp_kyogre_pectoral',
 'dfp_kyogre_dorsal','df_groudon','df_groudon_shoulder','df_groudon_claw','df_kyogre','df_kyogre_pectoral',
 'df_kyogre_dorsal','tf_smoke','de_rayquaza','de_rayquaza_tail','ca_groudon','ca_groudon_tail','ca_kyogre',
 'ca_rayquaza','ca_rayquaza_tail','ca_splash'}
function M.resources()
 local out={M.ROOT..'manifest.lua'}
 for _,key in ipairs(layers)do out[#out+1]=M.ROOT..key..'_idx.png'end
 for _,key in ipairs(sprites)do out[#out+1]=M.ROOT..key..'.png'end
 return out
end
function M.extract(x)
 assert(x.version=='emerald');x:beginStage('Emerald original Rayquaza cinematic')
 local load=require('compat.gen1-rs.Loader').new('emerald',{__package={loaded={}}})
 local rom={id='emerald'}
 function rom:get(at)return x.rom:u8(at)end
 function rom:u16(at)return x.rom:u16(at)end
 function rom:u32(at)return x.rom:u32(at)end
 function rom:readString(at,size)
  assert(at>=0 and at+size<=x.rom.size,'Emerald cinematic resource outside cartridge')
  return x.rom.data:sub(at+1,at+size)
 end
 local Fs=require('src.import.CacheFs');local cache={write=function(_,path,bytes)
  local ok,why=Fs.write(path,bytes);assert(ok,why);return true
 end}
 local ok,man=load('src.import.gba.rse.rayquaza_scene_extract').run(rom,cache,{game='emerald'})
 assert(ok and type(man)=='table')
 local songs=load('src.core.game3.constants.emerald.songs').byName
 local species=load('src.core.game3.constants.emerald.species').byName
 x._constants.gen3EmeraldRayScene={format=1,version='emerald',manifest=M.ROOT..'manifest.lua',
  resources=M.resources(),
  song=assert(songs.MUS_RAYQUAZA_APPEARS),rayquaza=assert(species.SPECIES_RAYQUAZA)}
end
function M.valid(spec,version)
 if version~='emerald'or type(spec)~='table'or spec.version~=version or spec.format~=1
  or spec.manifest~=M.ROOT..'manifest.lua'
  or type(spec.song)~='number'or spec.song<=0 or type(spec.rayquaza)~='number'or spec.rayquaza<=0
  or type(spec.resources)~='table'then return false end
 local resources=M.resources();if #spec.resources~=#resources then return false end
 for i,path in ipairs(resources)do if spec.resources[i]~=path then return false end end
 return true
end
function M.missing()
 local Fs=require('src.import.CacheFs')
 local function read(path)
  local bytes=Fs.read(path);local f=bytes and loadstring(bytes);if not f then return end
  setfenv(f,{});local ok,value=pcall(f);return ok and type(value)=='table'and value or nil
 end
 local spec=(read('data/generated/constants.lua')or{}).gen3EmeraldRayScene
 if not M.valid(spec,'emerald')then return{'<emerald:original-rayquaza-scene>'}end
 local out={};for _,path in ipairs(spec.resources)do if not Fs.exists(path)then out[#out+1]=path end end
 local man=read(spec.manifest)
 if not man or man.format~=1 or man.game~='emerald'
  or type(man.layers)~='table'or type(man.sprites)~='table'or type(man.palettes)~='table'
  or type(man.smokeCoords)~='table'or #man.smokeCoords~=10 then
  out[#out+1]=spec.manifest;return out
 end
 for _,key in ipairs(layers)do local row=man.layers[key]
  local size=key=='ca_ring'and 128 or 256
  if type(row)~='table'or row.index~=M.ROOT..key..'_idx.png'or row.w~=size or row.h~=size
   or row.bpp~=((key=='tf_rayquaza'or key=='ca_ring')and 8 or 4)then out[#out+1]='<emerald:ray-layer-'..key..'>'end
 end
 for _,key in ipairs(sprites)do local row=man.sprites[key]
  if type(row)~='table'or row.png~=M.ROOT..key..'.png'or type(row.frames)~='number'or row.frames<1
   or type(row.anims)~='table'or type(row.paletteTag)~='number'then out[#out+1]='<emerald:ray-sprite-'..key..'>'end
 end
 return out
end
return M
