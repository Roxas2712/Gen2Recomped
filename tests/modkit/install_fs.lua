-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Owned in-memory filesystem boundary; never forwards IO to a user profile.
local Merge=require('src.mods.Merge')
return function()
 local Cache=require('src.import.CacheFs');local Saves=require('src.core.SaveData')
 local m={files={},dirs={['']=true},mounts={},archives={},options={mods={}},reads=0,writes=0}
 local Safety=require('src.core.SaveSafety')
 local old={fs=love.filesystem,open=io.open,cache={},load=Saves.loadOptions,save=Saves.saveOptions,folders=Saves.gameFolders,
  persistence=Saves.persistenceFs,real=Safety.realPath}
 local function rel(path)return path:gsub('^/owned/','')end
 local function lookup(path)
  path=rel(path)
  for prefix,tree in pairs(m.mounts)do
   if path:sub(1,#prefix+1)==prefix..'/' then return tree[path:sub(#prefix+2)]end
  end
  return m.files[path]
 end
 local fs={}
 function fs.getInfo(path,kind)
  path=rel(path)
  local value=lookup(path)
  if value~=nil then return (not kind or kind=='file')and{type='file',size=#value}or nil end
  local prefix=path==''and''or path..'/'
  local isDir=m.dirs[path]
  for key in pairs(m.files)do if key:sub(1,#prefix)==prefix then isDir=true end end
  for mount,tree in pairs(m.mounts)do
   if path==mount then isDir=true end
   if path:sub(1,#mount+1)==mount..'/' then
    local sub=path:sub(#mount+2)..'/'
    for key in pairs(tree)do if key:sub(1,#sub)==sub then isDir=true end end
   end
  end
  return isDir and(not kind or kind=='directory')and{type='directory'}or nil
 end
 function fs.getDirectoryItems(path)
  local found={};local prefix=path==''and''or path..'/'
  local function add(key)
   if key:sub(1,#prefix)==prefix then local child=key:sub(#prefix+1):match('^[^/]+');if child then found[child]=true end end
  end
  for key in pairs(m.files)do add(key)end;for key in pairs(m.dirs)do add(key)end
  for mount,tree in pairs(m.mounts)do for key in pairs(tree)do add(mount..'/'..key)end end
  local result={};for name in pairs(found)do result[#result+1]=name end;table.sort(result);return result
 end
 function fs.createDirectory(path)
  local cur='';for part in path:gmatch('[^/]+')do cur=cur==''and part or cur..'/'..part;m.dirs[cur]=true end;return true
 end
 function fs.write(path,bytes)
  if m.failWrite and m.failWrite(path,bytes)then return nil,'injected write failure'end
  fs.createDirectory(path:match('^(.*)/')or'');m.files[path]=bytes;m.writes=m.writes+1;return true
 end
 function fs.read(path,amount)
  m.reads=m.reads+1;local value=lookup(path);if not value then return nil,'missing'end
  return amount and value:sub(1,amount)or value
 end
 function fs.load(path)
  local bytes=lookup(path);if not bytes then return nil,'missing'end
  return loadstring(bytes,'@'..path)
 end
 function fs.remove(path)
  if m.failRemove and m.failRemove(path)then return nil end
  if #fs.getDirectoryItems(path)>0 then return nil end
  m.files[path],m.dirs[path]=nil,nil;return true
 end
 function fs.getSaveDirectory()return '/owned'end
 function fs.getRealDirectory(path)return m.foreign and m.foreign(path)or'/owned'end
 function fs.newFileData(bytes)return{bytes=bytes}end
 function fs.mount(input,where)
  local bytes=type(input)=='table'and input.bytes or lookup(input)
  local tree=m.archives[bytes];if not tree then return false end
  m.mounts[where]=tree;m.keys=m.keys or{};m.keys[input]=where;return true
 end
 function fs.unmount(input)
  local where=m.keys and m.keys[input];if not where then return false end
  m.mounts[where]=nil;m.keys[input]=nil;return true
 end
 function fs.newFile(path,mode)
  path=rel(path);local cursor=0
  if mode=='r'and lookup(path)==nil then return nil,'missing'end
  if mode=='w'then if not fs.write(path,'')then return nil end end
  local file={}
  function file:read(amount)
   m.reads=m.reads+1;local value=lookup(path)
   if cursor>=#value then return nil end
   local out=value:sub(cursor+1,cursor+amount);cursor=cursor+#out
   if m.afterRead then m.afterRead(path,#out)end
   return out
  end
  function file:write(bytes)return fs.write(path,(m.files[path]or'')..bytes)end
  function file:close()if m.failClose and m.failClose(path)then return false,'close failed'end;return true end
  function file:seek(kind,offset)
   if kind=='end'then cursor=#lookup(path)elseif kind=='set'then cursor=offset else cursor=kind end
   return cursor
  end
  function file:getSize()return #lookup(path)end
  return file
 end
 fs.openFile=fs.newFile
 function fs.rename(from,to)
  if m.failRename and m.failRename(from,to)then return nil,'injected rename failure'end
  local value=m.files[from]
  if value then m.files[to]=value;m.files[from]=nil
  else
   if fs.getInfo(to)or not fs.getInfo(from)then return nil,'destination exists or source missing'end
   local moving,dirs={},{}
   for key,bytes in pairs(m.files)do if key:sub(1,#from+1)==from..'/'then moving[to..key:sub(#from+1)]=bytes;m.files[key]=nil end end
   for key in pairs(m.dirs)do if key==from or key:sub(1,#from+1)==from..'/'then dirs[to..key:sub(#from+1)]=true;m.dirs[key]=nil end end
   for key,bytes in pairs(moving)do m.files[key]=bytes end;for key in pairs(dirs)do m.dirs[key]=true end
  end
  if m.afterRename then m.afterRename(from,to)end
  return true
 end
 love.filesystem=fs
 io.open=function(path,mode)
  if path:sub(1,7)~='/owned/'then return nil end
  return fs.newFile(path,mode=='rb'and'r'or'w')
 end
 local bindings={root=function()return '/owned'end,dataFs=function()return fs end,
  rawWrite=fs.write,rawCreateDirectory=fs.createDirectory,rawRemove=fs.remove,rawRemoveDir=fs.remove,rawRename=fs.rename}
 for key,value in pairs(bindings)do old.cache[key]=Cache[key];Cache[key]=value end
 Saves.loadOptions=function()return Merge.deepCopy(m.options)end
 Saves.saveOptions=function(options)
  if m.failOptions then m.failOptions=false;return nil end
  m.options=Merge.deepCopy(options);return true
 end
 Saves.gameFolders=function()return{}end
 Saves.persistenceFs=function()return fs end
 Safety.realPath=function()return nil end
 function m.restore()
  require('src.mods.ModInstallJob').releaseAll()
  love.filesystem,io.open=old.fs,old.open
  for key,value in pairs(old.cache)do Cache[key]=value end
  Saves.loadOptions,Saves.saveOptions,Saves.gameFolders=old.load,old.save,old.folders
  Saves.persistenceFs=old.persistence;Safety.realPath=old.real
 end
 m.fs=fs
 return m
end
