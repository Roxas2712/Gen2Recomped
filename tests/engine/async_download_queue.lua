package.path = "./?.lua;./?/init.lua;" .. package.path
local checks, ticks, workers, files, queued = 0, 0, {}, {}, {}
local function check(ok, label) checks = checks + 1; assert(ok, label) end
local function channel()
  local q = {}
  function q:push(v) self[#self + 1] = v; if type(v) == "table" and v.stage then queued[v.id] = v end end
  function q:pop() if #self > 0 then return table.remove(self, 1) end end
  function q:peek() return self[1] end
  function q:clear() for i = #self, 1, -1 do self[i] = nil end end
  return q
end
love = {system = {getOS = function() return "Linux" end}, timer = {getTime = function() return ticks end},
  filesystem = {createDirectory = function() return true end, getSaveDirectory = function() return "/owned" end,
    getInfo = function(p) return files[p] and {type = "file", size = #files[p]} end,
    remove = function(p) files[p] = nil; return true end}, thread = {newChannel = channel,
    newThread = function()
      local t = {start = function(self, c, r) self.commands, self.results = c, r end,
        getError = function(self) return self.err end, wait = function() end}
      workers[#workers + 1] = t; return t
    end}}
package.loaded["src.core.HostShell"] = {canSpawnProcess = function() return true end}
local rename = os.rename
local publishes = 0
os.rename = function(from, to)
  from, to = from:sub(8), to:sub(8)
  if to == "blocked" then return nil, "publish refused" end
  check(files[from] ~= nil, "only a completed actual staging file is published")
  files[to], files[from] = files[from], nil; publishes = publishes + 1; return true
end
local D = require("src.net.AsyncDownload")
local function complete(id, body, options)
  local job = queued[id]; check(job ~= nil, "request queued before worker result")
  files[job.stage] = body
  workers[#workers].results:push({id = id, ok = not options or options.ok ~= false,
    bytes = options and options.bytes or #body, err = options and options.err, httpStatus = 200})
end
for _, dest in ipairs({"", "/absolute", "../escape", "x/../escape", "C:\\escape", "x//file", "x/", "net-download/file"}) do
  check(D.download("https://host/file", dest) == nil, "invalid target refused: " .. dest)
end
check(D.download("file:///private", "out") == nil, "only HTTP transport")
check(D.download("http://host/file", "out", {boundedHttpsGet = 1}) == nil, "HTTPS constraint")
check(D.download("https://host/file", "out", {size = 3, maxBytes = 2}) == nil, "contradictory size limit")
check(D.download("https://host/file", "out", {size = .5}) == nil, "fractional size refused")
check(D.download("https://host/file", "out", {maxBytes = math.huge}) == nil, "infinite limit refused")
check(D.download("https://host/file", "out", {userAgent = "bad\r\nheader"}) == nil, "invalid header refused")
files["nested/out"] = "previous"
local id = assert(D.download("https://host/file", "nested/out", {size = 6}))
check(#workers == 2, "fixed file worker ceiling")
check(D.download("https://host/file", "nested\\out") == nil, "one active writer per normalized destination")
check(D.poll(id).status == "pending" and publishes == 0, "poll starts no transfer or publish")
files[queued[id].stage] = "abc"
local progress = D.poll(id)
check(progress.receivedBytes == 3 and progress.progress == .5, "progress reads staging metadata")
check(files["nested/out"] == "previous", "partial file never replaces destination")
complete(id, "abcdef")
local state = D.poll(id)
check(state.status == "ok" and state.receivedBytes == 6 and state.progress == 1, "completed file metadata")
check(files["nested/out"] == "abcdef", "successful atomic replacement")
state.status = "modified"; check(D.poll(id).status == "ok", "detached polling state")
check(D.cancel(id) and files["nested/out"] == "abcdef", "cancel after success cannot remove published file")
D.release(id); check(D.poll(id).status == "error", "released handle invalid")

for _, mode in ipairs({"cancel", "release", "timeout", "size", "reported-size", "transport", "publish"}) do
  local dest = mode == "publish" and "blocked" or "preserved"
  files[dest] = "known good"
  id = assert(D.download("https://host/file", dest, {size = 6, maxSeconds = 1}))
  if mode == "cancel" then D.cancel(id)
  elseif mode == "release" then D.release(id)
  elseif mode == "timeout" then ticks = ticks + 2; check(D.poll(id).status == "error", "queue time counts toward deadline") end
  complete(id, mode == "size" and "short" or "abcdef",
    mode == "transport" and {ok = false, err = "HTTP 404"} or mode == "reported-size" and {bytes = 99} or nil)
  check(D.poll(id).status == "error", mode .. " is terminal error")
  check(files[dest] == "known good", mode .. " preserves previous file")
  check(files[queued[id].stage] == nil, mode .. " retires private partial data")
  D.release(id)
end
id = assert(D.download("https://host/empty", "empty", {size = 0})); complete(id, "")
check(D.poll(id).status == "ok" and files.empty == "", "valid zero-byte HTTP download completes")
D.release(id)
local held = {}
for i = 1, D.MAX_JOBS do held[i] = assert(D.download("https://host/slow", "held" .. i)) end
check(D.download("https://host/slow", "extra") == nil, "bounded active and queued file jobs")
for _, h in ipairs(held) do D.cancel(h); D.release(h) end
check(D.download("https://host/slow", "extra") == nil, "release cannot evade occupied worker budget")
for _, h in ipairs(held) do complete(h, "late") end
id = assert(D.download("https://host/new", "reused"))
check(D.poll(held[1]).status == "error", "late completion never revives released request")
workers[1].err = "worker stopped"
check(D.poll(id).status == "error", "worker death terminates pending file jobs")
D.shutdown()
id = assert(D.download("https://host/new", "restart")); complete(id, "ready")
check(D.poll(id).status == "ok", "file pool restarts after shutdown")
D.release(id); D.shutdown(); os.rename = rename
print(("async file download queue: %d checks PASS"):format(checks))
