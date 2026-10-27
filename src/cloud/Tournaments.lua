-- Account-scoped tournament organization. The server owns brackets and awards;
-- community results require agreement and are not battle legality attestations.
local T={}
local A=require('src.cloud.NativeAccount')
local Auth=require('src.cloud.RetroCloud')
local function uuid(id) return type(id)=='string' and #id==36 and id:match('^[a-f0-9%-]+$') end
local actions={access=true,entry=true,start=true,cancel=true,result=true,resolve=true,room=true,battle=true,['battle-result']=true,['battle-wire']=true,['battle-handoff']=true,['battle-handoff-active']=true}
function T.request(method,id,action,payload,match)
 if not Auth.signedIn() then return nil,'Sign in to enter the Arena.' end
 if id and not uuid(id) or match and not uuid(match) or action and not actions[action] then return nil,'Invalid tournament request.' end
 local path='/tournaments'..(id and '/'..id or '')..(match and '/matches/'..match or '')..(action and '/'..action or '')
 local account=Auth.accountId()
 local doc,why,status=A.request(method,path,payload,true)
 if not Auth.signedIn() or Auth.accountId()~=account then return nil,'The active account changed. Refresh the Arena.' end
 if doc and tostring(doc.account_id)~=account then return nil,'The Arena returned another account profile.' end
 return doc,why,status
end
function T.arena(method,payload)
 if not Auth.signedIn() then return nil,'Sign in to find an online rival.' end
 if method~='GET' and method~='POST' and method~='DELETE' then return nil,'Invalid Arena request.' end
 local account=Auth.accountId()
 local doc,why=A.request(method,'/arena'..(method=='GET' and '' or '/queue'),payload,true)
 if not Auth.signedIn() or Auth.accountId()~=account or doc and tostring(doc.account_id)~=account then return nil,'The active account changed. Refresh the Arena.' end
 return doc,why
end
function T.prize(receipt)
 if not uuid(receipt) then return nil,'Invalid tournament prize.' end
 local account=Auth.accountId()
 local doc,why=A.request('GET','/gifts/receipts/'..receipt,nil,true)
 if not Auth.signedIn() or Auth.accountId()~=account then return nil,'The active account changed.' end
 if not doc then return nil,why end
 return require('src.cloud.GiftCodes').keep(doc)
end
return T
