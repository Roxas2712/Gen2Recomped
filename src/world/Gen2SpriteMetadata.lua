-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Publish the species already identified by native imported mon-icon rows.
-- Do not infer a species from an arbitrary authored sprite or asset filename.
local Version=require('src.core.GameVersion')
local Names=require('src.core.Gen2SpeciesNames')
local M={}
function M.publish(data)
 if not Version.isGen2()or type(data)~='table'or type(data.sprites)~='table'then return false end
 local changed=false
 for id,def in pairs(data.sprites)do
  local index=type(id)=='string'and tonumber(id:match('^SPRITE_MON_(%d+)$'))
  if index and type(def)=='table'and def.id==id and def.monIcon==true then
   local species=Names.fromNumber(data,index)
   local mon=data.pokemon and data.pokemon[species]
   if mon and tonumber(mon.index)==index and def.species==nil and def.spriteType==nil then
    def.species,def.spriteType=species,'POKEMON_SPRITE';changed=true
   end
  end
 end
 return changed
end
return M
