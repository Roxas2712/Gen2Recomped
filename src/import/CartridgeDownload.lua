-- Explicit, cancellable artwork fetch. No auth token or game data is sent.
local D={};D.__index=D
local retired={}
function D.reap()
  for i=#retired,1,-1 do
    local job=retired[i]
    if not job.thread:isRunning() then love.filesystem.remove(job.path);table.remove(retired,i) end
  end
end
local function start(url,version,preview)
  if not (love.thread and love.thread.newThread and love.thread.newChannel) then return nil,'Background downloading is unavailable.' end
  D.reap();love.filesystem.createDirectory('launcher/cart_downloads')
  local path=('launcher/cart_downloads/%s_%d_%d.png'):format(version,os.time(),math.random(1,999999999))
  local ok,job=pcall(function()
    local channel=love.thread.newChannel();local thread=love.thread.newThread('src/import/cartridge_download_worker.lua')
    thread:start({url=url,preview=preview,path=path,absolute=love.filesystem.getSaveDirectory()..'/'..path,packagePath=package.path},channel)
    return setmetatable({path=path,thread=thread,channel=channel,started=love.timer.getTime()},D)
  end)
  return ok and job or nil,ok and nil or tostring(job)
end
function D.start(version,confirmed)
  if confirmed~=true then return nil,'Confirm the artwork source and rights notice first.' end
  local source=require('src.import.CartridgeSources').get(version)
  if not source then return nil,'No original cartridge reference is available for this edition.' end
  local job,why=start(source.image,version,false)
  if job then job.source=source end
  return job,why
end
function D.verify(bytes,source)
  if type(bytes)~='string' or #bytes==0 or #bytes>8*1024*1024 then return nil,'Invalid artwork download.' end
  if source and source.sha256 then
    if #bytes~=source.bytes or love.data.encode('string','hex',love.data.hash('sha256',bytes))~=source.sha256 then
      return nil,'The cartridge image did not match its published fingerprint. Please retry the download.'
    end
  end
  return true
end
function D.preview(url)
  if type(url)~='string' or not (url:match('^https://pokexpert%.de/') or url:match('^https://i%.ytimg%.com/')) then return nil,'Untrusted preview source.' end
  return start(url,'preview',true)
end
function D:cancel()
  if self.cancelled or self.finished then return end
  self.cancelled=true;retired[#retired+1]=self
end
function D:poll()
  D.reap();if self.cancelled then return {kind='cancelled'} end
  if self.finished then return self.finished end
  local result=self.channel:pop()
  if not result and not self.thread:isRunning() then result=self.channel:pop() or {kind='error',error=self.thread:getError() or 'The artwork download stopped.'} end
  if not result and love.timer.getTime()-self.started>330 then self:cancel();return {kind='error',error='Artwork download timed out.'} end
  if result then
    self.finished=result
    if result.kind=='done' then
      local info=love.filesystem.getInfo(self.path)
      if not info or info.size<=0 or info.size>8*1024*1024 then result={kind='error',error='Artwork exceeds the 8 MB limit.'}
      else
        local bytes=love.filesystem.read(self.path)
        local valid,why=D.verify(bytes,self.source)
        if valid then result.bytes=bytes else result={kind='error',error=why} end
      end
    end
    love.filesystem.remove(self.path);self.finished=result;return result
  end
end
return D
