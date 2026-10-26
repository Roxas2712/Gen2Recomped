-- Run:  luajit tools/build_worker_check.lua
--
-- W1 -- THE BUILD POOL, DRIVEN IN-PROCESS.  love.thread is stubbed with
-- plain queues and the worker loop (src/core/build_worker_loop.lua) is
-- stepped by hand, so the whole round trip -- register, submit, serve,
-- poll, callback -- runs under plain LuaJIT with no thread at all.  Then
-- the edges: a handler that throws, a cancelled job, the per-poll limit,
-- a malformed job, the stop sentinel, the pool size by cores and tier,
-- and every way the pool says "not available" so callers build
-- synchronously.
package.path = './?.lua;./?/init.lua;' .. package.path

local PASS, FAIL = 0, 0
local function check(cond, label)
  if cond then PASS = PASS + 1 else FAIL = FAIL + 1; print('FAIL: ' .. label) end
end

-- a channel: push / pop / demand over a queue
local function channel()
  local q, head = {}, 1
  return {
    push = function(_, v) q[#q + 1] = v end,
    pop = function() if head > #q then return nil end local v = q[head]; head = head + 1; return v end,
    demand = function(self) return self:pop() end,
    size = function() return #q - head + 1 end,
    clear = function() q,head={},1 end,
  }
end
local channels = {}
local started = {}
love = {
  thread = {
    newChannel = channel,
    getChannel = function(name) channels[name] = channels[name] or channel(); return channels[name] end,
    newThread = function(script) return { start = function(_, ...) started[#started + 1] = { script, ... } end } end,
  },
  system = { getProcessorCount = function() return 8 end },
}

local Performance = require('src.core.Performance')
local Loop = require('src.core.build_worker_loop')
local BuildWorker = require('src.core.BuildWorker')

-- a handler module the "worker" can require
package.loaded['tests.build_echo'] = {
  run = function(payload, kind)
    if payload == 'boom' then error('handler exploded', 0) end
    return { kind = kind, doubled = payload * 2 }
  end,
}
BuildWorker.register('echo', 'tests.build_echo')
check(BuildWorker.handlerFor('echo') == 'tests.build_echo', 'handler registered')

-- pool size
Performance.tier = 'high'
check(BuildWorker.count() == 3, '8 cores on HIGH: three workers (capped)')
love.system.getProcessorCount = function() return 2 end
check(BuildWorker.count() == 1, '2 cores: one worker')
love.system.getProcessorCount = function() return 4 end
check(BuildWorker.count() == 3, '4 cores: three workers')
Performance.tier = 'low'
check(BuildWorker.count() == 1, 'LOW: one worker whatever the cores')
Performance.tier = 'high'

-- the round trip
local jobs,results
local got, errs = {}, {}
local id = BuildWorker.submit('echo', 'chunk-7', 21,
  function(result, key) got[#got + 1] = { result, key } end,
  function(err, key) errs[#errs + 1] = { err, key } end)
jobs,results=started[1][2],started[1][3]
check(id ~= nil, 'submit returns an id')
check(BuildWorker.running() == 3, 'the first submit started the pool')
check(#started == 3 and started[1][1] == BuildWorker.SCRIPT, 'each worker runs the thread script')
check(BuildWorker.pending() == 1, 'one job pending')
check(BuildWorker.poll() == 0, 'nothing delivered before the worker ran')
check(Loop.serve(jobs, results, 1) == 1, 'the worker served one job')
check(BuildWorker.poll() == 1, 'poll delivered it')
check(#got == 1 and got[1][1].doubled == 42 and got[1][1].kind == 'echo' and got[1][2] == 'chunk-7',
      'the callback got the result and the key')
check(BuildWorker.pending() == 0, 'nothing pending after delivery')
Performance.buildWorkers=false
check(BuildWorker.submit('echo','disabled',1)==nil,'switch off refuses work in an already running pool')
check(BuildWorker.pending()==0,'disabled submission creates no pending callback')
Performance.buildWorkers=true

-- a handler that throws reaches onError
BuildWorker.submit('echo', 'bad', 'boom', function() got[#got + 1] = 'wrong' end,
  function(err, key) errs[#errs + 1] = { err, key } end)
Loop.serve(jobs, results, 1)
BuildWorker.poll()
check(#errs == 1 and errs[1][1] == 'handler exploded' and errs[1][2] == 'bad', 'a throwing handler reaches onError with the key')
check(#got == 1, '...and not onDone')

-- a cancelled job's result is dropped unseen
local cid = BuildWorker.submit('echo', 'gone', 1, function() got[#got + 1] = 'wrong' end)
check(BuildWorker.cancel(cid), 'cancel of a pending job')
check(not BuildWorker.cancel(cid), 'cancel twice is false')
Loop.serve(jobs, results, 1)
check(BuildWorker.poll() == 0, 'a cancelled result delivers nothing')
check(#got == 1, '...and runs no callback')

-- the per-poll limit
for i = 1, 6 do BuildWorker.submit('echo', 'k' .. i, i, function(r) got[#got + 1] = r end) end
Loop.serve(jobs, results, 6)
check(BuildWorker.poll(4) == 4, 'poll(4) delivers four')
check(BuildWorker.poll(4) == 2, '...and the rest next time')
check(#got == 7, 'all six callbacks ran')

-- unknown kind
local nid, why = BuildWorker.submit('nope', 'x', 1)
check(nid == nil and why:find('no handler'), 'an unknown kind is refused with a reason')

-- the worker loop: malformed job ignored, sentinel stops it
jobs:push('garbage'); jobs:push({ id = 99, kind = 'echo', module = 'tests.build_echo', payload = 2 }); jobs:push(false)
check(Loop.serve(jobs, results) == 1, 'serve skipped the garbage, answered one, stopped at the sentinel')
check(results:pop().id == 99, 'the answer carries the id')
-- a handler module without run()
package.loaded['tests.build_norun'] = { }
jobs:push({ id = 100, kind = 'x', module = 'tests.build_norun', payload = 0 }); jobs:push(false)
Loop.serve(jobs, results)
local r = results:pop()
check(r.ok == false and r.error:find('no run'), 'a handler without run() answers an error')

-- shutdown pushes one sentinel per worker
BuildWorker.shutdown()
check(jobs:size() == 3, 'shutdown queued three stop sentinels')
check(BuildWorker.running() == 0 and BuildWorker.pending() == 0, 'shutdown cleared the pool')
local retiredJobs=jobs

-- not available: the switch, no love.thread, a spawn that fails
Performance.buildWorkers = false
check(not BuildWorker.available(), 'buildWorkers=false: not available')
check(BuildWorker.submit('echo', 'k', 1) == nil, '...and submit refuses')
Performance.buildWorkers = true
local realSpawn = BuildWorker._spawn
BuildWorker._spawn = function() error('no threads here') end
check(BuildWorker.submit('echo', 'k', 1) == nil, 'every spawn failing refuses the submit')
check(not BuildWorker.available(), '...and the pool stays unavailable after that')
BuildWorker.shutdown()
BuildWorker._spawn = realSpawn
local thread = love.thread
love.thread = nil
check(not BuildWorker.available(), 'no love.thread: not available')
love.thread = thread

-- IdleStream polls the pool
package.loaded['src.core.game3.asset_stream'] = nil
local IdleStream = require('src.core.IdleStream')
got = {}
BuildWorker.submit('echo', 'idle', 5, function(r) got[#got + 1] = r end)
jobs,results=started[#started][2],started[#started][3]
check(jobs~=retiredJobs,'restarted pool has its own job channel')
check(retiredJobs:size()==3,'old stop sentinels cannot reach the restarted pool')
Loop.serve(jobs, results, 1)
local timer = { getTime = function() return 0 end }
IdleStream.run(timer, 0.0001)   -- too short a slice for any stream work
check(#got == 1 and got[1].doubled == 10, 'IdleStream.run polled the pool even with no slice to spend')
Performance.tier='low'
BuildWorker.submit('echo','low',2,function(r)got[#got+1]=r end)
check(BuildWorker.running()==1,'idle pool adopts LOW on the next submission')
jobs,results=started[#started][2],started[#started][3]
Loop.serve(jobs,results,1);BuildWorker.poll()
check(got[#got].doubled==4,'tier change preserves the submitted callback')
BuildWorker.shutdown()

print(('build_worker_check: %d passed, %d failed'):format(PASS, FAIL))
if FAIL > 0 then os.exit(1) end
