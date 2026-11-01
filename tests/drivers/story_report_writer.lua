-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Keep a complete, atomically published JSON report without encoding its
-- committed command history again for every ordinary input.
local Writer = {}
Writer.__index = Writer
local PREFIX = '{"commands":['

function Writer.new(path, encode)
  assert(type(path) == 'string' and type(encode) == 'function')
  local previous = io.open(path, 'rb')
  if previous then previous:close(); error('Story report needs a fresh output path') end
  return setmetatable({path=path, encode=encode, count=0,
    offset=#PREFIX, initialized=false}, Writer)
end

function Writer:write(report)
  assert(type(report) == 'table' and type(report.commands) == 'table')
  local count = #report.commands
  assert(count >= self.count, 'Committed story commands cannot be removed')
  local metadata = {}
  for key, value in pairs(report) do
    if key ~= 'commands' then metadata[key] = value end
  end
  local suffix = ']}'
  if next(metadata) then
    local encoded = self.encode(metadata)
    assert(type(encoded) == 'string' and encoded:sub(1,1) == '{')
    suffix = '],' .. encoded:sub(2)
  end
  local source, target, offset
  local temporary = self.path .. '.tmp'
  local ok, why = pcall(function()
    target = assert(io.open(temporary, 'wb'))
    if self.initialized then
      source = assert(io.open(self.path, 'rb'))
      local remaining = self.offset
      while remaining > 0 do
        local chunk = assert(source:read(math.min(65536, remaining)),
          'Committed story prefix is incomplete')
        assert(#chunk > 0, 'Committed story prefix is incomplete')
        assert(target:write(chunk)); remaining = remaining - #chunk
      end
      assert(source:close()); source = nil
    else
      assert(target:write(PREFIX))
    end
    for index = self.count + 1, count do
      local row = report.commands[index]
      assert(type(row) == 'table' and row.seq == index,
        'Story command sequence is not contiguous')
      if index > 1 then assert(target:write(',')) end
      assert(target:write(self.encode(row)))
    end
    offset = assert(target:seek())
    assert(target:write(suffix))
    assert(target:close()); target = nil
    assert(os.rename(temporary, self.path))
  end)
  if source then pcall(source.close, source) end
  if target then pcall(target.close, target) end
  if not ok then error(why, 0) end
  -- Advance only after the new complete JSON file has been published.
  self.offset, self.count, self.initialized = offset, count, true
end

return Writer
