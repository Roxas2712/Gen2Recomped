-- W1 -- A POOL OF WORKER THREADS FOR THE BUILDS THAT DO NOT NEED THE GPU.
--
-- The port's heavy builds -- a Gen 3 tileset atlas, a Gen 4 chunk's vertex
-- stream, the voxel mod's structure analysis -- are pure Lua over data that
-- can cross a thread boundary (strings, numbers, tables, love Data), with
-- only the last step (newImage, newMesh) needing the main thread.  Until
-- now every one of them ran on the main thread, cooperatively sliced
-- (IdleStream) but never in parallel, on machines with four to sixteen
-- cores doing nothing.
--
-- This is the pool: `submit(kind, key, payload, onDone, onError)` hands a
-- job to a worker, `poll()` -- called from the idle hook every frame --
-- delivers finished results to their callbacks on the main thread.  A
-- handler is a module name registered per kind (`register(kind, module)`);
-- the worker requires it in its own state and calls `run(payload, kind)`.
-- See src/core/build_worker_loop.lua for the worker side and the rules.
--
-- NOTHING USES THIS YET.  It is the foundation for W1a (Gen 3 atlas), W1b
-- (Gen 4 vertex build) and W1c (voxel analysis), each of which stays on
-- its synchronous path when `available()` is false: no love.thread (a
-- headless tool), Performance.buildWorkers = false, or a worker that
-- failed to start.  The pool is sized to the machine (processor count
-- minus one, one to three) and the tier (LOW: one), lazily, on the first
-- submit.

local BuildWorker = {}

BuildWorker.MAX_WORKERS = 3
BuildWorker.JOBS_CHANNEL = "pokeport:build:jobs"
BuildWorker.RESULTS_CHANNEL = "pokeport:build:results"
BuildWorker.SCRIPT = "src/core/build_worker.lua"

local handlers = {}     -- kind -> module name
local threads = nil     -- started workers, or nil before the first submit
local poolTarget
local jobsChannel, resultsChannel
local pending = {}      -- id -> { kind, key, onDone, onError, submittedAt }
local pendingCount = 0
local nextId = 0
local failed = false    -- a worker refused to start: synchronous from then on

local function performance()
  local ok, P = pcall(require, "src.core.Performance")
  return ok and type(P) == "table" and P or nil
end

function BuildWorker.register(kind, module)
  assert(type(kind) == "string" and type(module) == "string", "register(kind, module)")
  handlers[kind] = module
end

function BuildWorker.handlerFor(kind)
  return handlers[kind]
end

-- how many workers this machine and tier get
function BuildWorker.count()
  local P = performance()
  if P and P.tier == "low" then return 1 end
  local cores = 2
  if love and love.system and love.system.getProcessorCount then
    local ok, n = pcall(love.system.getProcessorCount)
    if ok and type(n) == "number" then cores = n end
  end
  local n = cores - 1
  if n < 1 then n = 1 end
  if n > BuildWorker.MAX_WORKERS then n = BuildWorker.MAX_WORKERS end
  return n
end

function BuildWorker.available()
  if failed then return false end
  local P = performance()
  if P and P.buildWorkers == false then return false end
  return love ~= nil and love.thread ~= nil and love.thread.newThread ~= nil
    and love.thread.newChannel ~= nil
end

-- the thread factory, swappable by a check tool
function BuildWorker._spawn(jobs, results)
  local thread = love.thread.newThread(BuildWorker.SCRIPT)
  if thread:start(jobs, results) == false then return nil end
  return thread
end

local function start()
  if not BuildWorker.available() then return false end
  if threads then
    if poolTarget == BuildWorker.count() or pendingCount > 0 then return true end
    -- Apply a changed tier when the pool is idle, without losing callbacks.
    BuildWorker.shutdown()
  end
  if not BuildWorker.available() then return false end
  -- Each pool owns its channels. A restart must never consume an older
  -- pool's queued stop sentinels or let an old worker steal its new jobs.
  jobsChannel = love.thread.newChannel()
  resultsChannel = love.thread.newChannel()
  threads = {}
  local want = BuildWorker.count()
  poolTarget = want
  for i = 1, want do
    local ok, thread = pcall(BuildWorker._spawn, jobsChannel, resultsChannel)
    if ok and thread then threads[#threads + 1] = thread end
  end
  if #threads == 0 then
    threads = nil
    failed = true
    return false
  end
  return true
end

-- Submit a job.  Returns its id, or nil and a reason when the pool cannot
-- take it (then the caller builds synchronously, as it always did).
function BuildWorker.submit(kind, key, payload, onDone, onError)
  local module = handlers[kind]
  if not module then return nil, "no handler for " .. tostring(kind) end
  if not start() then return nil, "no workers" end
  nextId = nextId + 1
  local id = nextId
  pending[id] = { kind = kind, key = key, onDone = onDone, onError = onError }
  pendingCount = pendingCount + 1
  jobsChannel:push({ id = id, kind = kind, module = module, payload = payload })
  return id
end

-- Forget a job: its result, when it comes, is dropped unseen.
function BuildWorker.cancel(id)
  if pending[id] then
    pending[id] = nil
    pendingCount = pendingCount - 1
    return true
  end
  return false
end

function BuildWorker.pending()
  return pendingCount
end

-- Deliver finished results to their callbacks.  Cheap when idle: one
-- channel pop.  `limit` bounds the callbacks run in one call so a burst of
-- results cannot take the frame; the rest wait for the next poll.
function BuildWorker.poll(limit)
  if not resultsChannel then return 0 end
  local delivered = 0
  while limit == nil or delivered < limit do
    local msg = resultsChannel:pop()
    if msg == nil then break end
    local job = type(msg) == "table" and pending[msg.id]
    if job then
      pending[msg.id] = nil
      pendingCount = pendingCount - 1
      delivered = delivered + 1
      if msg.ok then
        if job.onDone then
          local ok, err = pcall(job.onDone, msg.result, job.key)
          if not ok and job.onError then pcall(job.onError, tostring(err), job.key) end
        end
      elseif job.onError then
        pcall(job.onError, msg.error, job.key)
      end
    end
  end
  return delivered
end

-- Stop the workers.  Pending results are dropped; a caller that still
-- needs one builds it synchronously.
function BuildWorker.shutdown()
  if threads and jobsChannel then
    jobsChannel:clear()
    for _ = 1, #threads do jobsChannel:push(false) end
  end
  threads = nil
  poolTarget = nil
  jobsChannel, resultsChannel = nil, nil
  pending = {}
  pendingCount = 0
  failed = false
end

-- for the check tool: how many workers are running
function BuildWorker.running()
  return threads and #threads or 0
end

return BuildWorker
