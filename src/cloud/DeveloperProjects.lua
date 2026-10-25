local D={}
local A=require('src.cloud.NativeAccount')
local Http=require('src.cloud.Http')
local Json=require('src.link.Json')
local Auth=require('src.cloud.RetroCloud')
local S=require('src.core.SaveSerializer')
local FILE='mod_developer_projects.lua'
local function valid(value) return type(value)=='string' and value:match('^[%w%-]+/[%w_.%-]+$') and not value:find('..',1,true) end
local function proofs()
  local ok,doc=pcall(S.decode,love.filesystem.read(FILE) or '')
  return ok and type(doc)=='table' and doc.scope==Auth.account() and type(doc.proofs)=='table' and doc.proofs or {}
end
local function keep(doc)
  if type(doc.id)~='number' or not valid(doc.repository) or type(doc.verified)~='boolean' then return nil,'Invalid project response.' end
  local prefix='https://github.com/'..doc.repository..'/new/'
  if type(doc.proof_url)~='string' or doc.proof_url:sub(1,#prefix)~=prefix or doc.proof_url:find('[\r\n]') then doc.proof_url=nil end
  local prior=proofs()
  if doc.verified then prior[doc.repository]=nil
  elseif doc.proof then prior[doc.repository]={proof=doc.proof,proof_url=doc.proof_url}
  else
    local cached=prior[doc.repository]
    doc.proof=type(cached)=='table' and cached.proof or cached
    doc.proof_url=type(cached)=='table' and cached.proof_url or nil
  end
  local saved,why=require('src.core.SaveSafety').atomicWrite(love.filesystem,FILE,S.encode({scope=Auth.account(),proofs=prior}),{decode=require('src.core.SaveSafety').decodeAny})
  if not saved then return nil,'Could not store project proof: '..tostring(why) end
  return doc
end
function D.list(page)
  local doc,why=A.request('GET','/developer/repositories?page='..tostring(math.max(1,math.floor(tonumber(page) or 1))),nil,true)
  if not doc then return nil,why end
  if type(doc.repositories)~='table' then return nil,'Invalid repository list.' end
  local prior=proofs()
  for _,r in ipairs(doc.repositories) do
    if type(r.id)~='number' or not valid(r.repository) or type(r.verified)~='boolean' then return nil,'Invalid project response.' end
    r.proof_url=nil
    if not r.verified then
      local cached=prior[r.repository]
      r.proof=type(cached)=='table' and cached.proof or cached
      r.proof_url=type(cached)=='table' and cached.proof_url or nil
    end
  end
  return doc
end
function D.prepare(repository,version)
  local doc,why=A.request('POST','/developer/repositories',{repository=repository,terms_version=version,developer_rights_accepted=true},true)
  if not doc then return nil,why end;return keep(doc)
end
function D.verify(id)
  if type(id)~='number' or id<1 or id%1~=0 then return nil,'Choose a project first.' end
  local doc,why=A.request('POST','/developer/repositories/'..id..'/verify',{},true)
  if not doc then return nil,why end;return keep(doc)
end
function D.proofUrl(profile)
  if not profile or not valid(profile.repository) or type(profile.proof)~='string' then return nil end
  local ok,p=pcall(Json.decode,profile.proof)
  if not ok or type(p)~='table' or p.service~='modcompass' or p.repository~=profile.repository or type(p.account)~='number' or type(p.nonce)~='string' then return nil end
  local prefix='https://github.com/'..profile.repository..'/new/'
  if type(profile.proof_url)=='string' and profile.proof_url:sub(1,#prefix)==prefix and not profile.proof_url:find('[\r\n]') then return profile.proof_url end
  return 'https://github.com/'..profile.repository..'/new/HEAD?'..Http.form({filename='.modcompass-developer.json',value=profile.proof})
end
function D.uploadCover(profile,bytes,credit,alt,confirmed)
  if not profile or not profile.verified or type(profile.id)~='number' or profile.id<1 or profile.id%1~=0 then return nil,'Verify this repository first.' end
  if confirmed~=true then return nil,'Confirm your rights to publish this cover first.' end
  if type(bytes)~='string' or #bytes>2*1024*1024 or not require('src.import.ImageBounds').allowed(bytes,2048) then return nil,'Use a PNG, JPEG or WebP up to 2048 pixels and 2 MB.' end
  local doc,why=A.request('POST','/developer/repositories/'..profile.id..'/cover',{image_base64=love.data.encode('string','base64',bytes),credit=credit,alt=alt,artwork_rights_accepted=true},true)
  if not doc then return nil,why end
  if type(doc.digest)~='string' or #doc.digest~=64 or not doc.digest:match('^[a-f0-9]+$') or type(doc.status)~='string' then return nil,'Invalid cover response.' end
  return doc
end
return D
