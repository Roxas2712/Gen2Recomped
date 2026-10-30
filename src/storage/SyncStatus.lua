-- Session-only transfer feedback. A previous launch's green badge must never
-- imply that newly changed local progress is already available elsewhere.
local M={entries={}}
local function scope()
  local auth=package.loaded['src.cloud.RetroCloud']
  return auth and auth.accountId and tostring(auth.accountId() or 'local') or 'local'
end
local function key(version,slot) return scope()..'/'..tostring(version or '*')..'/'..tostring(slot or '*') end
function M.set(state,version,slot,detail)
  local entry={state=state,edition=version,slot=slot,detail=detail,scope=scope()}
  M.entries[key(version,slot)]=entry;M.latest=entry;return entry
end
function M.get(version,slot)
  if version then return M.entries[key(version,slot)] end
  return M.latest and M.latest.scope==scope() and M.latest or nil
end
function M.changed(version,slot)
  local entry=M.get(version,slot)or M.get()
  if entry and (entry.state=='available' or entry.state=='partial')then
    return M.set('local',version,slot,'New progress is saved on this device. Upload it to update your cloud copy.')
  end
end
function M.result(result,problem,version,slot)
  if not result then
    local both=tostring(problem):lower()
    return M.set((both:find('both copies',1,true) or both:find('both devices',1,true)) and 'conflict' or 'error',version,slot,problem)
  end
  if type(result)=='table' and (result.sync or result.normal) then
    local entry=M.result(result.sync or result.normal,problem,version,slot)
    if entry.state=='error' or entry.state=='conflict' then return entry end
    local warnings={}
    if entry.state=='partial' and entry.detail then warnings[#warnings+1]=entry.detail end
    for _,value in ipairs(result.warnings or {})do warnings[#warnings+1]=value end
    if result.cacheWarning then warnings[#warnings+1]=require('src.translation.Service').launcherLookup('Imported games')..': '..require('src.translation.Service').launcherLookup(tostring(result.cacheWarning)) end
    if result.suspendNotice then warnings[#warnings+1]=require('src.translation.Service').launcherLookup('Exact resume')..': '..require('src.translation.Service').launcherLookup(tostring(result.suspendNotice)) end
    if #warnings>0 then return M.set('partial',version,slot,table.concat(warnings,' · ')) end
    return entry
  end
  if result=='kept both' or type(result)=='table' and (result['kept both'] or 0)>0 then
    return M.set('conflict',version,slot,'Both versions were preserved. Choose the save you want to continue.')
  end
  if type(result)=='table' and (result.failed or 0)>0 then
    return M.set('error',version,slot,result.problem or result.suspendNotice or 'Some saves could not be transferred. Local copies were kept.')
  end
  if type(result)=='table' and result.suspendNotice then
    return M.set('partial',version,slot,require('src.translation.Service').launcherLookup('Exact resume')..': '..require('src.translation.Service').launcherLookup(tostring(result.suspendNotice)))
  end
  return M.set(result=='empty' and 'local' or 'available',version,slot)
end
function M.describe(entry)
  local state=entry and entry.state or 'local'
  local labels={local_='Saved on this device',uploading='Uploading to your cloud…',available='Save synced to your cloud',
    conflict='Sync conflict · Both copies kept',error='Cloud sync failed · Local save kept',cancelled='Upload cancelled · Local save kept',
    partial='Save sync finished · Extra transfer incomplete'}
  return labels[state=='local' and 'local_' or state] or labels.local_
end
function M.notice(entry)
  local L=require('src.translation.Service').launcherLookup
  return L(M.describe(entry))..(entry and entry.detail and (' · '..L(tostring(entry.detail)))or '')
end
return M
