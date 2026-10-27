-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
local B={}
function B.request(entry,refresh)
 local Auth=require('src.cloud.RetroCloud');local account=Auth.accountId()
 if not Auth.signedIn()then return nil,'Sign in before checking a Bank Pokémon.'end
 local id=entry and entry.id
 if type(id)~='string'or #id~=64 or not id:match('^%x+$')then return nil,'Deposit this Pokémon in the Bank before requesting verification.'end
 if not refresh then
  local path='bank/entries/'..id..'.lua';local bytes=require('src.core.SaveData').persistenceFs().read(path)
  if not bytes then return nil,'The local Bank entry is missing.'end
  local store,why=Auth.open();if not store then return nil,why end
  if not store.has(path)then local ok,err=store.write(path,bytes);if not ok then return nil,err end
  elseif store.read(path)~=bytes then return nil,'The cloud Bank copy differs. Sync or restore the original entry first.'end
 end
 local doc,why=require('src.cloud.NativeAccount').request(refresh and'GET'or'POST','/bank/entries/'..id..'/verification',nil,true)
 if not Auth.signedIn()or Auth.accountId()~=account or doc and(tostring(doc.account_id)~=account or doc.bank_digest~=id)then return nil,'The active account or Bank entry changed.'end
 return doc,why
end
return B
