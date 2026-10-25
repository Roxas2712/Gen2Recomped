-- Compiles source without running it. This is a static preflight, never a
-- simulated gameplay pass or a promise that callbacks will succeed at runtime.
local P={}
local G=require('src.mods.ModGens')
local T=require('src.mods.ModTargets')
local V=require('src.core.Version')
local Games=require('src.core.GameVersion')
local Semver=require('src.mods.Semver')
function P.inspect(manifests,options,version,fs)
  local report={phase='static',game=version,errors={},warnings={},checked={},skipped={},runtimePending=true}
  local byId,active={},{}
  local function issue(kind,id,message) report[kind][#report[kind]+1]={id=id,message=message} end
  if not Games.VERSIONS[version] then issue('errors','engine','Choose a known game before checking mods.');return report end
  local gen=Games.generation(version);options=options or {}
  for _,m in ipairs(manifests) do
    byId[m.id]=m
    local value=(options.mods or {})[m.id];local on=G.active(value,gen)
    if on==nil then on=not m.experimental end
    if on then
      local forced=T.forced(options,m.id,version) or G.forced(value,gen)
      if (not T.supports(m,version) or not G.allows(m,gen)) and not forced then
        report.skipped[#report.skipped+1]=m.id
        issue('warnings',m.id,'Not enabled for '..version..': outside the declared games/generations.')
      else
        active[m.id]=m
        if forced then issue('warnings',m.id,'Forced compatibility override: support for '..version..' is not established.') end
      end
    end
  end
  local ids={};for id in pairs(active) do ids[#ids+1]=id end;table.sort(ids)
  local budget={files=0,bytes=0,listed=0}
  for _,id in ipairs(ids) do
    local m=active[id];report.checked[#report.checked+1]=id
    if m.api and m.api>V.modApi then issue('errors',id,'Requires mod API '..m.api..'; this engine provides '..V.modApi..'.') end
    if m.game_version and not Semver.satisfies(V.engine,m.game_version) then issue('errors',id,'Requires engine '..m.game_version..'; installed: '..V.engine..'.') end
    for _,spec in ipairs(m.dependencySpecs or {}) do if T.specApplies(spec,version,gen) then
      local dep=active[spec.id]
      if not dep then issue('errors',id,'Required mod '..spec.id..(byId[spec.id] and ' is disabled or unavailable for this game.' or ' is not installed.'))
      elseif spec.range and not Semver.satisfies(dep.version,spec.range) then issue('errors',id,'Needs '..spec.id..' '..spec.range..'; installed: '..tostring(dep.version)..'.') end
    end end
    for _,spec in ipairs(m.conflictSpecs or {}) do
      local other=active[spec.id]
      if other and T.specApplies(spec,version,gen) and (not spec.range or Semver.satisfies(other.version,spec.range)) then issue('errors',id,'Conflicts with enabled mod '..spec.id..'. Disable one of these mods.') end
    end
    for _,field in ipairs({'entry','options_schema','assets_transforms'}) do
      if m[field] and not fs.getInfo(m.path..'/'..m[field]) then issue('errors',id,'Missing '..field..' file: '..m[field]) end
    end
    local function scan(path,depth)
      local function incomplete(reason)
        if not budget.exhausted then issue('warnings',id,reason..' Remaining source can only be checked when loaded at runtime.');budget.exhausted=true end
      end
      if budget.exhausted then return end
      if depth>24 or budget.files>=4096 or budget.bytes>=16*1024*1024 then incomplete('Static source inspection limit reached.');return end
      for _,name in ipairs(fs.getDirectoryItems(path) or {}) do
        budget.listed=budget.listed+1
        if budget.listed>20000 or budget.exhausted then incomplete('Static directory inspection limit reached.');return end
        if name~='.' and name~='..' and not name:find('/',1,true) and not name:find('\\',1,true) then
          local file=path..'/'..name;local info=fs.getInfo(file)
          if info and info.type=='directory' then scan(file,depth+1)
          elseif info and name:lower():match('%.lua$') then
            budget.files=budget.files+1
            if budget.files>4096 or info.size and info.size>4*1024*1024 then incomplete('Lua source exceeds the static scan budget: '..file);return end
            local bytes=fs.read(file)
            if type(bytes)~='string' then issue('errors',id,'Unreadable Lua source: '..file);return end
            if #bytes>4*1024*1024 or budget.bytes+#bytes>16*1024*1024 then incomplete('Lua source exceeds the static scan budget: '..file);return end
            budget.bytes=budget.bytes+#bytes
            if bytes:byte(1)==27 then issue('warnings',id,'Precompiled Lua bytecode cannot be checked portably: '..file)
            else
              local chunk,why=(loadstring or load)(bytes,'@'..file)
              if not chunk then issue('errors',id,'Lua syntax error: '..tostring(why)) end
            end
          end
        end
      end
    end
    scan(m.path,0)
  end
  local visited,visiting={},{}
  local function visit(id)
    if visiting[id] then issue('errors',id,'Circular required dependencies. Remove the dependency cycle.');return end
    if visited[id] then return end
    visiting[id]=true
    for _,spec in ipairs(active[id].dependencySpecs or {}) do if active[spec.id] and T.specApplies(spec,version,gen) then visit(spec.id) end end
    visiting[id]=nil;visited[id]=true
  end
  for _,id in ipairs(ids) do visit(id) end
  return report
end
function P.log(report)
  local lines={'RETRORECOMPED · MOD PREFLIGHT','Game: '..tostring(report.game),'STATIC CHECK · no mod code was executed',
    'Checked '..#report.checked..' mods · '..#report.errors..' errors · '..#report.warnings..' notices',''}
  for _,kind in ipairs({'errors','warnings'}) do for _,row in ipairs(report[kind]) do lines[#lines+1]=(kind=='errors' and '[ERROR] ' or '[NOTICE] ')..row.id..': '..row.message end end
  lines[#lines+1]='';lines[#lines+1]='Runtime callbacks, content behavior and game-specific interactions remain runtime checks. A successful static check is not a gameplay test.'
  return table.concat(lines,'\n')
end
return P
