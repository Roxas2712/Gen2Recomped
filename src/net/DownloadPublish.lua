-- Atomic replacement shared by download workers and validated import copies.
-- The caller owns its staging file and supplies the scoped destination.
return function(source, target, deadline)
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
  local from, to = wide(source), wide(target)
  local timer = love.timer
  local now = timer and timer.getTime
  local untilAt = now and math.min(deadline or math.huge, now() + 0.25)
  local attempts, code = 0
  repeat
    if deadline and now and now() >= deadline then return nil, "download publication timed out" end
    if attempts > 0 and untilAt and now() >= untilAt then break end
    attempts = attempts + 1
    if ffi.C.MoveFileExW(from, to, 1) ~= 0 then return true end
    code = tonumber(ffi.C.GetLastError())
    -- Readers (including PhysFS) need not open files with FILE_SHARE_DELETE.
    -- Retry only transient sharing/access conflicts, in the worker, without
    -- removing or truncating the previous complete destination.
    if code ~= 5 and code ~= 32 and code ~= 33 then break end
    if not (untilAt and timer.sleep) or attempts >= 50 or now() >= untilAt then break end
    timer.sleep(math.min(0.005, math.max(0, untilAt - now())))
  until false
  return nil, "download publish failed (Windows " .. code .. ")"
end

