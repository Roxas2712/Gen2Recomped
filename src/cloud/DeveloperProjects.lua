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
  doc.proof_url=nil
  local prior=proofs()
  if doc.verified then prior[doc.repository]=nil
  elseif doc.proof then prior[doc.repository]=doc.proof
  else doc.proof=prior[doc.repository] end
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
    r.proof_url=nil;if not r.verified then r.proof=prior[r.repository] end
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
  return 'https://github.com/'..profile.repository..'/new/HEAD?'..Http.form({filename='.modcompass-developer.json',value=profile.proof})
end
return D
