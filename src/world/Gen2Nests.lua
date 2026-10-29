-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- FindNest over actual native encounter, landmark and roaming owners. Queries
-- never move a beast, migrate a save, roll an encounter or cache stale slots.
local Landmarks=require('src.world.Gen2Landmarks')
local Species=require('src.core.Gen2SpeciesNames')
local Maps=require('src.core.MapIdentity')
local N={LANDMARK_PALLET_TOWN=0x2e,LANDMARK_FAST_SHIP=0x5e}
function N.regionOf(index,data)return Landmarks.region(data,index)end
function N.landmarkId(data,index)return Landmarks.id(data,index)end
function N.landmark(data,index)return Landmarks.record(data,index)end

function N.find(data,species,region,save)
 if type(data)~='table' or species==nil then return{}end
 local wanted=Species.registryId(data.pokemon,species)
 local kanto,ship=Landmarks.kantoStart(data),Landmarks.index(data,'LANDMARK_FAST_SHIP')
 local out,seen={},{}
 local function add(mapId,roaming)
  local id=Maps.runtimeId(data,mapId)
  local def=data.maps and data.maps[id]
  local index=def and tonumber(def.landmark)
  local where=Landmarks.region(data,index,kanto,ship)
  if not where or seen[index] or region and where~=region or roaming and where~='johto' then return end
  seen[index]=true;out[#out+1]=index
 end
 local function holds(group)
  if type(group)~='table'then return false end
  for _,slot in ipairs(group.slots or{})do
   if type(slot)=='table' and Species.registryId(data.pokemon,slot.species)==wanted then return true end
  end
  for _,timed in pairs(group.byTime or{})do
   if type(timed)=='table'then
    for _,slot in ipairs(timed.slots or{})do
     if type(slot)=='table' and Species.registryId(data.pokemon,slot.species)==wanted then return true end
    end
   end
  end
  return false
 end
 -- Only grass (all times) and water. Fishing, trees and swarm replacements
 -- are deliberately absent from the cartridge's AREA search.
 for mapId,entry in pairs(data.encounters or{})do
  if type(entry)=='table' and (holds(entry.grass) or holds(entry.water))then add(mapId)end
 end
 local Roamers=require('src.world.RoamMons')
 for name in pairs(save and save.g2Roam or{})do
  local slot=Roamers.entry(save,name)
  if slot and Species.registryId(data.pokemon,slot.speciesId or slot.species or name)==wanted then
   add(slot.mapId,true)
  end
 end
 table.sort(out)
 return out
end
return N
