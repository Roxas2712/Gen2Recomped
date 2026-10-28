-- Native FR/LG trainer identity; stable trainer keys/parties stay with the host.
-- Reference: Gen1Recomp fb7b0366, scripting/trainers.lua and versions_frlg.lua.
local V=require('src.core.GameVersion')
local M={}
local RIVAL={[81]=true,[89]=true,[90]=true}
local MUSIC={[84]='gym',[87]='elite',[90]='final'}
function M.classCount(version)return V.isFRLG(version)and 107 or 67 end
function M.view(trainer,save,version)
  if not(V.isFRLG(version)and RIVAL[tonumber(trainer.class)])then return trainer end
  local name=save and save.player and save.player.rival
  if type(name)~='string'or name==''then return trainer end
  return setmetatable({name=name},{__index=trainer})
end
function M.musicKind(trainer,version)
  return V.isFRLG(version)and MUSIC[tonumber(trainer.class)]or nil
end
return M
