-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Read names from the admitted native dataset, never from a second type chart.
local Native = require('src.compat.gen1.NativeSession')
local Ids = require('src.compat.gen1.BattleIds')
local M = {}
local dataset, ids

function M.name(value)
  local game = Native.game()
  local data = game and game.data
  if not data then dataset, ids = nil, nil; return nil end
  if data ~= dataset or not ids:valid() then
    dataset, ids = data, Ids.new(data)
  end
  local key = ids:native('types', value)
  if not key then return nil end
  local chart = data.type_chart and data.type_chart.types
  local catalogue = data.types or data.constants and data.constants.types
  local record = chart and chart[key] or catalogue and catalogue[key]
  local name = record and record.name or key
  local service = package.loaded['src.translation.Service']
  return service and service.name(name) or name
end

local function clear()dataset,ids=nil,nil end
M._service={release=clear,releaseOwner=clear}
require('src.core.game3.asset_stream').register(M._service)
return M
