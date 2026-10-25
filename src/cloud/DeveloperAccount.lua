-- Same device token and user as saves. No GitHub credential is requested.
local D={FILE='mod_developer.lua'}
local Auth=require('src.cloud.RetroCloud')
local Http=require('src.cloud.Http')
local Json=require('src.link.Json')
local S=require('src.core.SaveSerializer')
local function repository(value)
  return type(value)=='string' and value:match('^[%w%-]+/[%w_.%-]+$') and not value:find('..',1,true)
end
function D.read()
  local bytes=love.filesystem.read(D.FILE);local ok,value=pcall(S.decode,bytes or '')
  if ok and type(value)=='table' and value.scope==Auth.account() then return value.profile end
end
local function keep(profile)
  local value={scope=Auth.account(),profile=profile}
  return require('src.core.SaveSafety').atomicWrite(love.filesystem,D.FILE,S.encode(value),{decode=require('src.core.SaveSafety').decodeAny})
end
local function call(method,path,payload)
  local token,why=Auth.accessToken();if not token then return nil,why end
  local code,bytes=Http.request(method,Auth.API..'/developer'..(path or ''),{headers={Accept='application/json',Authorization='Bearer '..token,['Content-Type']='application/json'},body=payload and Json.encode(payload)})
  if type(bytes)~='string' or #bytes>256*1024 then return nil,'Invalid developer profile size.' end
  local ok,doc=pcall(Json.decode,bytes or '')
  if code~=200 or not ok or type(doc)~='table' then
    if code==401 and Auth.expire then Auth.expire(token) end
    local message=ok and type(doc)=='table' and (doc.errors and doc.errors.repository and doc.errors.repository[1] or doc.message)
    return nil,message or ('Account request failed ('..tostring(code or 'offline')..').')
  end
  if type(doc.account)~='table' or type(doc.account.id)~='number' or type(doc.verified)~='boolean'
    or doc.repository~=nil and not repository(doc.repository) then return nil,'Invalid developer profile response.' end
  local prior=D.read()
  if not doc.proof and prior and prior.account and prior.account.id==doc.account.id and not doc.verified and prior.repository==doc.repository then doc.proof=prior.proof end
  doc.proof_url=nil -- Build links locally from the verified repository grammar.
  local saved,err=keep(doc);if not saved then return nil,'Could not preserve this account profile: '..tostring(err) end
  return doc
end
function D.profile() return call('GET') end
function D.save(value) return call('PUT','',{repository=value}) end
function D.verify() return call('POST','/verify',{}) end
function D.proofUrl(profile)
  if not profile or not repository(profile.repository) or type(profile.proof)~='string' then return nil end
  local ok,p=pcall(Json.decode,profile.proof)
  if not ok or type(p)~='table' or p.service~='modcompass' or p.account~=profile.account.id or type(p.nonce)~='string' then return nil end
  return 'https://github.com/'..profile.repository..'/new/HEAD?'..Http.form({filename='.modcompass-developer.json',value=profile.proof})
end
return D
