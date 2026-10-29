-- Bounded GB image/RED++ hints, following Gen1Recomp #2872. The existing
-- build pool owns threads; idle callbacks retain CPU pixels, never textures.
-- Contributions by Roxas2712; existing upstream licences remain applicable.
local P=require('src.core.Performance')
local Workers=require('src.core.BuildWorker')
local Idle=require('src.core.IdleStream')
local M={MAX_BYTES=16*1024*1024,MAX_IMAGE_BYTES=4*1024*1024,MAX_QUEUE=64}
local queue,queued,pending,ready={},{},{},{}
local bytes,reserved,serial,epoch=0,0,0,0
local timedOut=false
local failures,lastError=0,nil
Workers.register('gb-assets','src.render.GbAssetWorker')
local function clock()return love and love.timer and love.timer.getTime()or os.clock()end
local function release(data)if data and data.release then pcall(data.release,data)end end
local function drop(key)
  local row=ready[key]
  if row then ready[key]=nil;bytes=bytes-row.bytes;release(row.data)end
end
function M.clear()
  epoch=epoch+1
  for _,job in pairs(pending)do Workers.cancel(job.id)end
  for key in pairs(ready)do drop(key)end
  queue,queued,pending={},{},{};reserved=0
  timedOut=false
end
local function enabled()return not timedOut and P.gbAssetPrefetch~=false and Workers.available()end
function M.request(key,make,front)
  if not enabled()then return false end
  if ready[key]or pending[key]then return true end
  local job=queued[key]
  if job then
    if front then
      for i,v in ipairs(queue)do if v==job then table.remove(queue,i);break end end
      table.insert(queue,1,job)
    end
    return true
  end
  if #queue>=M.MAX_QUEUE then return false end
  job={key=key,make=make};queued[key]=job
  if front then table.insert(queue,1,job)else queue[#queue+1]=job end
  return true
end
function M.get(key,signature,take)
  if not enabled()then M.clear();return nil end
  local row=ready[key]
  if not row then return nil end
  if row.signature~=signature then drop(key);return nil end
  serial=serial+1;row.used=serial
  if take then ready[key]=nil;bytes=bytes-row.bytes end
  return row.data
end
function M.has(key)return ready[key]~=nil end
function M.forget(key)
  drop(key)
  if pending[key]then
    Workers.cancel(pending[key].id);reserved=reserved-pending[key].size;pending[key]=nil
  end
  queued[key]=nil -- queued callbacks become inert without rebuilding the list
end
local service={}
function service.busy()
  return #queue>0 or next(pending)~=nil or(P.gbAssetPrefetch==false and next(ready)~=nil)
end
function service.step()
  if not enabled()then M.clear();return end
  local now=clock();local inflight=0
  for key,job in pairs(pending)do
    if now-job.at>5 then M.clear();timedOut=true;return else inflight=inflight+1 end
  end
  if inflight>=2 then return end
  local job=table.remove(queue,1)
  if not job then return end
  if queued[job.key]~=job then return end
  queued[job.key]=nil
  local ok,payload,signature,size=pcall(job.make)
  if not ok then failures=failures+1;lastError=tostring(payload)end
  if not ok or not payload or type(size)~='number'or size<=0 or size>M.MAX_IMAGE_BYTES then return end
  while bytes+reserved+size>M.MAX_BYTES do
    local oldest,stamp
    for key,row in pairs(ready)do if not stamp or row.used<stamp then oldest,stamp=key,row.used end end
    if not oldest then return end
    drop(oldest)
  end
  local captured=epoch
  local function retire()if pending[job.key]==job then
    pending[job.key]=nil;reserved=reserved-size
  end end
  job.size,job.at=size,now
  job.id=Workers.submit('gb-assets',job.key,payload,function(data)
    retire()
    if captured~=epoch or P.gbAssetPrefetch==false then release(data);return end
    local valid,n=pcall(function()return data:getSize()end)
    if not valid or n~=size or bytes+n>M.MAX_BYTES then release(data);return end
    drop(job.key);serial=serial+1
    ready[job.key]={data=data,signature=signature,bytes=n,used=serial};bytes=bytes+n
  end,function(why)retire();failures=failures+1;lastError=tostring(why)end)
  if job.id then pending[job.key]=job;reserved=reserved+size end
end
function M.status()local n=0;for _ in pairs(pending)do n=n+1 end
  return{bytes=bytes,reserved=reserved,queued=#queue,pending=n,epoch=epoch,
    errors=failures,lastError=lastError}
end
M.service=Idle.register(service)
return M
