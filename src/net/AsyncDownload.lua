-- File downloads have bounded, engine-owned workers. Poll only drains results,
-- reads file metadata and atomically publishes a completed staging file.
local M = { MAX_JOBS = 8, MAX_BYTES = 512 * 1024 * 1024 }
local jobs, workers, destinations, nextId = {}, {}, {}, 0
local commands, results, quit, directory, ready, failure
local function now() return love.timer.getTime() end

local function replace(source, target)
  if love.system.getOS() ~= "Windows" then return os.rename(source, target) end
  -- Windows rename cannot overwrite an existing file. Never delete the old
  -- destination first: MoveFileExW replaces it in one filesystem operation.
  local ffi = require("ffi")
  ffi.cdef[[
    int MultiByteToWideChar(unsigned int, unsigned long, const char *, int, unsigned short *, int);
    int MoveFileExW(const unsigned short *, const unsigned short *, unsigned long);
    unsigned long GetLastError(void);
  ]]
  local function wide(s)
    local n = ffi.C.MultiByteToWideChar(65001, 8, s, #s, nil, 0)
    if n == 0 then error("invalid UTF-8 download path") end
    local out = ffi.new("unsigned short[?]", n + 1)
    if ffi.C.MultiByteToWideChar(65001, 8, s, #s, out, n) ~= n then error("download path conversion failed") end
    return out
  end
  if ffi.C.MoveFileExW(wide(source), wide(target), 1) == 0 then
    return nil, "download publish failed (Windows " .. tonumber(ffi.C.GetLastError()) .. ")"
  end
  return true
end

local function ensure()
  if ready ~= nil then return ready end
  if not (love and love.thread and love.thread.newThread and love.filesystem and love.timer)
      or not require("src.core.HostShell").canSpawnProcess() then
    ready, failure = false, "background file downloads unavailable"; return false
  end
  commands, results, quit = love.thread.newChannel(), love.thread.newChannel(), love.thread.newChannel()
  directory = "net-download/" .. os.time() .. "-" .. tostring({}):gsub("[^%w]", "")
  local ok, made = pcall(love.filesystem.createDirectory, directory)
  if not ok or not made then ready, failure = false, "could not create download workspace"; return false end
  for _ = 1, 2 do
    local created, thread = pcall(love.thread.newThread, "src/net/download_worker.lua")
    if created and thread and pcall(thread.start, thread, commands, results, quit) then workers[#workers + 1] = thread end
  end
  ready = #workers > 0
  if not ready then failure = "could not start file-download workers" end
  return ready
end

local function retire(job)
  if destinations[job.key] == job.id then destinations[job.key] = nil end
end
local function failed(job, reason)
  if job.cancel then job.cancel:push(true) end
  job.state = {status = "error", err = reason, progress = 0}
  retire(job)
end
local function removeStage(job)
  if job.stage then love.filesystem.remove(job.stage) end
end
local function drain()
  if not results then return end
  while true do
    local response = results:pop()
    if not response then break end
    local job = type(response) == "table" and jobs[response.id]
    if job then
      job.busy = false
      if job.retained and job.state.status == "pending" then
        if now() >= job.deadline then failed(job, "download timed out")
        elseif not response.ok then failed(job, response.err or "download failed")
        else
          local info = love.filesystem.getInfo(job.stage, "file")
          if not info or info.size ~= response.bytes or job.size ~= nil and info.size ~= job.size then
            failed(job, "download size mismatch")
          else
            local base = love.filesystem.getSaveDirectory() .. "/"
            local ok, moved, why = pcall(replace, base .. job.stage, base .. job.dest)
            if not ok or not moved then failed(job, tostring(why or moved or "could not publish download"))
            else
              job.state = {status = "ok", progress = 1, receivedBytes = response.bytes, httpStatus = response.httpStatus}
              retire(job)
            end
          end
        end
        if job.state.status == "error" then job.state.httpStatus = response.httpStatus end
      end
      removeStage(job)
      if not job.retained then jobs[response.id] = nil end
    end
  end
  for _, thread in ipairs(workers) do
    local err = thread:getError()
    if err then
      ready, failure = false, tostring(err)
      quit:push(true); commands:clear()
      for _ = 1, #workers do commands:push(false) end
      for _, job in pairs(jobs) do if job.state.status == "pending" then failed(job, failure) end end
      break
    end
  end
  for _, job in pairs(jobs) do
    if job.state.status == "pending" and now() >= job.deadline then failed(job, "download timed out") end
  end
end

local function path(value)
  if type(value) ~= "string" or #value == 0 or #value > 2048 or value:find("[%z%c:]") then return nil end
  value = value:gsub("\\", "/")
  if value:sub(1, 1) == "/" or value:sub(-1) == "/" or value:find("//", 1, true)
      or value == "net-download" or value:sub(1, 13) == "net-download/" then return nil end
  for part in value:gmatch("[^/]+") do if part == "." or part == ".." then return nil end end
  return value
end
local function number(value, default, maximum)
  if value == nil then return default end
  value = tonumber(value)
  if not value or value ~= value or value < 0 or value > maximum then return nil end
  return value
end

function M.download(url, destination, options)
  options = type(options) == "table" and options or {}
  if type(url) ~= "string" or #url > 8192 or url:find("[%z%c%s]")
      or not url:lower():match("^https?://[^/?#]+") then return nil, "invalid HTTP URL" end
  if options.boundedHttpsGet == 1 and not url:lower():match("^https://") then return nil, "HTTPS required" end
  for _, name in ipairs({"userAgent", "accept"}) do
    local value = options[name]
    if value ~= nil and (type(value) ~= "string" or #value > 1024 or value:find("[%z%c]")) then
      return nil, "invalid HTTP header"
    end
  end
  local dest = path(destination)
  if not dest then return nil, "relative download file path required" end
  local size = number(options.size, nil, M.MAX_BYTES)
  if options.size ~= nil and (size == nil or size % 1 ~= 0) then return nil, "invalid expected size" end
  local limit = number(options.maxBytes, math.max(size or 0, 64 * 1024 * 1024), M.MAX_BYTES)
  local seconds = number(options.maxSeconds, 60, 300)
  if not limit or limit < 1 or limit % 1 ~= 0 or size and size > limit then return nil, "invalid byte limit" end
  if not seconds or seconds < .1 then return nil, "invalid download timeout" end
  drain()
  local busy = 0
  for _, job in pairs(jobs) do if job.busy then busy = busy + 1 end end
  if busy >= M.MAX_JOBS then return nil, "file-download worker queue is full" end
  local key = love and love.system and love.system.getOS and love.system.getOS() == "Windows" and dest:lower() or dest
  if destinations[key] then return nil, "download destination is busy" end
  nextId = nextId + 1
  local id = nextId
  local job = {id = id, dest = dest, key = key, size = size, retained = true,
    state = {status = "pending", progress = 0, receivedBytes = 0}}
  jobs[id] = job
  if not ensure() then failed(job, failure); return id end
  local parent = dest:match("^(.+)/[^/]+$")
  if parent then
    local ok, made = pcall(love.filesystem.createDirectory, parent)
    if not ok or not made then failed(job, "could not create download destination directory"); return id end
  end
  job.stage, job.cancel = directory .. "/" .. id .. ".part", love.thread.newChannel()
  job.deadline, job.busy = now() + seconds, true
  destinations[key] = id
  commands:push({id = id, url = url, stage = job.stage, cancel = job.cancel,
    deadline = job.deadline, maxSeconds = seconds, size = size, maxBytes = limit,
    userAgent = options.userAgent, accept = options.accept, httpsOnly = options.boundedHttpsGet == 1})
  return id
end

function M.poll(id)
  drain()
  local job = jobs[id]
  if not job or not job.retained then return {status = "error", err = "invalid job handle"} end
  local state = {}
  for k, v in pairs(job.state) do state[k] = v end
  if state.status == "pending" and job.stage then
    local info = love.filesystem.getInfo(job.stage, "file")
    state.receivedBytes = info and info.size or 0
    state.progress = job.size and job.size > 0 and math.min(1, state.receivedBytes / job.size) or 0
  end
  return state
end
function M.cancel(id)
  local job = jobs[id]
  if not job or not job.retained then return false end
  if job.state.status == "pending" then failed(job, "cancelled") end
  return true
end
function M.release(id)
  local job = jobs[id]
  if not job then return end
  M.cancel(id); job.retained = false
  if not job.busy then removeStage(job); jobs[id] = nil end
end
function M.shutdown()
  for id in pairs(jobs) do M.cancel(id) end
  if quit then quit:push(true); commands:clear(); for _ = 1, #workers do commands:push(false) end end
  for _, thread in ipairs(workers) do pcall(thread.wait, thread) end
  for _, job in pairs(jobs) do
    job.busy = false; removeStage(job)
    if job.stage then love.filesystem.remove(job.stage .. ".cfg"); love.filesystem.remove(job.stage .. ".stderr") end
  end
  if directory then love.filesystem.remove(directory) end
  workers, destinations = {}, {}
  commands, results, quit, directory, ready, failure = nil, nil, nil, nil, nil, nil
end

return M
