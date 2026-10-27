-- Ruby/Sapphire: pokeruby pokemon_3.c GetMUS_ForBattle and battle scripts.
-- These class numbers belong to RS, not Emerald's expanded class table.
local V=require('src.core.GameVersion')
local M={}
M.effects={Save='SE_SAVE',Run='SE_FLEE',Start_Menu='SE_WIN_OPEN',
  Select='SE_SELECT',Purchase='SE_SHOP'}
M.roles={wild='MUS_VS_WILD',trainer='MUS_VS_TRAINER',gym='MUS_VS_GYM_LEADER',
  final='MUS_VS_CHAMPION',elite='MUS_VS_ELITE_FOUR',rival='MUS_VS_RIVAL',
  aquaMagma='MUS_VS_AQUA_MAGMA',aquaMagmaLeader='MUS_VS_AQUA_MAGMA_LEADER',
  weatherTrio='MUS_VS_KYOGRE_GROUDON',regi='MUS_VS_REGI',
  wildWin='MUS_VICTORY_WILD',trainerWin='MUS_VICTORY_TRAINER',
  gymWin='MUS_VICTORY_GYM_LEADER',finalWin='MUS_VICTORY_LEAGUE',
  aquaMagmaWin='MUS_VICTORY_AQUA_MAGMA'}
local classes={[2]='aquaMagmaLeader',[49]='aquaMagmaLeader',
  [3]='aquaMagma',[4]='aquaMagma',[50]='aquaMagma',[51]='aquaMagma',
  [25]='gym',[32]='final',[24]='elite'}
function M.active(version)
  version=version or V.get();return version=='ruby'or version=='sapphire'
end
function M.trainerKind(trainer)
  local class=tonumber(trainer.class)
  if class==46 then
    local name=trainer.translationSourceName or trainer.name
    return name=='WALLY'and'trainer'or'rival'
  end
  return classes[class]or'trainer'
end
function M.victoryKind(battle)
  if battle.kind~='trainer'then return'wild'end
  local class=tonumber(battle.trainer and battle.trainer.class)
  if class==24 or class==32 then return'final'end
  local kind=classes[class]
  if kind=='aquaMagma'or kind=='aquaMagmaLeader'then return'aquaMagma'end
  return class==25 and'gym'or'trainer'
end
function M.install(audio,labels)
  audio.battle=audio.battle or{}
  for role,name in pairs(M.roles)do audio.battle[role]=assert(labels[name],'Missing RS battle song '..name)end
end
function M.installEffects(audio)
  for role,symbol in pairs(M.effects)do
    local native=assert(audio.sfx[symbol],'Missing RS effect '..symbol)
    audio.sfx[role]={m4a=native.m4a,song=native.song}
  end
end
function M.ready(audio)
  if type(audio)~='table'or type(audio.battle)~='table'or type(audio.songs)~='table'then return false end
  for role,name in pairs(M.roles)do
    local song=audio.songs[audio.battle[role]]
    if type(song)~='table'or song.musName~=name:sub(5)or not song.header or not song.tracks then return false end
  end
  local level=audio.sfx and audio.sfx.Level_Up
  local fanfare=audio.fanfares and audio.fanfares.LEVEL_UP
  if type(level)~='table'or type(fanfare)~='table'or level.fanfare~='LEVEL_UP'
    or level.m4a~=fanfare.index or level.song~=fanfare.song then return false end
  for role,symbol in pairs(M.effects)do
    local effect,native=audio.sfx[role],audio.sfx[symbol]
    if type(effect)~='table'or type(native)~='table'or type(effect.m4a)~='number'
      or effect.m4a~=native.m4a or effect.song~=native.song or effect.fanfare then return false end
  end
  return true
end
return M
