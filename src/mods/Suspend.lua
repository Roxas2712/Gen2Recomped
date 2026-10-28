-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Opt-in continuation contract. Only data is transported; callbacks always
-- come from the installed, byte-identical mod, never from a save capsule.
local M={MAX_STATE=256*1024,MAX_FILES=12000,MAX_CONTENT=512*1024*1024}
local S=require('src.core.SaveSerializer')
local Runtime=require('src.mods.Runtime')
local function clone(value)
 assert(type(value)=='table','Mod suspend state must be a table')
 local seen,nodes={},0
 local function check(v,depth)
  nodes=nodes+1;assert(nodes<=50000 and depth<=32,'Mod suspend state is too complex')
  local t=type(v)
  if t=='table' then
   assert(not seen[v] and getmetatable(v)==nil,'Mod suspend state must be a plain acyclic table');seen[v]=true
   for k,x in pairs(v)do assert(type(k)=='string' or type(k)=='number','Invalid mod state key');check(k,depth+1);check(x,depth+1)end
   seen[v]=nil
  else assert(t=='nil' or t=='string' or t=='boolean' or t=='number' and v==v and math.abs(v)~=math.huge,'Nonportable mod suspend state')end
 end
 check(value,0);local bytes=S.encodeExact(value);assert(#bytes<=M.MAX_STATE,'Mod suspend state exceeds 256 KiB')
 return assert(S.decode(bytes))
end
local function invoke(id,fn,...)
 local old=Runtime.currentMod;Runtime.currentMod=id
 local ok,value=pcall(fn,...);Runtime.currentMod=old
 assert(ok,'Mod '..id..' suspend callback failed: '..tostring(value))
 return value
end
function M.install(loader,mod,api)
 local id=mod.manifest.id
 api.suspend={register=function(_,contract)
  assert(type(contract)=='table' and type(contract.schema)=='number' and contract.schema>=1 and contract.schema%1==0,'Mod suspend schema must be a positive integer')
  assert(type(contract.capture)=='function' and type(contract.restore)=='function','Mod suspend requires capture and restore callbacks')
  loader.suspendContracts=loader.suspendContracts or {}
  assert(not loader.suspendContracts[id],'Mod suspend contract already registered')
  loader.suspendContracts[id]={schema=contract.schema,capture=contract.capture,restore=contract.restore}
  return true
 end}
end
local function loaded(game) return game.modStatus and game.modStatus.loaded or {} end
function M.available(game)
 for _,row in ipairs(loaded(game))do
  local id=row.id;local loader=game.mods
  if not(loader and loader.mods[id] and loader.suspendContracts and loader.suspendContracts[id])then
   return nil,'Mod '..tostring(id)..' has no portable suspend contract. Normal saves remain available.'
  end
 end
 return true
end
local function hash(bytes)return love.data.encode('string','hex',love.data.hash('sha256',bytes))end
function M.identity(game)
 assert(M.available(game))
 local out={};local budget,count=0,0
 for _,row in ipairs(loaded(game))do
  local id=row.id;local loader=game.mods;local mod=loader.mods[id];local fs=loader.fs;local files={};local visited={}
  local function file(path,label)
   if visited[label]then return end;visited[label]=true
   count=count+1;assert(count<=M.MAX_FILES,'Too many mod suspend files')
   local info=assert(fs.getInfo(path),'Missing mod suspend file: '..label)
   assert(info.type=='file','Invalid mod suspend file: '..label)
   assert((info.size or 0)<=M.MAX_CONTENT-budget,'Mod suspend content exceeds hashing budget')
   local bytes=assert(fs.read(path),'Cannot read mod suspend file: '..label)
   budget=budget+#bytes;assert(budget<=M.MAX_CONTENT,'Mod suspend content exceeds hashing budget')
   files[#files+1]=label..'\0'..hash(bytes)
  end
  local function walk(path,label,depth)
   assert(depth<=32,'Mod directory nesting is too deep')
   for _,name in ipairs(fs.getDirectoryItems(path)or{})do
    assert(not name:find('[/\\]') and name~='.' and name~='..','Unsafe mod file name')
    local p=path..'/'..name;local l=label..'/'..name;local info=assert(fs.getInfo(p))
    if info.type=='directory'then walk(p,l,depth+1)else file(p,l)end
   end
  end
  walk(mod.path,'package',0)
  for _,entry in ipairs(mod.manifest.required_imports or {})do
   if entry.root=='save' or entry.root=='root'then file(entry.file,'import/'..entry.file)end
  end
  assert(#files>0,'Mod suspend package is empty');table.sort(files)
  out[#out+1]={id=id,version=row.version,schema=loader.suspendContracts[id].schema,digest=hash(table.concat(files,'\n'))}
 end
 return out
end
function M.capture(game)
 assert(M.available(game));local out={}
 for _,row in ipairs(loaded(game))do
  local c=game.mods.suspendContracts[row.id]
  out[#out+1]={id=row.id,schema=c.schema,state=clone(invoke(row.id,c.capture))}
 end
 return out
end
function M.restore(game,states)
 assert(type(states)=='table' and #states==#loaded(game),'Mod suspend state set differs')
 for i,row in ipairs(loaded(game))do
  local c=assert(game.mods.suspendContracts[row.id]);local state=states[i]
  assert(type(state)=='table' and state.id==row.id and state.schema==c.schema,'Mod suspend schema/order differs')
  assert(invoke(row.id,c.restore,clone(state.state))~=false,'Mod suspend restore refused by '..row.id)
 end
end
return M
