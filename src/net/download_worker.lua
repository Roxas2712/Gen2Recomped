require("love.thread")
require("love.filesystem")
require("love.timer")
require("love.system")
local commands, results, quit = ...
local Transport = require("src.net.DownloadTransport")
while true do
  local job = commands:demand()
  if quit:peek() or job == false then break end
  if type(job) == "table" then
    local output
    local ok, bytes, err, status = pcall(function()
      if job.cancel:peek() then return nil, "cancelled" end
      if love.timer.getTime() >= job.deadline then return nil, "download timed out" end
      local why
      local openFile = love.filesystem.openFile or love.filesystem.newFile
      output, why = openFile(job.stage, "w")
      if not output then return nil, tostring(why or "could not create download staging file") end
      return Transport.run(job, output)
    end)
    if output then
      local closed, result = pcall(output.close, output)
      if not closed or not result then bytes, err = nil, "could not close download staging file" end
    end
    if not ok then err, bytes = tostring(bytes or err), nil end
    love.filesystem.remove(job.stage .. ".cfg")
    love.filesystem.remove(job.stage .. ".stderr")
    if bytes == nil or job.cancel:peek() then
      love.filesystem.remove(job.stage)
      results:push({id = job.id, ok = false, err = err or "cancelled", httpStatus = status})
    else
      results:push({id = job.id, ok = true, bytes = bytes, httpStatus = status})
    end
  end
end
