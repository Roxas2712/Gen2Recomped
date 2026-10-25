-- Requirements travel inside the save, so cloud transfers cannot pair a save
-- with a different device's newer global mod profile. This is battery-save
-- compatibility metadata; it does not serialize a running Lua continuation.
local R={SCHEMA=1}
local S=require('src.core.SaveSerializer')
local Version=require('src.core.Version')
local Games=require('src.core.GameVersion')
local Gens=require('src.mods.ModGens')
local Profile=require('src.mods.ModProfiles')
local Semver=require('src.mods.Semver')
local function id(value) return type(value)=='string' and #value<=128 and value:match('^[%w_%-][%w_.%-]*$') and not value:find('..',1,true) end
local function text(value) return type(value)=='string' and #value>0 and #value<=80 and not value:find('[%c]') end
local function integer(value,limit) return type(value)=='number' and value%1==0 and value>=0 and value<=limit end
function R.capture(version,loaded,options)
  if not Games.VERSIONS[version] then return nil,'Unknown game version.' end
  local portable={}
  for _,m in ipairs(Profile.capture(loaded,options or {}).mods) do portable[m.id]=m end
  local out={schema=R.SCHEMA,version=version,engine=Version.engine,modApi=Version.modApi,saveFormat=Version.saveFormat,mods={}}
  for _,m in ipairs(loaded or {}) do
    if not id(m.id) or not text(m.version) or not integer(m.api or 1,1000) then return nil,'A loaded mod has no stable identity.' end
    local p=portable[m.id]
    out.mods[#out.mods+1]={id=m.id,version=m.version,api=m.api or 1,repo=p and p.repo,tag=p and p.tag,sha256=p and p.sha256}
  end
  table.sort(out.mods,function(a,b) return a.id<b.id end)
  return R.decode(out)
end
function R.decode(raw)
  if type(raw)~='table' or raw.schema~=R.SCHEMA or not Games.VERSIONS[raw.version] or not text(raw.engine)
    or not integer(raw.modApi,1000) or not integer(raw.saveFormat,1000) or type(raw.mods)~='table' or #raw.mods>256 then return nil,'Unsupported save requirements.' end
  local clean={schema=R.SCHEMA,version=raw.version,engine=raw.engine,modApi=raw.modApi,saveFormat=raw.saveFormat,mods={}}
  local seen={}
  for _,m in ipairs(raw.mods) do
    if type(m)~='table' or not id(m.id) or seen[m.id] or not text(m.version) or not integer(m.api,1000) then return nil,'Invalid save mod requirements.' end
    local row={id=m.id,version=m.version,api=m.api}
    if m.repo then
      local p,why=Profile.decode(S.encode({schema=1,engine=raw.engine,mods={{id=m.id,repo=m.repo,version=m.version,on=true,gens={true,true,true,true,true},tag=m.tag,sha256=m.sha256}}}))
      if not p then return nil,why end
      local source=p.mods[1];row.repo=source.repo;row.tag=source.tag;row.sha256=source.sha256
    elseif m.tag or m.sha256 then return nil,'Package provenance has no repository.' end
    clean.mods[#clean.mods+1]=row;seen[m.id]=true
  end
  table.sort(clean.mods,function(a,b) return a.id<b.id end)
  return clean
end
local function active(mod,options,generation)
  local supported=mod.supportedGens or mod.generations
  return not mod.supersededBy and Gens.resolve(options.mods and options.mods[mod.id],generation,mod.experimental)
    and Gens.permits({generations=supported},options.mods and options.mods[mod.id],generation)
end
function R.assess(save,version,installed,options)
  options=options or {};installed=installed or {}
  local meta=type(save.meta)=='table' and save.meta or {}
  local requirements,why
  local legacy=meta.resume==nil
  if not legacy then requirements,why=R.decode(meta.resume)
  else
    local mods={}
    if meta.mods~=nil and type(meta.mods)~='table' then return {blocked=true,needsReview=true,rows={},problems={'Invalid legacy mod list.'},version=version} end
    for _,m in ipairs(meta.mods or {}) do
      if type(m)~='table' then return {blocked=true,needsReview=true,rows={},problems={'Invalid legacy mod identity.'},version=version} end
      mods[#mods+1]={id=m.id,version=m.version,api=m.api or 1}
    end
    requirements,why=R.decode({schema=1,version=version,engine=meta.engine or Version.engine,modApi=Version.modApi,saveFormat=meta.format or 1,mods=mods})
  end
  local report={version=version,legacy=legacy,rows={},problems={},blocked=false,needsReview=false}
  if not requirements or requirements.version~=version or save.version and save.version~=version then
    report.blocked=true;report.needsReview=true;report.problems[1]=why or 'This save belongs to a different game.';return report
  end
  report.requirements=requirements
  report.engineMismatch=requirements.engine~=Version.engine
  if report.engineMismatch then report.problems[#report.problems+1]='Saved with engine '..requirements.engine..'; this device runs '..Version.engine..'.' end
  if requirements.saveFormat>Version.saveFormat or requirements.modApi>Version.modApi then
    report.blocked=true;report.problems[#report.problems+1]='Update RetroRecomped before opening this save.'
  end
  local generation=Games.generation(version)
  local byId={};for _,m in ipairs(installed) do byId[m.id]=m end
  local profile={schema=1,engine=requirements.engine,mods={}}
  local required,canRestore={},true
  for _,wanted in ipairs(requirements.mods) do
    required[wanted.id]=true
    local have=byId[wanted.id]
    local receipt=have and options.modInstallSources and options.modInstallSources[wanted.id]
    if receipt and receipt.version~=have.version then receipt=nil end
    local repo=receipt and receipt.repo or have and have.github
    local digest=receipt and receipt.sha256 or have and have.packageHash
    local mismatch=not have or have.version~=wanted.version or wanted.repo and (not repo or repo:lower()~=wanted.repo:lower()) or wanted.sha256 and digest~=wanted.sha256
    local enabled=have and active(have,options,generation)
    local unsupported=have and not Gens.permits({generations=have.supportedGens or have.generations},options.mods and options.mods[wanted.id],generation)
    local row={id=wanted.id,version=wanted.version,status=mismatch and (wanted.repo and 'download' or 'manual') or not enabled and 'enable' or 'ready'}
    if wanted.api>Version.modApi then row.status='manual';report.blocked=true end
    if have and (type(have.api)=='number' and have.api>Version.modApi or have.game_version and not Semver.satisfies(Version.engine,have.game_version)) then
      row.status='manual';row.detail='This installed package does not support the current engine.'
    end
    if have and (have.missingImports and next(have.missingImports) or have.missingGames and next(have.missingGames)) then
      row.status='manual';row.detail='Import this mod’s required local files or games in the mod manager.'
    end
    if unsupported then row.status='manual';row.detail='Enable the generation override manually in Mods if you intend to use it.' end
    if row.status=='manual' then canRestore=false end
    if row.status~='ready' then report.needsReview=true end
    report.rows[#report.rows+1]=row
    if wanted.repo then profile.mods[#profile.mods+1]={id=wanted.id,repo=wanted.repo,version=wanted.version,tag=wanted.tag,sha256=wanted.sha256,on=true,gens={true,true,true,true,true}} end
  end
  for _,m in ipairs(installed) do
    if not required[m.id] and active(m,options,generation) then
      report.rows[#report.rows+1]={id=m.id,version=m.version,status='disable'};report.needsReview=true
    end
  end
  report.needsReview=report.needsReview or report.engineMismatch or report.blocked
  if canRestore and not report.blocked then
    local ids={};for modId in pairs(required) do ids[#ids+1]=modId end;table.sort(ids)
    report.plan=Profile.plan(profile,installed,{generation=generation,required=ids})
    report.plan.kind='apply';report.plan.localHash=Profile.fingerprint(installed,options)
  end
  return report
end
function R.fingerprint(save) return S.encode(save) end
return R
