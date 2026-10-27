-- Isolated exact-source FR/LG presentation modules; no host module/RNG writes.
local M = {}
function M.new(bindings)
  local loaded = {}
  local function load(name)
    if bindings[name] then return bindings[name] end
    if loaded[name] then return loaded[name] end
    assert(name:match('^src%.[%w_%.]+$'), 'Invalid FR/LG module: '..tostring(name))
    local chunk = assert(love.filesystem.load('compat/gen1-frlg/reference/'..name:gsub('%.','/')..'.lua'))
    setfenv(chunk, setmetatable({require=load}, {__index=_G}))
    local value = chunk(); loaded[name] = value
    return value
  end
  return load
end
return M
