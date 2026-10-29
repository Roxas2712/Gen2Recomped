-- Bounded native file transfers. Contributions by Roxas2712; see NOTICE.md.
local S = { CHUNK_BYTES = 4 * 1024 * 1024 }

local function close(file)
  if not file then return true end
  local ok, result, why = pcall(file.close, file)
  if not ok then return nil, result end
  if not result then return nil, why or 'could not close file' end
  return true
end

local function openRead(fs, path)
  if type(fs.openFile) == 'function' then return fs.openFile(path, 'r') end
  local file, why = fs.newFile(path)
  if not file then return nil, why end
  local ok, err = file:open('r')
  if not ok then close(file); return nil, err end
  return file
end

-- Short reads need not be EOF. Coalesce at most one block, not the file.
local function block(file)
  local parts, size = {}, 0
  while size < S.CHUNK_BYTES do
    local data, detail = file:read(S.CHUNK_BYTES - size)
    if data == nil then
      if detail ~= nil then error(tostring(detail), 0) end
      break
    end
    if type(data) ~= 'string' or #data > S.CHUNK_BYTES - size then
      error('invalid bounded file read', 0)
    end
    if #data == 0 then break end
    parts[#parts + 1], size = data, size + #data
  end
  return #parts == 1 and parts[1] or table.concat(parts)
end

function S.available(fs)
  return type(fs.openFile) == 'function' or type(fs.newFile) == 'function'
end

function S.copy(fs, sink, source, destination)
  -- Old embedders and filesystem doubles retain their original interface.
  if not S.available(fs) or type(sink.openWrite) ~= 'function' then
    local bytes, why = fs.read(source)
    if bytes == nil then return nil, why or ('could not read ' .. source) end
    return sink.write(destination, bytes)
  end
  local input, output
  local ok, why = pcall(function()
    local err
    input, err = openRead(fs, source)
    if not input then error(err or ('could not open ' .. source), 0) end
    output, err = sink.openWrite(destination)
    if not output then error(err or ('could not create ' .. destination), 0) end
    local info = fs.getInfo and fs.getInfo(source)
    local total = 0
    while true do
      local bytes = block(input)
      if #bytes == 0 then break end
      local written, detail = output:write(bytes)
      if not written then error(detail or 'file write failed', 0) end
      total = total + #bytes
    end
    if info and type(info.size) == 'number' and total ~= info.size then
      error('source size changed or file read was incomplete', 0)
    end
  end)
  local readClosed, readWhy = close(input)
  local writeClosed, writeWhy = close(output)
  if not ok then return nil, tostring(why) end
  if not readClosed then return nil, tostring(readWhy) end
  if not writeClosed then return nil, tostring(writeWhy) end
  return true
end

function S.same(fs, left, right)
  if not S.available(fs) then
    local a, b = fs.read(left), fs.read(right)
    return a ~= nil and b ~= nil and a == b
  end
  local a, b
  local ok, equal = pcall(function()
    a = assert(openRead(fs, left))
    b = assert(openRead(fs, right))
    while true do
      local x, y = block(a), block(b)
      if x ~= y then return false end
      if #x == 0 then return true end
    end
  end)
  local ac, bc = close(a), close(b)
  return ok and equal and ac and bc or false
end

return S
