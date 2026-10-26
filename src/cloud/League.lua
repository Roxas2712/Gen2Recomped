local L={}
local Auth=require('src.cloud.RetroCloud')
local A=require('src.cloud.NativeAccount')
function L.request(method,path,payload)
 if not Auth.signedIn() then return nil,'Sign in to join the league.' end
 local account=Auth.accountId();local doc,why=A.request(method,'/arena/'..path,payload,true)
 if not Auth.signedIn() or Auth.accountId()~=account or doc and tostring(doc.account_id)~=account then return nil,'The active account changed.' end
 return doc,why
end
function L.claim(id)
 if type(id)~='string' or not id:match('^[a-f0-9%-]+$') or #id~=36 then return nil,'Invalid league reward.' end
 local doc,why=L.request('POST','league/rewards/'..id..'/claim',{})
 if not doc then return nil,why end
 local kept={}
 for _,receipt in ipairs(doc.receipts or {}) do local key,problem=require('src.storage.LeagueEgg').keep(receipt);if not key then return nil,problem end;kept[#kept+1]=key end
 return {account_id=Auth.accountId(),kept=kept}
end
return L
