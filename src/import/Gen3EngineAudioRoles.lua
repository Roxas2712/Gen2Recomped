-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Bind host requests to the admitted cartridge's native song identities.
local M={REVISION=1}
local effects={Save='SE_SAVE',Run='SE_FLEE',Start_Menu='SE_WIN_OPEN',Select='SE_SELECT',Purchase='SE_SHOP'}
function M.bind(edition,constants,audio)
 local key=(edition=='ruby'or edition=='sapphire')and'gen3RsPresentation'
   or edition=='emerald'and'gen3EmeraldPresentation'
   or(edition=='firered'or edition=='leafgreen')and'gen3FrlgHall'
 local spec=key and constants and constants[key]
 if type(spec)~='table'or spec.version~=edition or spec.format~=1 or type(spec.songIds)~='table'then
  return nil,'native presentation belongs to another or unavailable cartridge'
 end
 local level=audio and audio.fanfares and audio.fanfares.LEVEL_UP
   or constants.gen3Fanfares and constants.gen3Fanfares.fanfares and constants.gen3Fanfares.fanfares.LEVEL_UP
 if type(level)~='table'or level.index~=spec.songIds.MUS_LEVEL_UP then return nil,'level-up fanfare and native song identities disagree'end
 local pending={};local proof={format=1,edition=edition,roles={}}
 local function add(role,index,fanfare)
  if type(index)~='number'or index<0 or index%1~=0 then return false end
  local label=('SONG_%03X'):format(index);local song=audio and audio.songs and audio.songs[label]
  if type(song)~='table'or song.index~=index or not song.header or type(song.tracks)~='table'or #song.tracks==0 then return false end
  if role=='Level_Up'and level.song~=label then return false end
  pending[role]={m4a=index,song=label,fanfare=fanfare}
  proof.roles[role]={index=index,song=label};return true
 end
 if not add('Level_Up',level.index,'LEVEL_UP')then return nil,'native level-up program is unavailable'end
 for role,symbol in pairs(effects)do
  if not add(role,spec.songIds[symbol])then return nil,'native effect is unavailable: '..symbol end
 end
 audio.sfx=audio.sfx or{}
 for role,definition in pairs(pending)do audio.sfx[role]=definition end
 return proof
end
return M
