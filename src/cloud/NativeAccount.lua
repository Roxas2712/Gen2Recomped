-- Native account requests share the same identity and revocable cloud token.
local A={}
local Auth=require('src.cloud.RetroCloud')
local Http=require('src.cloud.Http')
local Json=require('src.link.Json')
local function call(method,path,payload,authorized)
  local headers={Accept='application/json',['Content-Type']='application/json'}
  local credential
  if authorized then
    local token,why=Auth.accessToken();if not token then return nil,why end
    credential=token
    headers.Authorization='Bearer '..token
  end
  local code,bytes=Http.request(method,Auth.API..path,{headers=headers,body=payload and Json.encode(payload),sensitive=true})
  if type(bytes)~='string' or #bytes>512*1024 then return nil,'Account service unavailable. Please try again.' end
  local ok,doc=pcall(Json.decode,bytes)
  if not ok or type(doc)~='table' then return nil,'Account service unavailable. Please try again.' end
  if code~=200 and code~=202 then
    if authorized and code==401 then Auth.expire(credential) end
    if not code or code>=500 then return nil,'Account service unavailable. Please try again.' end
    if type(doc.errors)=='table' then
      for _,key in ipairs({'email','name','password','repositories','repository','terms_version','terms_accepted','privacy_acknowledged','developer_rights_accepted','image_base64','avatar','avatar_rights','artwork_rights_accepted','credit','alt','code','player','editions','dex','level','moves','starts_at','ends_at','title','edition','capacity','team_size','level','rules','verification','winner','reason','prize.dex','prize.level','prize.egg','prize.shiny'}) do
        local e=doc.errors[key];if type(e)=='table' and type(e[1])=='string' then return nil,e[1]:sub(1,300) end
      end
    end
    return nil,type(doc.message)=='string' and doc.message:sub(1,300) or ('Account request failed ('..tostring(code or 'offline')..').')
  end
  if doc.state=='connected' then
    local saved,why=Auth.acceptConnection(doc);if not saved then return nil,why end
    doc.access_token=nil
  elseif doc.challenge and (type(doc.challenge)~='string' or #doc.challenge~=64 or not doc.challenge:match('^[a-f0-9]+$')) then
    return nil,'Invalid account challenge.'
  end
  return doc
end
function A.policy() return call('GET','/auth/policy') end
function A.login(email,password) return call('POST','/auth/login',{email=email,password=password,label=A.label()}) end
function A.register(payload) payload.label=A.label();return call('POST','/auth/register',payload) end
function A.complete(challenge,code) return call('POST','/auth/challenge',{challenge=challenge,code=code}) end
function A.resend(challenge) return call('POST','/auth/resend',{challenge=challenge}) end
function A.forgot(email) return call('POST','/auth/password/email',{email=email}) end
function A.reset(challenge,code,password,confirmation) return call('POST','/auth/password/reset',{challenge=challenge,code=code,password=password,password_confirmation=confirmation}) end
function A.devices()
  local doc,why=call('GET','/account/devices',nil,true)
  if doc then local ok,err=Auth.acceptAccount(doc);if not ok then return nil,err end end
  return doc,why
end
function A.profile(payload)
  local doc,why=call(payload and 'PUT' or 'GET','/account/profile',payload,true)
  if doc then local ok,err=Auth.acceptAccount(doc);if not ok then return nil,err end end
  return doc,why
end
function A.grantRole(payload) return call('POST','/community/roles',payload,true) end
function A.gifts() return call('GET','/gifts',nil,true) end
function A.createGift(payload) return call('POST','/gifts',payload,true) end
function A.activateGift(id,active)
  if type(id)~='string' or #id~=36 or not id:match('^[a-f0-9%-]+$') then return nil,'Invalid gift.' end
  return call('PATCH','/gifts/'..id,{active=active},true)
end
function A.friends() return call('GET','/community/friends',nil,true) end
function A.findPlayer(tag) return call('POST','/community/find-player',{friend_tag=tag},true) end
function A.addFriend(player) return call('POST','/community/friends',{player=player},true) end
function A.friendAction(id,accept)
  if type(id)~='string' or #id>20 or not id:match('^[1-9][0-9]*$') then return nil,'Invalid player.' end
  return call(accept and 'POST' or 'DELETE','/community/friends/'..id..(accept and '/accept' or ''),nil,true)
end
function A.online(page) return call('GET','/community/online?page='..math.max(1,math.floor(tonumber(page) or 1)),nil,true) end
function A.revoke(id)
  if type(id)~='string' or #id~=64 or not id:match('^[a-f0-9]+$') then return nil,'Invalid device.' end
  return call('DELETE','/account/devices/'..id,nil,true)
end
function A.label() return 'RetroRecomped · '..tostring(love.system.getOS()) end
A.request=call
return A
