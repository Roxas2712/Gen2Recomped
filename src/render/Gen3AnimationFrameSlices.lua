-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Retain only the currently selected immutable frame for each animation.
-- Placement, cadence, ordering and dirty-tile detection stay with the decoder.
local M = {}

function M.get(cache, index, frame, count)
  local prior = cache[index]
  if prior and prior.frame == frame and prior.count == count then
    return prior.pieces, true
  end
  local pieces = {}
  for tile = 0, count - 1 do
    local offset = tile * 32
    if offset + 32 <= #frame then
      pieces[tile + 1] = frame:sub(offset + 1, offset + 32)
    end
  end
  cache[index] = { frame = frame, count = count, pieces = pieces }
  return pieces, false
end

function M.trim(cache, count)
  for index in pairs(cache) do
    if index > count then cache[index] = nil end
  end
end

local workerMethods={}
for key,value in pairs(M)do workerMethods[key]=value end
function M._workerCompatible()
  if getmetatable(M)~=nil then return false end
  for key,value in pairs(workerMethods)do if M[key]~=value then return false end end
  for key in pairs(M)do if key~='_workerCompatible'and workerMethods[key]==nil then return false end end
  return true
end
return M
