-- One account connection replaces provider keys/folder setup for normal saves.
-- Existing unassigned progress is adopted only through an explicit choice.
-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
local M={VERSION=1}
function M.defaultEnabled(options)
 return not(options.cloudSetupVersion==M.VERSION and options.cloudAutoSync==false)
end
function M.prepare(self,form,choice)
 local P=require('src.storage.AccountStorage')
 if P.enabled then
  local owner,why=P.owner();if why then return nil,why end
  if not owner then
   local sources=P.localSources()
   if #sources>0 and not choice then return 'review',sources end
   if choice and choice~='separate'then
    local found=false;for _,source in ipairs(sources)do if source==choice then found=true end end
    if not found then return nil,'This local profile changed. Review the connection again.' end
   end
   local ok,err=P.bind(choice);if not ok then return nil,err end
   P.profileChanged(self)
  elseif not P.check() then return nil,'These saves belong to another account. Existing records were preserved.' end
 end
 local options=self:_settings()
 if form.cloudSync~=false then
  options.cloudService='retro';options.cloudAutoSync=true
  options.launcherSaveStorageChoice='cloud'
 else
  options.cloudAutoSync=false;options.launcherSaveStorageChoice='local'
 end
 options.cloudSetupVersion=M.VERSION
 local ok,why=require('src.core.SaveData').saveOptions(options)
 if not ok then return nil,why or 'Cloud preferences could not be saved. Please retry.' end
 self._settingsCache=nil;self._settingsRowCache=nil
 self._cloudRestoreOnce=form.cloudSync~=false and form.restore~=false
 self._storageNext=0
 return true
end
return M
