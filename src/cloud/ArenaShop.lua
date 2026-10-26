local M={ORDER='bank/shop-order.lua'}
local Auth=require('src.cloud.RetroCloud')
local A=require('src.cloud.NativeAccount')
local S=require('src.core.SaveSerializer')
local function disk()return require('src.core.SaveData').persistenceFs()end
function M.request(method,payload,page)
 if not Auth.signedIn() then return nil,'Sign in to use the Arena shop.' end
 local account=Auth.accountId()
 local doc,why,code=A.request(method,'/arena/shop'..(method=='POST' and '/orders' or '?page='..tostring(page or 1)),payload,true)
 if doc and (Auth.accountId()~=account or doc.account_id~=account) then return nil,'The active shop account changed.' end
 return doc,why,code
end
function M.pending()
 local bytes=disk().read(M.ORDER);if not bytes then return end
 local ok,value=pcall(S.decode,bytes)
 if ok and type(value)=='table' and value.account==Auth.accountId() and type(value.payload)=='table' then return value.payload end
 return nil,'The pending shop order needs recovery.'
end
function M.purchase(item,edition)
 local allowed,why=require('src.storage.AccountStorage').check();if not allowed then return nil,why end
 local payload,err=M.pending();if err then return nil,err end
 if payload and (payload.item~=item or payload.edition~=edition) then return nil,'Retry the pending purchase before choosing another item.' end
 if not payload then
  local h=love.data.encode('string','hex',love.data.hash('sha256',tostring(love.timer.getTime())..'|'..tostring(os.time())..'|'..tostring(love.math.random())..'|'..Auth.accountId()))
  payload={order=h:sub(1,8)..'-'..h:sub(9,12)..'-4'..h:sub(14,16)..'-a'..h:sub(18,20)..'-'..h:sub(21,32),item=item,edition=edition}
  disk().createDirectory('bank');local ok,problem=require('src.core.SaveSafety').atomicWrite(disk(),M.ORDER,S.encode({account=Auth.accountId(),payload=payload}),{decode=S.decode})
  if not ok then return nil,problem end
 end
 local doc,problem,code=M.request('POST',payload)
 if doc or code==422 then disk().remove(M.ORDER) end
 return doc,problem
end
function M.collect()
 local allowed,why=require('src.storage.AccountStorage').check();if not allowed then return nil,why end
 local Items=require('src.storage.BankItems');local store,err=Auth.open();if not store then return nil,err end
 local ok,problem=Items.sync(store);if not ok then return nil,problem end
 local page,count=1,0;local first
 repeat
  local doc,issue=M.request('GET',nil,page);if not doc then return nil,issue end
  first=first or doc
  for _,receipt in ipairs(doc.items or {}) do local kept,reason=Items.acceptArena(receipt);if not kept then return nil,reason end;count=count+1 end
  page=page+1
 until page>math.min(41,tonumber(first.pages) or 1)
 local synced,issue=Items.sync(store);if not synced then return nil,issue end
 first.collected=count;return first
end
return M
