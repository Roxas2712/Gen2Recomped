-- Main-thread resource services share a wall-clock slice. Providers retain
-- their own typed jobs and cancellation; no private worker module is copied.
local S={BUDGET=.002,_uploadedThisFrame=false}
local services=setmetatable({},{__mode='v'})
function S.register(service)services[#services+1]=service;return service end
function S.poll()
  for _,service in pairs(services)do if service.poll then service:poll()end end
end
-- a service with a queued job: AtlasRuntime/SpriteRuntime answer through
-- pending() (a table of jobs); anything else is never busy
function S.busy()
  for _,service in pairs(services)do
    if service.pending then
      local ok,jobs=pcall(service.pending,service)
      if ok and type(jobs)=='table'and next(jobs)~=nil then return true end
    end
  end
  return false
end
-- W0: the caller may offer its own slice (the frame pacer's idle time);
-- the default is the historical 2 ms
function S.update(budget)
  local clock=love and love.timer and love.timer.getTime or os.clock
  local deadline=clock()+(tonumber(budget)or S.BUDGET)
  for _,service in pairs(services)do
    if service.step then service:step(math.max(0,deadline-clock()))end
    if service.update then service:update()end
    if clock()>=deadline then break end
  end
end
function S.cancelPending()
  for _,service in pairs(services)do if service.cancelPending then service:cancelPending()end end
end
function S.cancelOwner(owner)
  for _,service in pairs(services)do if service.releaseOwner then
    local ok,why=pcall(service.releaseOwner,service,owner)
    if not ok then print('[compat/stream] owner cleanup failed: '..tostring(why))end
  end end
end
function S.frameComplete()S._uploadedThisFrame=false end
function S.shutdown()
  for _,service in pairs(services)do if service.release then service:release()end end
end
S.release=S.shutdown
return S
