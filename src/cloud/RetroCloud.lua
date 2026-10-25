-- The shared ModCompass account stores only a revocable device token here.
local Http=require('src.cloud.Http')
local Json=require('src.link.Json')
local Serializer=require('src.core.SaveSerializer')
local R={FILE='cloud_retro.lua',API='https://pokexpert.de/api/cloud/v1'}
local function load()
  if not (love and love.filesystem and love.filesystem.read) then return nil end
  local bytes=love.filesystem.read(R.FILE)
  if not bytes then return nil end
  local ok,value=pcall(Serializer.decode,bytes)
  if ok and type(value)=='table' and type(value.access)=='string'
    and value.access:match('^[a-f0-9]+$') and #value.access==64 then return value end
end
local function request(method,path,body,token,headers)
  headers=headers or {}
  headers.Accept='application/json'
  if token then headers.Authorization='Bearer '..token end
  if type(body)=='table' then headers['Content-Type']='application/json';body=Json.encode(body) end
  local code,bytes=Http.request(method,R.API..path,{body=body,headers=headers,sensitive=true})
  if code==401 and token then R.expire(token) end
  return code,bytes
end
local function document(method,path,body,token,headers)
  return Http.json(request(method,path,body,token,headers))
end
local function save(value)
  local Safety=require('src.core.SaveSafety')
  return Safety.atomicWrite(love.filesystem,R.FILE,Serializer.encode(value),{decode=Safety.decodeAny})
end
-- Device credentials survive restarts and offline periods. Only the service
-- can revoke them; the old expiry field is retained for older builds.
function R.signedIn() return load()~=nil end
function R.account() local value=load();return value and value.email end
function R.accountId() local value=load();return value and value.accountId end
function R.nickname() local value=load();return value and (value.name or value.email) end
function R.acceptAccount(doc)
  local value=load()
  if not value or type(doc.account_id)~='string' or #doc.account_id>20 or not doc.account_id:match('^[1-9][0-9]*$') then return nil,'Account identity unavailable. Sign in again.' end
  if value.accountId and value.accountId~=doc.account_id then return nil,'Account identity changed. Sign in again.' end
  value.accountId=doc.account_id
  if type(doc.email)=='string' then value.email=doc.email end
  if type(doc.name)=='string' then value.name=doc.name end
  if type(doc.friend_tag)=='string' then value.friendTag=doc.friend_tag end
  return save(value)
end
function R.acceptConnection(doc)
  if type(doc)~='table' or type(doc.access_token)~='string' or #doc.access_token~=64
    or not doc.access_token:match('^[a-f0-9]+$') or type(doc.expires_in)~='number'
    or doc.expires_in<120 or doc.expires_in>90*86400 or type(doc.email)~='string' then return nil,'Invalid device connection.' end
  local accountId=type(doc.account_id)=='string' and #doc.account_id<=20 and doc.account_id:match('^[1-9][0-9]*$') and doc.account_id or nil
  local ok,why=save({access=doc.access_token,expires=os.time()+doc.expires_in-60,email=doc.email,accountId=accountId,name=type(doc.name)=='string' and doc.name or nil})
  if not ok then return nil,'Could not store the device connection: '..tostring(why) end
  return true
end
function R.accessToken()
  local value=load()
  if value then return value.access end
  return nil,'Connect this device to your ModCompass account in Cloud saves.'
end
function R.begin()
  local platform=love.system and love.system.getOS and love.system.getOS() or 'Handheld'
  local status,doc=document('POST','/device',{label='RetroRecomped · '..platform})
  if status~=200 or not (doc and doc.device_code and doc.user_code) then
    return nil,'Cloud connection unavailable ('..tostring(status or 'offline')..').'
  end
  return {kind='device',deviceCode=doc.device_code,code=doc.user_code,url=doc.verification_uri,
    interval=5,nextPoll=os.time()+5,expires=os.time()+600}
end
function R.poll(flow)
  if os.time()>flow.expires then return 'failed','Device code expired. Please connect again.' end
  if os.time()<flow.nextPoll then return 'waiting' end
  flow.nextPoll=os.time()+flow.interval
  local status,doc=document('POST','/token',{token=flow.deviceCode})
  if status==400 and doc and doc.error=='authorization_pending' then return 'waiting' end
  if status==429 then flow.interval=math.min(30,flow.interval+5);return 'waiting' end
  if status==200 and doc and type(doc.access_token)=='string' and #doc.access_token==64 then
    local ok,why=R.acceptConnection(doc)
    if not ok then return 'failed',why end
    return 'done'
  end
  return 'failed','Device connection failed ('..tostring(status or 'offline')..').'
end
function R.cancel() end
function R.expire(expected)
  local current=load()
  if not expected or current and current.access==expected then love.filesystem.remove(R.FILE) end
end
function R.signOut()
  local value=load()
  if value then
    local status=request('POST','/logout',{},value.access)
    if status~=200 and status~=401 then error('Cloud sign-out unavailable. Please try again when online.',0) end
  end
  if value then R.expire(value.access) end
end

function R.open()
  local token,why=R.accessToken()
  if not token then return nil,why end
  local accountId,email=R.accountId(),R.account()
  local status,doc=document('GET','/objects',nil,token)
  if status~=200 or not (doc and type(doc.objects)=='table') then
    return nil,'Cloud listing failed ('..tostring(status or 'offline')..').'
  end
  local revisions={}
  for _,object in ipairs(doc.objects) do
    if type(object.path)=='string' and type(object.revision)=='string' then revisions[object.path]=object.revision end
  end
  local store={kind='retro',label='RetroRecomped Cloud',accountId=accountId,profileScope='retro:'..tostring(email or ''):lower(),storage=doc.storage}
  function store.has(path) return revisions[path]~=nil end
  function store.list(directory)
    local prefix=directory..'/'
    local result={}
    for path in pairs(revisions) do
      if path:sub(1,#prefix)==prefix then
        local rest=path:sub(#prefix+1)
        if not rest:find('/',1,true) then result[#result+1]=rest end
      end
    end
    table.sort(result);return result
  end
  function store.read(path)
    local code,body=request('GET','/objects/'..path,nil,token)
    if code==404 then revisions[path]=nil;return nil end
    if code~=200 then error('Cloud read failed ('..tostring(code or 'offline')..'). Local saves are preserved.',0) end
    return body
  end
  function store.write(path,bytes)
    local headers={['Content-Type']='text/plain'}
    if revisions[path] then headers['If-Match']='"'..revisions[path]..'"'
    else headers['If-None-Match']='*' end
    local code,result=document('PUT','/objects/'..path,bytes,token,headers)
    if code==200 and result and result.revision then revisions[path]=result.revision;return true end
    return false,code==412 and 'Changed on another device. Sync again; both copies are preserved.'
      or 'Cloud write failed ('..tostring(code or 'offline')..').'
  end
  return store
end
return R
