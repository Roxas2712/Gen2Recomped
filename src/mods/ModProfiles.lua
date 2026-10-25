-- A portable mod profile contains package identity and enable flags only.
-- Credentials, machine paths, artwork and arbitrary mod settings stay local.
local P={PATH='profiles/mods.lua',STATE='mod_profile_sync.lua'}
local S=require('src.core.SaveSerializer')
local Saves=require('src.core.SaveData')
local Safety=require('src.core.SaveSafety')
local Version=require('src.core.Version')
local Gens=require('src.mods.ModGens')
local Semver=require('src.mods.Semver')
local function versioned(value)
  return type(value)=='string' and #value<=80 and value:match('^%d+%.%d+%.%d+[%w%.+%-]*$') and Semver.parse(value)
end
local function clone(t) return S.decode(S.encode(t)) end
local function fingerprint(t) return love.data.encode('string','hex',love.data.hash('sha256',S.encode(t))) end
local function state(scope)
  local bytes=Saves.persistenceFs().read(P.STATE)
  local ok,value=pcall(S.decode,bytes or '')
  return ok and type(value)=='table' and value.scope==scope and value or {}
end
local function persist(value) return Safety.atomicWrite(Saves.persistenceFs(),P.STATE,S.encode(value),{decode=Safety.decodeAny}) end
local function localFingerprint(mods,options)
  local installed={}
  for _,m in ipairs(mods or {}) do installed[#installed+1]={id=m.id,version=m.version,enabled=m.enabled} end
  table.sort(installed,function(a,b) return tostring(a.id)<tostring(b.id) end)
  return fingerprint({profile=P.capture(mods,options),installed=installed,flags=options.mods or {}})
end
function P.capture(mods,options)
  local out={schema=1,engine=Version.engine,mods={}}
  for _,mod in ipairs(mods or {}) do
    local receipt=options.modInstallSources and options.modInstallSources[mod.id]
    local repo=receipt and receipt.version==mod.version and receipt.repo or mod.github
    if type(mod.id)=='string' and #mod.id<=128 and mod.id:match('^[%w_%-][%w_.%-]*$')
      and type(repo)=='string' and #repo<=180 and repo:match('^[%w%-]+/[%w_.%-]+$') and not repo:find('..',1,true) and versioned(mod.version) then
      local on,gens=Gens.decode(options.mods and options.mods[mod.id])
      if on==nil then on=mod.enabled~=false end
      out.mods[#out.mods+1]={id=mod.id,repo=repo,version=mod.version,on=on,gens=gens,
        sha256=receipt and receipt.version==mod.version and receipt.sha256 or nil,
        tag=receipt and receipt.version==mod.version and receipt.tag or nil}
    end
  end
  table.sort(out.mods,function(a,b) return a.id<b.id end)
  return out
end
function P.decode(bytes)
  if type(bytes)~='string' or #bytes>256*1024 then return nil,'Invalid mod profile size.' end
  local ok,p=pcall(S.decode,bytes)
  if not ok or type(p)~='table' or p.schema~=1 or type(p.engine)~='string' or type(p.mods)~='table' or #p.mods>256 then return nil,'Invalid mod profile.' end
  local ids={}
  for _,m in ipairs(p.mods) do
    if type(m)~='table' or type(m.id)~='string' or #m.id>128 or not m.id:match('^[%w_%-][%w_.%-]*$') or ids[m.id]
      or type(m.repo)~='string' or #m.repo>180 or not m.repo:match('^[%w%-]+/[%w_.%-]+$') or m.repo:find('..',1,true)
      or not versioned(m.version) or type(m.on)~='boolean' or type(m.gens)~='table' then return nil,'Invalid package in mod profile.' end
    if m.tag~=nil and (type(m.tag)~='string' or #m.tag>100 or not m.tag:match('^[%w_.+%-]+$')) then return nil,'Invalid package tag.' end
    if m.sha256~=nil and (type(m.sha256)~='string' or #m.sha256~=64 or not m.sha256:match('^[a-f0-9]+$')) then return nil,'Invalid package fingerprint.' end
    for i=1,5 do if type(m.gens[i])~='boolean' then return nil,'Invalid generation choice.' end end
    ids[m.id]=true
  end
  -- Rebuild an allowlisted document. Unknown fields can never become settings.
  local clean={schema=1,engine=p.engine,mods={}}
  for _,m in ipairs(p.mods) do
    local gens={};for i=1,5 do gens[i]=m.gens[i] end
    clean.mods[#clean.mods+1]={id=m.id,repo=m.repo,version=m.version,on=m.on,gens=gens,tag=m.tag,sha256=m.sha256}
  end
  table.sort(clean.mods,function(a,b) return a.id<b.id end)
  return clean
end
function P.plan(profile,installed,resume)
  local byId={};for _,m in ipairs(installed or {}) do byId[m.id]=m end
  local receipts=Saves.loadOptions().modInstallSources or {}
  local plan={profile=profile,downloads={},flags={},disable={},engineMismatch=profile.engine~=Version.engine}
  local desired={}
  for _,m in ipairs(profile.mods) do
    local have=byId[m.id]
    local receipt=have and receipts[m.id]
    if receipt and receipt.version~=have.version then receipt=nil end
    local repo=receipt and receipt.repo or have and have.github or ''
    local digest=receipt and receipt.sha256 or have and have.packageHash
    if not have or have.version~=m.version or repo:lower()~=m.repo:lower() or m.sha256 and digest~=m.sha256 then plan.downloads[#plan.downloads+1]=m end
    plan.flags[m.id]={on=m.on,gens=clone(m.gens)}
    desired[m.id]=true
  end
  if resume then
    plan.resume=clone(resume)
    for _,id in ipairs(resume.required or {}) do
      desired[id]=true;plan.flags[id]={on=true,gens={true,true,true,true,true}}
    end
  end
  for id in pairs(byId) do if not desired[id] then plan.disable[#plan.disable+1]=id end end
  plan.experimental={};plan.present={};for _,m in ipairs(installed or {}) do plan.present[m.id]=true;if m.experimental then plan.experimental[m.id]=true end end
  table.sort(plan.disable)
  return plan
end
function P.sync(store,mods,options)
  local localProfile=P.capture(mods,options)
  local localHash=fingerprint(localProfile)
  local scope=store.profileScope or store.kind or 'default'
  local prior=state(scope)
  local remoteBytes=store.read(P.PATH)
  if not remoteBytes then
    local ok,why=store.write(P.PATH,S.encode(localProfile));if not ok then return nil,why end
    local saved,err=persist({scope=scope,base=localHash});if not saved then return nil,err end
    return {kind='published',count=#localProfile.mods}
  end
  local remote,why=P.decode(remoteBytes);if not remote then return nil,why end
  local remoteHash=fingerprint(remote)
  if remoteHash==localHash then
    local saved,err=persist({scope=scope,base=localHash});if not saved then return nil,err end
    return {kind='current',count=#remote.mods}
  end
  if prior.base and remoteHash==prior.base then
    local ok,err=store.write(P.PATH,S.encode(localProfile));if not ok then return nil,err end
    local saved,problem=persist({scope=scope,base=localHash});if not saved then return nil,problem end
    return {kind='published',count=#localProfile.mods}
  end
  local plan=P.plan(remote,mods)
  plan.kind=prior.base and prior.base~=localHash and 'conflict' or 'apply'
  plan.hash=remoteHash
  plan.scope=scope
  plan.localHash=localFingerprint(mods,options)
  return plan
end
function P.accept(plan)
  local options=Saves.loadOptions();options.mods=options.mods or {}
  if plan.resume then
    local generation=plan.resume.generation
    if type(generation)~='number' or generation%1~=0 or generation<1 or generation>Gens.COUNT then return nil,'Invalid save generation.' end
    local required={};for _,id in ipairs(plan.resume.required or {}) do required[id]=true end
    local function select(id,want)
      local on,gens,force=Gens.decode(options.mods[id])
      if on==nil then on=not (plan.experimental and plan.experimental[id]) end
      -- Preserve effective activation elsewhere: a master-off, experimental
      -- default-off or previously absent package was off on every generation.
      if want and (not on or not (plan.present and plan.present[id])) then
        for i=1,Gens.COUNT do gens[i]=false end
      end
      if want then on=true end
      gens[generation]=want;if not want then force[generation]=false end
      options.mods[id]=Gens.encode(on,gens,force)
    end
    for id in pairs(plan.flags) do select(id,required[id]==true) end
    for _,id in ipairs(plan.disable or {}) do select(id,false) end
    for id in pairs(options.mods) do if not required[id] then select(id,false) end end
    if not Saves.saveOptions(options) then return nil,'Could not save this game’s mod choices.' end
    -- A per-save restore is a local change, not acceptance of the unrelated
    -- global cloud profile. Keep its conflict base unchanged.
    return true
  end
  local desired={}
  for id,value in pairs(plan.flags) do desired[id]=true;options.mods[id]=clone(value) end
  for _,id in ipairs(plan.disable or {}) do options.mods[id]=Gens.withEnabled(options.mods[id],false) end
  -- Keep files, but disable extra local packages so every device has the same
  -- active set. Nothing is uninstalled, and no generation override is forced.
  for id,value in pairs(options.mods) do
    if not desired[id] then options.mods[id]=Gens.withEnabled(value,false) end
  end
  local ok=Saves.saveOptions(options);if not ok then return nil,'Could not save the mod profile.' end
  return persist({scope=plan.scope or 'default',base=plan.hash or fingerprint(plan.profile)})
end
P.fingerprint=localFingerprint
function P.unchanged(plan,mods,options) return not plan.localHash or plan.localHash==localFingerprint(mods,options) end
function P.publish(store,mods,options)
  local profile=P.capture(mods,options)
  local ok,why=store.write(P.PATH,S.encode(profile));if not ok then return nil,why end
  return persist({scope=store.profileScope or store.kind or 'default',base=fingerprint(profile)})
end
return P
