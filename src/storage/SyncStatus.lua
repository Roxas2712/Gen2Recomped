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
function M.result(result,problem,version,slot)
  if not result then
    local both=tostring(problem):lower()
    return M.set((both:find('both copies',1,true) or both:find('both devices',1,true)) and 'conflict' or 'error',version,slot,problem)
  end
  if type(result)=='table' and result.cacheWarning then
    return M.set('error',version,slot,'Private game transfer paused: '..tostring(result.cacheWarning))
  end
  if type(result)=='table' and result.sync then return M.result(result.sync,problem,version,slot) end
  if result=='kept both' or type(result)=='table' and (result['kept both'] or 0)>0 then
    return M.set('conflict',version,slot,'Both versions were preserved. Choose the save you want to continue.')
  end
  if type(result)=='table' and (result.failed or 0)>0 then
    return M.set('error',version,slot,result.suspendNotice or 'Some saves could not be transferred. Local copies were kept.')
  end
  return M.set(result=='empty' and 'local' or 'available',version,slot)
end
function M.describe(entry)
  local state=entry and entry.state or 'local'
  local labels={local_='Saved on this device',uploading='Uploading to your cloud…',available='Available on your other devices',
    conflict='Sync conflict · Both copies kept',error='Upload paused · Local save kept',cancelled='Upload cancelled · Local save kept'}
  return labels[state=='local' and 'local_' or state] or labels.local_
end
return M
