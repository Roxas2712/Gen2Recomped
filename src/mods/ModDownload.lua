-- Network and hashing stay off the UI thread. Cancelled jobs are retained
-- until their worker exits; a late response can never trigger an install.
local D={MAX_BYTES=512*1024*1024};D.__index=D
local retired={}
function D.reap()
  for i=#retired,1,-1 do
    local job=retired[i]
    if not job.thread:isRunning() then love.filesystem.remove(job.path);table.remove(retired,i) end
  end
end
function D.start(release)
  local zip=type(release)=='table' and release.zip
  if type(zip)~='table' or type(zip.url)~='string' or not zip.url:match('^https://') then return nil,'A secure release ZIP is required.' end
  local size=tonumber(zip.size)
  if size and (size<=0 or size>D.MAX_BYTES) then return nil,'The release exceeds the 512 MB download limit.' end
  if zip.sha256 and (type(zip.sha256)~='string' or #zip.sha256~=64 or not zip.sha256:match('^[a-f0-9]+$')) then return nil,'Invalid release fingerprint.' end
  if not (love.thread and love.thread.newThread and love.thread.newChannel) then return nil,'Background downloading is unavailable in this build.' end
  D.reap();love.filesystem.createDirectory('downloads')
  local path=('downloads/mod_%d_%d.zip'):format(os.time(),math.random(1,999999999))
  local ok,job=pcall(function()
    local channel=love.thread.newChannel();local thread=love.thread.newThread('src/mods/download_worker.lua')
    thread:start({url=zip.url,path=path,absolute=love.filesystem.getSaveDirectory()..'/'..path,
      size=size,digest=zip.sha256,maxBytes=D.MAX_BYTES,packagePath=package.path},channel)
    return setmetatable({path=path,thread=thread,channel=channel,total=size,started=love.timer.getTime()},D)
  end)
  if not ok then return nil,'Could not start download: '..tostring(job) end
  return job
end
function D:cancel()
  if self.cancelled or self.finished then return end
  self.cancelled=true;retired[#retired+1]=self
end
function D:poll()
  D.reap()
  if self.cancelled then return {kind='cancelled'} end
  if self.finished then return self.finished end
  local info=love.filesystem.getInfo(self.path)
  local result=self.channel:pop()
  if result then
    self.finished=result
    if result.kind~='done' then love.filesystem.remove(self.path) end
    return result
  end
  local why=self.thread:getError()
  if not self.thread:isRunning() then
    result=self.channel:pop()
    if result then self.finished=result;if result.kind~='done' then love.filesystem.remove(self.path) end;return result end
  end
  if why or not self.thread:isRunning() or love.timer.getTime()-self.started>330 then
    self:cancel();return {kind='error',error=tostring(why or 'The download stopped or timed out. Please retry.')}
  end
  return {kind='progress',bytes=info and info.size or 0,total=self.total}
end
return D
