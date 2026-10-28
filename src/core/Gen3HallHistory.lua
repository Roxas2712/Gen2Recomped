-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Persist the native ceremony's compact roster through the host save writer.
-- The induction count remains numeric; records retain stable host species IDs.
local M={LIMIT=50}
local function uint(value,max)
 value=tonumber(value)or 0
 assert(value%1==0 and value>=0 and value<=(max or 4294967295),'Invalid native Hall identity')
 return value
end
function M.fromNative(data,session)
 local teams=session.hallOfFameTeams
 local native=assert(type(teams)=='table'and teams[#teams],'Native ceremony has not recorded its team')
 assert(type(native)=='table'and#native>=1 and#native<=6,'Invalid native Hall team')
 local species={};for key,def in pairs(data.pokemon)do if def.index then species[def.index]=key end end
 local team={}
 for i,mon in ipairs(native)do
  local egg=mon.species==412
  local raw=egg and session.party and session.party[i]and session.party[i]._hostMon
  local key=egg and raw and raw.species or species[mon.species]
  assert(key and data.pokemon[key],'Unknown native Hall species '..tostring(mon.species))
  assert(type(mon.nickname)=='string','Missing native Hall nickname')
  team[i]={species=key,isEgg=egg or nil,nickname=mon.nickname,level=uint(mon.level,100),
   trainerId=uint(mon.trainerId),otSecretId=uint(mon.otSecretId,65535),personality=uint(mon.personality)}
 end
 return team
end
function M.recordScene(scene)
 if scene.hallTeamRecorded then return scene.hallTeamRecorded end
 local save=assert(scene.game.save)
 local team=M.fromNative(scene.game.data,scene.session)
 local teams=save.gen3HallOfFameTeams
 assert(teams==nil or type(teams)=='table','Invalid stored Gen3 Hall history')
 teams=teams or{}
 -- Build the compact snapshot before touching history, so an unsupported
 -- source cannot discard a previous team. Retry/raised IO reuses this record.
 teams[#teams+1]=team
 while#teams>M.LIMIT do table.remove(teams,1)end
 save.gen3HallOfFameTeams=teams
 scene.hallTeamRecorded=team
 return team
end
function M.nativeTeams(save,data)
 local stored=save and save.gen3HallOfFameTeams
 if stored==nil then return{}end
 if type(stored)~='table'or#stored>M.LIMIT then return nil,'Invalid Gen3 Hall history'end
 local teams={}
 for i,team in ipairs(stored)do
  if type(team)~='table'or#team<1 or#team>6 then return nil,'Invalid Gen3 Hall team'end
  local out={}
  for j,mon in ipairs(team)do
   local def=type(mon)=='table'and data.pokemon[mon.species]
   if not(def and type(def.index)=='number'and type(mon.nickname)=='string')then return nil,'Unknown Gen3 Hall member'end
   out[j]={species=mon.isEgg and 412 or def.index,nickname=mon.nickname,level=mon.level,
    trainerId=mon.trainerId,otSecretId=mon.otSecretId,personality=mon.personality,_hostMon=mon}
  end
  teams[i]=out
 end
 return teams
end
return M
