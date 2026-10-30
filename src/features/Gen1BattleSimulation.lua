-- Optional source-compatible simulation; native combat remains its own owner.
-- Contributions by Roxas2712. Vendor logic: gen1_gsc/LICENSE.MD.
local Bundle=require('src.features.gen1_gsc.Bundle')
local LuaData=require('src.storage.LuaData')
local M={REVISION=1}
local function copy(value,seen)
  if type(value)~='table'then return value end
  seen=seen or {};if seen[value]then return seen[value]end
  local out={};seen[value]=out;for k,v in pairs(value)do out[k]=copy(v,seen)end;return out
end
function M.new(options)
  options=options or {}
  local input={data=options.data,party=options.party,wild=options.wild,trainer=options.trainer,save=options.save}
  local report=LuaData.inspect(input)
  assert(report.serializable,report.reason)
  assert(type(input.data)=='table'and type(input.data.pokemon)=='table'and type(input.data.moves)=='table',
    'Gen1-shaped battle catalogs are required')
  local detached=copy(input)
  local opts={};for k,v in pairs(options)do opts[k]=v end
  for k,v in pairs(detached)do opts[k]=v end
  local bundle=Bundle.new(options)
  local battle=bundle:require('src.battle.gen2.Battle').new(opts)
  battle.simulationRevision=M.REVISION
  return battle,bundle
end
function M.bundle(options)return Bundle.new(options)end
return M
