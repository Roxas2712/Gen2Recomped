-- Shared account presence, including while a game or its overlay is open.
-- Never stores a password, device token or the staff directory in this cache.
local P={}
local Auth=require('src.cloud.RetroCloud')
local Task=require('src.cloud.Task')
function P.accept(profile)
 local account=Auth.accountId()
 if type(profile)~='table' or profile.account_id~=account then return end
 P.account=account;P.profile=profile;profile._receivedAt=os.time()
end
function P.tick()
 local account=Auth.accountId()
 if account~=P.account then
  if P.job then P.job:cancel() end
  P.account=account;P.job=nil;P.profile=nil;P.next=0
 end
 if not account or not Auth.signedIn() then
  if P.job then P.job:cancel();P.job=nil end
  P.profile=nil
  return
 end
 if P.job then
  local result=P.job:poll()
  if result then
   P.job=nil
   if result.kind=='done' then P.accept(result.first) end
  end
 elseif os.time()>=(P.next or 0) then
  P.next=os.time()+45
  P.job=Task.new(require('src.cloud.NativeAccount').friends)
 end
end
function P.read()
 return Auth.signedIn() and P.account==Auth.accountId() and P.profile or nil
end
return P
