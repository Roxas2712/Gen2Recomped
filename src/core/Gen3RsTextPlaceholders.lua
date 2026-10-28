-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- RS bytes name opposing roles; the selected cartridge supplies their words.
local M={}
local roles={[8]='EVIL_TEAM',[9]='GOOD_TEAM',[10]='EVIL_LEADER',[11]='GOOD_LEADER',
  [12]='EVIL_LEGENDARY',[13]='GOOD_LEGENDARY'}
function M.token(code,version)
  if version=='ruby'or version=='sapphire'then local role=roles[code];return role and'{'..role..'}'end
end
function M.valid(spec,version)
  if(version~='ruby'and version~='sapphire')or type(spec)~='table'or spec.format~=1 or spec.version~=version
    or type(spec.values)~='table'then return false end
  for _,key in ipairs{'UNKNOWN','KUN_MALE','KUN_FEMALE','RIVAL_MALE','RIVAL_FEMALE','VERSION',
    'AQUA','MAGMA','ARCHIE','MAXIE','KYOGRE','GROUDON','EVIL_TEAM','GOOD_TEAM','EVIL_LEADER','GOOD_LEADER','EVIL_LEGENDARY','GOOD_LEGENDARY'}do
    if type(spec.values[key])~='string'then return false end
  end
  return true
end
function M.value(game,key)
  local version=game and game.save and game.save.version or require('src.core.GameVersion').get()
  local spec=game and game.data and game.data.constants and game.data.constants.gen3RsPlaceholders
  if M.valid(spec,version)then return spec.values[key]end
end
function M.gendered(game,key)
  local p=game and game.save and game.save.player or{}
  local female=p.gender=='girl'or p.gender=='female'or p.gender==1 or p.female==true
  return M.value(game,key..(female and'_FEMALE'or'_MALE'))
end
return M
