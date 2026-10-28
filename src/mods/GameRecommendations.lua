-- Edition-aware selection from the existing catalogue, never from mod names.
-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
local M={}
local Versions=require('src.core.GameVersion')
local Targets=require('src.mods.ModTargets')
local Semver=require('src.mods.Semver')
local Engine=require('src.core.Version')
local Index=require('src.mods.ModIndex')
local function generation(version)
 local info=Versions.info(version)
 return info and not info.external and info.generation
end
local function listed(list,value)
 for _,item in ipairs(list or {})do if tonumber(item)==value then return true end end
 return false
end
function M.supports(entry,version,installed)
 local gen=generation(version)
 -- Native cartridges have separate mod formats/installers. A GBA label alone
 -- must never recommend RPG Lua packages for Pinball or RomFS games.
 if not gen then return false end
 if entry.games and #entry.games>0 then
  if not Targets.supports({games=Targets.normalize(entry.games)},version)then return false end
 end
 local gens=entry.supportedGens or entry.generations
 if gens and #gens>0 and not listed(gens,gen)then return false end
 if entry.games and #entry.games>0 or gens and #gens>0 then return true end
 for _,claim in ipairs(entry.compatibility or {})do
  if type(claim)=='table'and claim.engine=='g1r'then return gen==1 end
 end
 -- Old installed manifests retain the loader's default scope. Unknown online
 -- scope is not enough to endorse a new recommendation.
 return installed==true
end
function M.compatible(entry,version)
 if not M.supports(entry,version,false)then return false end
 if entry.api and (entry.api<1 or entry.api>Engine.modApi)then return false end
 if entry.game_version then
  local ok,match=pcall(Semver.satisfies,Engine.engine,entry.game_version)
  if not ok or not match then return false end
 end
 return true
end
local function repository(value)
 return type(value)=='string'and value:lower():gsub('%.git$','')or nil
end
function M.select(version,mods,index,week)
 local owned,available,ids,repos={},{},{},{}
 for _,mod in ipairs(mods or {})do
  ids[mod.id]=true
  if mod.github then repos[repository(mod.github)]=true end
  if M.supports(mod,version,true)then
   local enabled=mod.enabled==true and(not mod.gens or mod.gens[generation(version)]~=false)
   owned[#owned+1]={mod=mod,enabled=enabled}
  end
 end
 table.sort(owned,function(a,b)
  if a.enabled~=b.enabled then return a.enabled end
  return (a.mod.name or a.mod.id):lower()<(b.mod.name or b.mod.id):lower()
 end)
 local seenIds,seenRepos={},{}
 for position,entry in ipairs(index and index.mods or {})do
  local repo=repository(entry.github)
  local release=entry.latest
  local unresolvedRepo=entry.catalogueId and not entry._communityResolved and repo
  if not ids[entry.id]and not(unresolvedRepo and repos[repo])and not seenIds[entry.id]
   and not(unresolvedRepo and seenRepos[repo])and M.compatible(entry,version)
   and (entry.catalogueId and entry.resolveUrl or Index.canInstall(entry))
   and entry.update_check~='off'and entry.update_check~='no installable release'
   and not(entry.update_check or ''):match('^error:')
   and not entry.experimental and not(release and release.prerelease)then
   local weekly=week and entry.catalogueId==week.catalogue_id or false
   local verified=entry.api~=nil and entry.game_version~=nil and(not entry.catalogueId or entry._communityResolved==true)and Index.canInstall(entry)
   available[#available+1]={entry=entry,weekly=weekly,verified=verified==true,position=position}
   seenIds[entry.id]=true;if unresolvedRepo then seenRepos[repo]=true end
  end
 end
 -- Operator's live weekly choice first, then complete compatible manifests;
 -- otherwise preserve catalogue order.
 -- No invented ratings or popularity statistics.
 table.sort(available,function(a,b)
  if a.weekly~=b.weekly then return a.weekly end
  if a.verified~=b.verified then return a.verified end
  return a.position<b.position
 end)
 return owned,available
end
return M
