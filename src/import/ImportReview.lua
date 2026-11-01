-- Confirm replacement before touching imported data; cancelling keeps Play usable.
-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
local M={}
local function account()
 local auth=require('src.cloud.RetroCloud');return auth.accountId and auth.accountId()
end
local function now()return love.timer.getTime()end
function M.request(self,version,resume,existing)
 if not existing then return false end
 if self._modConfirm then return true end
 local L=require('src.translation.Service').launcherLookup
 local info=require('src.core.GameVersion').info(version)
 self._modConfirm={kind='reimport',title=L('Re-import this game?'),yesLabel=L('Re-import game'),
  lines={info and info.displayName or tostring(version),
   L('Only the imported game data will be rebuilt. Your saves, installed mods and account stay on this device.'),
   L('Your current game remains available until you confirm. Cancel to keep everything as it is.')},
  version=version,resume=resume,account=account(),opened=now()}
 self._modConfirmYes=nil;self._modConfirmNo=nil
 return true
end
function M.accept(self,confirm)
 if not confirm or confirm.kind~='reimport' or now()-confirm.opened<0.4 then return false end
 self._modConfirm=nil
 if confirm.account~=account() or self.workState=='working' or self._storageTask or self._profileApplying then
  self.settingsNotice=require('src.translation.Service').launcherLookup('The account or active transfer changed. Choose the import again.')
  return false
 end
 confirm.resume();return true
end
function M.cancel(self)
 self._modConfirm=nil
 if self._romQueue or self._pickMany then self._romQueueResume=true end
end
return M
