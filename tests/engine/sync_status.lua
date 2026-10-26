package.path='./?.lua;'..package.path
local account='1';package.loaded['src.cloud.RetroCloud']={accountId=function()return account end}
local M=require('src.storage.SyncStatus')
local n=0;local function check(v,m)assert(v,m);n=n+1 end
check(M.describe():find('this device',1,true),'an unknown session never claims a finished upload')
M.set('local','emerald','a');M.set('uploading','emerald','a')
check(M.get('emerald','a').state=='uploading','upload feedback is tied to the selected game and slot')
M.result(nil,'Network unavailable','emerald','a');check(M.get().state=='error','a failed request never displays cloud availability')
M.result('uploaded',nil,'emerald','a');check(M.get().state=='available','only an acknowledged successful transfer becomes available')
M.result({uploaded=1,failed=1,suspendNotice='Broken suspend block'})
check(M.get().state=='error' and M.get().detail=='Broken suspend block','partial batch failure cannot be hidden behind the normal save success')
M.result('kept both');check(M.get().state=='conflict','normal save conflicts are visible even when both writes succeeded')
M.result(nil,'Both devices have different suspends. Both copies were preserved; choose which one to continue.')
check(M.get().state=='conflict','divergent exact states remain a reviewable conflict')
account='2';check(not M.get() and not M.get('emerald','a'),'another account cannot inherit a green badge or another player’s error details')
account='1';M.set('cancelled');check(M.describe(M.get()):find('Local save kept',1,true),'cancellation explains that progress is still local')
print('Sync status: '..n..' checks passed')
