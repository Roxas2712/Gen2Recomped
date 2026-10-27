-- W1 -- THE WORKER'S HALF OF THE BUILD POOL.
--
-- One function, `serve(jobs, results, limit)`, that pops jobs from a
-- channel, runs the handler module each job names, and pushes the answer
-- back.  It is a module rather than the thread script itself so a headless
-- check can run it in-process against stub channels, one job at a time;
-- src/core/build_worker.lua is the three-line thread script that calls it
-- on the real channels.
--
-- A job is { id, kind, module, payload }.  `module` is required on the
-- worker side (its own Lua state: it must need nothing of love.graphics and
-- nothing the main state built), and its `run(payload, kind)` returns a
-- value the channel can carry back -- strings, numbers, booleans, tables
-- of those, and love Data objects (ByteData, ImageData), which is how a
-- decoded mesh or a built atlas crosses over without a copy.  Anything the
-- handler raises comes back as { id, ok = false, error }.
--
-- `false` on the job channel is the stop sentinel: the loop returns.

local Loop = {}

local function answer(results, id, ok, value)
  if ok then
    results:push({ id = id, ok = true, result = value })
  else
    results:push({ id = id, ok = false, error = tostring(value) })
  end
end

-- Serve jobs until the sentinel (or `limit` jobs, for the check tool).
-- Returns the number of jobs answered.
function Loop.serve(jobs, results, limit)
  local served = 0
  while limit == nil or served < limit do
    local job = jobs:demand()
    if job == false or job == nil then break end
    if type(job) ~= "table" or job.id == nil then
      -- not ours to answer; a malformed push must not wedge the worker
    else
      local ok, value = pcall(function()
        local handler = require(job.module)
        local run = type(handler) == "table" and handler.run or handler
        if type(run) ~= "function" then
          error(("build handler %s has no run()"):format(tostring(job.module)), 0)
        end
        return run(job.payload, job.kind)
      end)
      answer(results, job.id, ok, value)
      served = served + 1
    end
  end
  return served
end

return Loop
