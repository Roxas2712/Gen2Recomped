-- W0 -- THE FRAME'S IDLE TIME BUILDS THE NEXT MAP.
--
-- The Gen 3 native path (src/core/game3/asset_stream, AtlasRuntime,
-- SpriteRuntime) was written as a cooperative stream: every atlas and
-- sprite build is a coroutine with a per-slice budget, a priority and a
-- prefetch entry point.  Nothing ever pumped it.  Every build ran to
-- completion inside the frame that first drew it, which on a seam crossing
-- is the whole next tileset at once -- the hitch a player feels stepping
-- from one route onto the next.
--
-- This runs the stream's step() in the time the frame pacer would have
-- slept, after the GC budget has had its half-millisecond, and only when a
-- service has a job queued.  The slice is the smaller of the idle time left
-- before the deadline and a per-tier cap (Performance.CAPS.streamIdleSeconds:
-- HIGH spends up to 6 ms of a frame it was not using anyway, LOW 2 ms, so a
-- handheld keeps its sleep).  With nothing queued the cost is one table walk.
--
-- Nothing here loads the Gen 3 modules: the stream is looked up in
-- package.loaded, so a Gen 1/2/4 session that never required it pays
-- nothing.  Performance.idleStream = false turns the pump off and every
-- build is synchronous again, exactly as before.

local IdleStream = {}

-- below this there is not enough slice to be worth entering a coroutine
IdleStream.MIN_SECONDS = 0.0004
-- what the pacer keeps for itself so the pump cannot push a frame late
IdleStream.MARGIN_SECONDS = 0.0003
-- worker results delivered per frame at most (each runs a callback that
-- usually uploads something)
IdleStream.RESULTS_PER_FRAME = 4

local function cap()
  local ok, Performance = pcall(require, "src.core.Performance")
  if not ok or type(Performance) ~= "table" then return 0.002 end
  if Performance.idleStream == false then return 0 end
  local seconds = Performance.extraCap and Performance.extraCap("streamIdleSeconds")
  return tonumber(seconds) or 0.002
end
IdleStream.cap = cap

-- the Gen 3 stream, looked up and never loaded
local function stream()
  return package.loaded["src.core.game3.asset_stream"]
end

-- G9: ANY OTHER SERVICE WITH WORK TO DO AHEAD OF TIME registers here --
-- a Gen 4 ground building the chunk meshes just outside the view, say.
-- A service is { busy = function() -> bool, step = function(seconds) }.
-- Weakly held, so a map renderer that is dropped takes its service with
-- it and nobody has to remember to unregister.
local services = setmetatable({}, { __mode = "k" })

function IdleStream.register(service)
  if type(service) == "table" and service.busy and service.step then
    services[service] = true
  end
  return service
end

function IdleStream.unregister(service)
  services[service] = nil
end

function IdleStream.busy()
  local S = stream()
  if S ~= nil and S.busy ~= nil and S.busy() then return true end
  for service in pairs(services) do
    if service.busy() then return true end
  end
  return false
end

-- Spend up to `seconds` of idle time on queued builds.  Returns the slice
-- actually offered (0 when nothing was queued or the slice was too small).
function IdleStream.run(timer, deadline)
  -- W1: finished worker results first -- one channel pop when there are
  -- none, and a bounded number of callbacks when there are
  local Workers = package.loaded["src.core.BuildWorker"]
  if Workers and Workers.poll then Workers.poll(IdleStream.RESULTS_PER_FRAME) end
  local limit = cap()
  if limit <= 0 then return 0 end
  local now = timer.getTime()
  local slice = deadline - now - IdleStream.MARGIN_SECONDS
  if slice > limit then slice = limit end
  if slice < IdleStream.MIN_SECONDS then return 0 end
  local S = stream()
  local offered = 0
  if S and S.busy and S.busy() then
    S.update(slice)
    offered = slice
  end
  -- the registered services share what is left, each told the time it has
  for service in pairs(services) do
    local left = deadline - timer.getTime() - IdleStream.MARGIN_SECONDS
    if left < IdleStream.MIN_SECONDS then break end
    if left > limit then left = limit end
    if service.busy() then
      service.step(left)
      offered = offered + left
    end
  end
  return offered
end

-- the pacer's idle hook: the GC budget first (it is tiny and bounded),
-- then whatever is left to the stream
function IdleStream.idle(gcIdle)
  return function(timer, deadline)
    if gcIdle then gcIdle(timer, deadline) end
    return IdleStream.run(timer, deadline)
  end
end

return IdleStream
