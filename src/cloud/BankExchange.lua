-- Authenticated exchanges of Bank copies. Device identity stays local;
-- durable request nonces make a retry return the same server-side exchange.
local T={DEVICE='recompiler_device.lua',JOURNAL='bank/exchange_requests.lua'}
local S=require('src.core.SaveSerializer')
local Safety=require('src.core.SaveSafety')
local Auth=require('src.cloud.RetroCloud')
local B=require('src.storage.PokemonBank')
local Json=require('src.link.Json')
local function disk() return require('src.core.SaveData').persistenceFs() end
local function hash(bytes) return love.data.encode('string','hex',love.data.hash('sha256',bytes)) end
local function read(path)
  local bytes=disk().read(path);if not bytes then return end
  local ok,value=pcall(S.decode,bytes);if ok and type(value)=='table' then return value end
end
local function write(path,value)
  disk().createDirectory('bank');disk().createDirectory('bank/trades')
  return Safety.atomicWrite(disk(),path,S.encode(value),{decode=Safety.decodeAny})
end
function T.device()
  local value=read(T.DEVICE)
  if value and type(value.id)=='string' and #value.id==32 and value.id:match('^[a-f0-9]+$') then return value.id end
  if disk().read(T.DEVICE) then return nil,'Device identity needs recovery. The existing ID was preserved.' end
  local id=require('src.core.PlaythroughIdentity').newId()
  local ok,why=write(T.DEVICE,{schema=1,id=id});return ok and id or nil,why
end
function T.request(method,path,body)
  local permitted,problem=require('src.storage.AccountStorage').check();if not permitted then return nil,problem end
  local token,why=Auth.accessToken();if not token then return nil,why end
  if type(path)~='string' or not path:match('^/bank/[%w/%-]+$') then return nil,'Invalid Bank endpoint.' end
  local device,err=T.device();if not device then return nil,err end
  local platform=love.system and love.system.getOS and love.system.getOS() or 'Device'
  local headers={Accept='application/json',Authorization='Bearer '..token,['X-Retro-Device']=device,
    ['X-Retro-Device-Label']='RetroRecomped · '..tostring(platform)}
  local bytes
  if body then headers['Content-Type']='application/json';bytes=Json.encode(body) end
  local status,result=require('src.cloud.Http').request(method,Auth.API..path,{headers=headers,body=bytes,sensitive=true})
  if status==401 and Auth.expire then Auth.expire() end
  if type(result)~='string' or #result>2*1024*1024 then return nil,'Bank response unavailable.' end
  local ok,value=pcall(Json.decode,result)
  if status~=200 or not ok or type(value)~='table' then return nil,ok and type(value)=='table' and value.message or ('Bank request failed ('..tostring(status or 'offline')..').') end
  return value
end
function T.profile() return T.request('GET','/bank/profile') end
function T.submit(entry,mode,recipient,exchange)
  if not Auth.signedIn() then return nil,'Register and verify your account before trading.' end
  if mode~='direct' and mode~='wonder' and mode~='reply' then return nil,'Unknown exchange mode.' end
  if mode=='direct' and (type(recipient)~='string' or not recipient:match('^RRC%-%x%x%x%x%x%x%-%x%x%x%x%x%x$')) then return nil,'Enter the recipient’s complete Recompiler ID.' end
  local value=S.decode(S.encode(entry));value.id=nil
  local bytes=S.encode(value);local digest=hash(bytes)
  if not B.decode(bytes,digest) then return nil,'This Bank copy could not be verified.' end
  local journal=read(T.JOURNAL)
  if not journal and disk().read(T.JOURNAL) then return nil,'Exchange journal needs recovery. Its request identifiers were preserved.' end
  journal=journal or {schema=1,requests={}}
  if journal.schema~=1 or type(journal.requests)~='table' then return nil,'Exchange journal needs recovery.' end
  local scope=hash(tostring(Auth.account())..'|'..mode..'|'..tostring(recipient)..'|'..tostring(exchange)..'|'..digest)
  local pending=journal.requests[scope]
  if not pending or pending.status=='completed' or pending.status=='cancelled' then
    pending={nonce=require('src.core.PlaythroughIdentity').newId(),status='pending'};journal.requests[scope]=pending
  end
  local saved,why=write(T.JOURNAL,journal);if not saved then return nil,why end
  local body={nonce=pending.nonce,entry=bytes,digest=digest,consent=true,
    summary={species=tostring(value.mon.species),nickname=value.mon.nickname,level=value.mon.level,game=value.source.version,
      is_egg=value.mon.isEgg==true or value.mon.egg==true or (tonumber(value.mon.eggSteps) or 0)>0}}
  local path='/bank/offers'
  if mode=='reply' then
    if type(exchange)~='string' or #exchange~=36 or not exchange:match('^[a-f0-9%-]+$') then return nil,'Invalid exchange identifier.' end
    path='/bank/exchanges/'..exchange..'/respond'
  else body.mode=mode;body.recipient=recipient end
  local result,err=T.request('POST',path,body);if not result then return nil,err end
  pending.exchange=result.id;pending.status=result.status
  local ok,problem=write(T.JOURNAL,journal)
  if not ok then return nil,'The exchange may be recorded online. Refresh its status before retrying: '..tostring(problem) end
  return result
end
function T.change(exchange,action)
  if type(exchange)~='string' or #exchange~=36 or not exchange:match('^[a-f0-9%-]+$') then return nil,'Invalid exchange identifier.' end
  local result,why
  if action=='confirm' then result,why=T.request('POST','/bank/exchanges/'..exchange..'/confirm',{consent=true})
  elseif action=='cancel' then result,why=T.request('DELETE','/bank/exchanges/'..exchange)
  else return nil,'Unknown exchange action.' end
  if result then
    local journal=read(T.JOURNAL)
    if journal and type(journal.requests)=='table' then
      for _,row in pairs(journal.requests) do if row.exchange==exchange then row.status=result.status end end
      write(T.JOURNAL,journal)
    end
  end
  return result,why
end
function T.receive(exchange)
  if type(exchange)~='string' or #exchange~=36 or not exchange:match('^[a-f0-9%-]+$') then return nil,'Invalid exchange identifier.' end
  local result,why=T.request('GET','/bank/exchanges/'..exchange);if not result then return nil,why end
  if result.status~='completed' then return nil,'Both players must confirm the exchange first.' end
  if type(result.incoming_digest)~='string' or #result.incoming_digest~=64 or not result.incoming_digest:match('^[a-f0-9]+$') then return nil,'Invalid incoming Bank fingerprint.' end
  local value,err=B.decode(result.incoming_entry,result.incoming_digest);if not value then return nil,err end
  local file='bank/trades/'..exchange..'.lua'
  local prior=read(file)
  if not prior and disk().read(file) then return nil,'Exchange receipt needs recovery. Existing copies were preserved.' end
  if prior and prior.entry~=result.incoming_digest then return nil,'Exchange receipt conflict. Existing copies are preserved.' end
  local id,problem=B.keep(value);if not id then return nil,problem end
  local ok,reason=write(file,{schema=1,exchange=exchange,entry=id,partner=result.partner,mode=result.mode,
    senderDevice=result.sender_device,recipientDevice=result.recipient_device,received=os.time()})
  if not ok then return nil,reason end
  return {entry=value,id=id,partner=result.partner,mode=result.mode,alreadyReceived=prior~=nil}
end
return T
