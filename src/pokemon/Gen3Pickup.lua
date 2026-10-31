-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Silent post-victory party ability. Nothing here runs from a draw callback.
local M={}
local V=require('src.core.GameVersion')
local function integer(n,lo,hi)return type(n)=='number'and n%1==0 and n>=lo and n<=hi end
local function cuts(list,count,last)
 if type(list)~='table'or#list~=count then return false end
 local previous=0
 for _,n in ipairs(list)do if not integer(n,previous+1,last)then return false end;previous=n end
 return true
end
local function admitted(data)
 local edition=V.get();local p=require('src.import.Gen3PickupProfiles').get(edition,V.info(edition).sha1)
 local record=data.constants and data.constants.gen3Pickup
 if not(p and type(record)=='table'and record.schema==1 and record.edition==edition
  and record.romSha1==p.sha1 and record.style==p.style)then return end
 local ids={}
 for id,def in pairs(data.items or{})do
  if type(id)=='string'and type(def)=='table'and integer(def.index,1,65535)then ids[def.index]=id end
 end
 local function items(list,count)
  if type(list)~='table'or#list~=count then return false end
  for _,index in ipairs(list)do if not ids[index]then return false end end
  return true
 end
 if p.style=='fixed'then
  if not(items(record.items,p.count)and cuts(record.thresholds,p.count-1,99))then return end
 else
  if not(items(record.common,18)and items(record.rare,11)and cuts(record.thresholds,9,98)
   and record.thresholds[9]==98)then return end
 end
 return record,ids,items
end
local function tableIndex(thresholds,roll)
 for i,cut in ipairs(thresholds)do if roll<cut then return i end end
 return #thresholds+1
end
function M.afterBattle(battle)
 if battle._gen3PickupDone then return end
 battle._gen3PickupDone=true
 if not V.isGen3()or battle.result~='win'or battle.kind=='link'or battle.demo or battle.pokedudeDemo then return end
 local data,save=battle.data,battle.game.save
 local record,ids,items=admitted(data)
 if not record then return end -- Older imports retain their previous RNG stream.
 local pyramid,round,mode
 if record.edition=='emerald'then
  local ow=battle.game.overworld
  local mapId=ow and ow.map and ow.map.id
  mapId=require('src.core.MapIdentity').sourceId(data,mapId)
  if require('src.script.Gen3BattlePike').MAPS[mapId]then return end
  local P=require('src.script.Gen3BattlePyramid')
  if P.location(mapId)~=P.LOCATION_NONE then
   pyramid=record.pyramid
   if not(type(pyramid)=='table'and items(pyramid.level50,200)and items(pyramid.open,200)
    and cuts(pyramid.thresholds,10,100)and pyramid.thresholds[10]==100)then return end
   -- Reading the existing challenge must not create frontier state outdoors.
   local s=save.gen3Frontier or{}
   mode=math.floor(tonumber(s.data and s.data[1])or 0)
   local streak=s.facStreaks and s.facStreaks[P.FACILITY]
   round=math.min(19,math.max(0,math.floor((tonumber(streak and streak['0:'..mode])or 0)/7)))
  end
 end
 local Abilities=require('src.battle.Abilities');local Party=require('src.pokemon.Party')
 for i=1,6 do
  local mon=save.party and save.party[i]
  if type(mon)=='table'and not Party.isEgg(mon)and mon.species~='EGG'
   and(mon.item==nil or mon.item==0 or mon.item==''or mon.item=='NONE')
   and Abilities.of({mon=mon,def=data.pokemon[mon.species]})=='PICKUP'then
   if battle.rng(0,65535)%10==0 then
    local roll=battle.rng(0,65535)%100;local item
    if pyramid then
     item=(mode==0 and pyramid.level50 or pyramid.open)[round*10+tableIndex(pyramid.thresholds,roll)]
    elseif record.style=='fixed'then item=record.items[tableIndex(record.thresholds,roll)]
    else
     local bucket=math.min(9,math.max(0,math.floor(((tonumber(mon.level)or 1)-1)/10)))
     if roll>=98 then item=record.rare[bucket+100-roll]
     else item=record.common[bucket+tableIndex(record.thresholds,roll)]end
    end
    mon.item=ids[item]
   end
  end
 end
end
return M
