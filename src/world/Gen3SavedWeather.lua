-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- SetSavedWeather/SetSav1Weather resolves the cycle before committing the
-- saved byte. Only a changed saved RAIN or THUNDERSTORM increments stat40;
-- animation, doweather, map redraw and heavy/abnormal rain do not.
local M={}
local cycles={route119={2,3,5,3},route123={2,2,3,2}}
local function supported(version)
  return version=='ruby'or version=='sapphire'or version=='emerald'
    or version=='firered'or version=='leafgreen'
end
function M.resolve(data,save,value,version)
  version=version or require('src.core.GameVersion').get()
  if not supported(version)then return tonumber(value)end
  value=math.floor(tonumber(value)or 0)%256
  if value<=14 or(value==15 and version=='emerald')then return value end
  local key=value==20 and'route119'or(value==21 and'route123')
  if not key then return 0 end
  local constants=data and data.constants or{}
  local spec=version=='emerald'and constants.gen3EmeraldWeather or constants.gen3RsWeather
  local list=spec and spec.cycles and spec.cycles[key]or cycles[key]
  local stage=math.floor(tonumber(save and save.gen3WeatherStage)or 0)%4
  return list[stage+1]
end
function M.set(save,value,data,version)
  version=version or require('src.core.GameVersion').get()
  local resolved=M.resolve(data,save,value,version)
  if not save then return resolved end
  -- Older host saves can contain an unresolved cycle id. Compare its
  -- current meaning without retroactively counting a weather transition.
  local previous=M.resolve(data,save,save.gen3Weather or 0,version)
  save.gen3Weather=resolved
  if supported(version)and resolved~=previous and(resolved==3 or resolved==5)then
    local stats=require('src.pokemon.Gen3GameStats')
    stats.increment(save,stats.GOT_RAINED_ON)
  end
  return resolved
end
return M
