-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Cooperative IO and ownership for launcher-only package transactions.
local Cache=require('src.import.CacheFs')
local J={CHUNK=256*1024,STEP_BUDGET=.006};J.__index=J
local live,serial={},0
local cancelled={}
local function clock()return love and love.timer and love.timer.getTime and love.timer.getTime() or os.clock()end
local function root()return Cache.root() or love.filesystem.getSaveDirectory()end
local function sameRoot(a,b)
  if type(a)~='string' or type(b)~='string' then return false end
  a=a:gsub('\\','/'):gsub('/+$','');b=b:gsub('\\','/'):gsub('/+$','')
  if package.config:sub(1,1)=='\\' then a=a:lower();b=b:lower()end
  return a==b
end
function J.new(body)
  for job in pairs(live)do if not job.result then return nil,'Another mod installation is running.' end end
  serial=serial+1
  local self=setmetatable({progress={done=0,total=0,phase='preparing'},handles={},cleanups={},
    token=('install-%d-%d-%d'):format(os.time(),serial,math.random(1,999999999)),root=root(),completed={}},J)
  assert(type(self.root)=='string' and self.root~='','No writable installation folder.')
  self.area='mod-install-staging/'..self.token
  assert(not love.filesystem.getInfo(self.area),'Installation staging folder already exists.')
  self.co=coroutine.create(function()return body(self)end)
  live[self]=true
  return self
end
function J:checkpoint(phase,done,total)
  self.progress.phase=phase or self.progress.phase
  self.progress.done=done or self.progress.done
  self.progress.total=total or self.progress.total
  if self.cancelled and not self.committed and not self.cleaning then error(cancelled,0)end
  assert(sameRoot(root(),self.root),'The installation folder changed; retry the import.')
  coroutine.yield()
  if self.cancelled and not self.committed and not self.cleaning then error(cancelled,0)end
  assert(sameRoot(root(),self.root),'The installation folder changed; retry the import.')
end
function J:track(handle)
  assert(handle,'Could not open package file.')
  self.handles[handle]=true;return handle
end
function J:close(handle)
  local ok,why=handle:close();assert(ok~=false and ok~=nil,why or 'Could not close package file.')
  self.handles[handle]=nil
end
function J:defer(fn)self.cleanups[#self.cleanups+1]=fn end
function J:openRead(path)
  local fs=love.filesystem;local open=fs.openFile or fs.newFile
  assert(open,'Streaming file reads are unavailable.')
  local handle,why=open(path,'r');assert(handle,why or 'Could not open '..path)
  return self:track(handle)
end
function J:openWrite(path)
  assert(sameRoot(root(),self.root),'The installation folder changed.')
  local handle=Cache.dataFs().newFile(path,'w')
  return self:track(handle)
end
function J:write(path,bytes)
  local file=self:openWrite(path)
  for at=1,#bytes,J.CHUNK do
    local ok,why=file:write(bytes:sub(at,at+J.CHUNK-1));assert(ok,why or 'Could not write '..path)
    self:checkpoint('writing',math.min(at+J.CHUNK-1,#bytes),#bytes)
  end
  self:close(file)
end
function J:copyTree(source,dest,phase)
  assert(Cache.rawCreateDirectory(dest),'Could not create package staging folder.')
  self:checkpoint(phase or 'copying',0,0)
  for _,name in ipairs(love.filesystem.getDirectoryItems(source))do
    assert(type(name)=='string' and name~='.' and name~='..' and not name:find('[/\\%z%c]'),'Invalid package path.')
    local from,to=source..'/'..name,dest..'/'..name
    local info=assert(love.filesystem.getInfo(from),'A package file disappeared.')
    assert(info.type~='symlink','Package symlinks are not supported.')
    if info.type=='directory' then self:copyTree(from,to,phase)
    else
      assert(info.type=='file','Unsupported package entry.')
      local input,output=self:openRead(from),self:openWrite(to)
      local count=0
      while true do
        local bytes,why=input:read(J.CHUNK)
        assert(bytes~=nil or not why,why)
        if not bytes or bytes=='' then break end
        assert(output:write(bytes),'Could not write package file '..name)
        count=count+#bytes;self:checkpoint(phase or 'copying',count,info.size or count)
      end
      self:close(input);self:close(output)
      if info.size then assert(count==info.size,'Package file changed while copying: '..name)end
      -- Read back the written bytes, including retained private imports.
      input=self:openRead(from);local check=self:openRead(to)
      while true do
        local a,ae=input:read(J.CHUNK);local b,be=check:read(J.CHUNK)
        -- LOVE returns (bytes, byteCount); io providers return (bytes, err).
        assert(type(ae)~='string' and type(be)~='string' and a==b,'Package file did not read back whole: '..name)
        if not a or a=='' then break end
        self:checkpoint('verifying',count,info.size or count)
      end
      self:close(input);self:close(check)
    end
  end
end
-- Only task-owned unique staging/journal paths may be removed here. Active
-- mods are moved back to staging by the transaction before cleanup.
function J:removeOwned(path,yielding)
  local area=path:match('^(mod%-install%-staging/install%-%d+%-%d+%-%d+)')
  local profile=self.profileCleanupRoot
  assert(area and (path==area or path:sub(1,#area+1)==area..'/') or
    profile and (path==profile or path:sub(1,#profile+1)==profile..'/') or
    path:match('^mod%-install%-journal/install%-%d+%-%d+%-%d+%.json[%.%w]*$'),'Invalid installer cleanup path.')
  for part in path:gmatch('[^/]+')do assert(part~='.' and part~='..' and not part:find('[\\%z%c]'),'Invalid installer path.')end
  assert(sameRoot(root(),self.root),'Recovery files retained in the previous installation folder.')
  local info=love.filesystem.getInfo(path)
  if not info then return end
  if info.type=='directory' then
    for _,name in ipairs(love.filesystem.getDirectoryItems(path))do
      assert(name~='.' and name~='..' and not name:find('[/\\%z%c]'),'Invalid recovery entry.')
      self:removeOwned(path..'/'..name,yielding)
    end
    Cache.rawRemoveDir(path)
  else Cache.rawRemove(path) end
  assert(not love.filesystem.getInfo(path),'Could not clean installer recovery file '..path)
  if yielding then self:checkpoint('cleanup',0,0)end
end
function J:removeProfile(path,yielding)
  assert(type(path)=='string'and path:match('^mod%-profile%-backups/%d+%-%d+$'),'Invalid profile cleanup folder.')
  local previous=self.profileCleanupRoot;self.profileCleanupRoot=path
  local ok,why=pcall(self.removeOwned,self,path,yielding)
  self.profileCleanupRoot=previous;if not ok then error(why,0)end
end
function J:readArchive(source)
  local limit=require('src.core.Platform').isNX() and 64*1024*1024 or nil
  local input,size
  if type(source)=='string' then
    -- Relative picks belong to the mounted data root, not the shell's cwd.
    local relative=not source:match('^[/\\]')and not source:match('^%a:')
    local info=relative and love.filesystem.getInfo(source,'file')
    if info then size=info.size;input=self:openRead(source)
    else input,size=require('src.core.NativeFile').openRead(source)end
    if input then
      self:track(input)
    else
      local info=love.filesystem.getInfo(source,'file');size=info and info.size
      input=self:openRead(source)
    end
  elseif (type(source)=='table' or type(source)=='userdata') and source.open then
    assert(source:open('r'),'Could not open dropped archive.');input=self:track(source);size=source:getSize()
  else error('Unsupported archive source.',0)end
  assert(not limit or not size or size<=limit,'This Switch build accepts mod ZIPs up to 64 MiB.')
  local chunks,count,magic={},0,nil
  local output
  if not limit then
    assert(Cache.rawCreateDirectory(self.area),'Could not create installer staging folder.')
    self.archivePath=self.area..'/archive.zip';output=self:openWrite(self.archivePath)
  end
  while true do
    local bytes,why=input:read(J.CHUNK);assert(bytes~=nil or not why,why)
    if not bytes or bytes=='' then break end
    magic=magic or bytes:sub(1,4)
    assert(magic:sub(1,2)=='PK','Not a ZIP archive.')
    count=count+#bytes;assert(not limit or count<=limit,'This Switch build accepts mod ZIPs up to 64 MiB.')
    if output then assert(output:write(bytes),'Could not stage the archive.')else chunks[#chunks+1]=bytes end
    self:checkpoint('reading',count,size or count)
  end
  self:close(input);if output then self:close(output)end
  if size then assert(count==size,'Archive changed while reading.')end
  if output then return magic or '' end
  return table.concat(chunks)
end
local function finishIO(self)
  for file in pairs(self.handles)do pcall(file.close,file)end;self.handles={}
  for i=#self.cleanups,1,-1 do
    local ok,why=pcall(self.cleanups[i]);if not ok then self.warning='Recovery files retained: '..tostring(why)end
  end;self.cleanups={}
end
function J:cleanArea(yielding)
  if self.pendingReceipt then return end
  if self.profileDraft then require('src.mods.ModProfileInstallJobs').cancelDraft(self,yielding)end
  self:removeOwned(self.area,yielding)
  local path='mod-install-journal/'..self.token..'.json'
  self:removeOwned(path..'.tmp',yielding)
  if self.stagingReceipt then self:removeOwned(self.stagingReceipt,yielding);self.stagingReceipt=nil end
end
function J:finishItem()
  finishIO(self)
  local ok,why=pcall(self.cleanArea,self,true)
  if not ok then self.warning='Installer recovery files were retained: '..tostring(why);self.halted=true end
  self.archivePath=nil
  if not self.pendingReceipt then self.committed=false else self.halted=true end
end
local function startCleanup(self,reason)
  finishIO(self);self.cleaning=true
  self.co=coroutine.create(function()
    local ok,why=pcall(self.cleanArea,self,true)
    if not ok then self.warning='Recovery files retained: '..tostring(why)end
    return nil,reason..(self.warning and ('; '..self.warning)or'')
  end)
end
function J.step(self,budget,time)
  if self.result then return 'done',unpack(self.result,1,3)end
  time=time or clock;local untilAt=time()+(budget or J.STEP_BUDGET)
  repeat
    local ok,a,b,c=coroutine.resume(self.co)
    if not ok then
      if not self.cleaning then
        startCleanup(self,a==cancelled and 'install cancelled' or 'Import failed: '..tostring(a))
      else
        finishIO(self);live[self]=nil;self.result={nil,'Recovery files retained: '..tostring(a)}
        return 'done',nil,self.result[2]
      end
    elseif coroutine.status(self.co)=='dead' then
      finishIO(self);live[self]=nil;self.result={a,b,c};return 'done',a,b,c
    end
  until time()>=untilAt
  return 'running',self.progress
end
function J.cancel(self)
  if not self or self.result then return true end
  if self.committed or self.pendingReceipt then return false end
  if self.cleaning then return true end
  self.cancelled=true
  -- No installed bytes have changed at a yielding boundary before commit.
  startCleanup(self,'install cancelled')
  return true
end
function J.releaseAll()
  local jobs={};for job in pairs(live)do jobs[#jobs+1]=job end
  for _,job in ipairs(jobs)do
    finishIO(job);live[job]=nil
    job.result={nil,'Installation interrupted; recovery resumes next launch.'}
  end
end
function J.busy()for job in pairs(live)do if not job.result then return true end end;return false end
J.sameRoot=sameRoot
require('src.core.SessionLifecycle').registerProcessShutdown(J.releaseAll)
return J
