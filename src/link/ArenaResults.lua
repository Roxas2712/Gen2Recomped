-- Account-scoped result outbox survives a failed request or a device restart.
local R={DIRECTORY='bank/arena-results'}
local job,active,nextTry
local function disk() return require('src.core.SaveData').persistenceFs() end
function R.keep(cup,match,payload)
 local Auth=require('src.cloud.RetroCloud');if not Auth.signedIn() then return nil,'Sign in before reporting a battle.' end
 local S=require('src.core.SaveSerializer');local fs=disk();fs.createDirectory(R.DIRECTORY)
 local doc={account=Auth.accountId(),cup=cup,match=match,payload=payload};local path=R.DIRECTORY..'/'..payload.battle..'.lua'
 return require('src.core.SaveSafety').atomicWrite(fs,path,S.encode(doc),{decode=S.decode})
end
function R.pump()
 local Auth=require('src.cloud.RetroCloud');if not Auth.signedIn() then if job then job:cancel();job=nil end;return end
 if job then
  if active.account~=Auth.accountId() then job:cancel();job=nil;return end
  local result=job:poll();if result then
   job=nil;nextTry=os.time()+15
   if result.kind=='done' and result.first and Auth.accountId()==active.account then disk().remove(active.path) end
  end
  return
 end
 if os.time()<(nextTry or 0) then return end
 local S=require('src.core.SaveSerializer')
 for _,name in ipairs(disk().getDirectoryItems(R.DIRECTORY) or {}) do
  if name:match('^[a-f0-9%-]+%.lua$') then
   local bytes=disk().read(R.DIRECTORY..'/'..name) or '';local ok,doc=false,nil;if #bytes<=65536 then ok,doc=pcall(S.decode,bytes) end
   if ok and type(doc)=='table' and doc.account==Auth.accountId() and type(doc.payload)=='table' then
    active={account=doc.account,path=R.DIRECTORY..'/'..name};local data=doc
    job=require('src.cloud.Task').new(function() return require('src.cloud.Tournaments').request('POST',data.cup,'battle-result',data.payload,data.match) end)
    if not job then nextTry=os.time()+15 end;return
   end
  end
 end
end
return R
