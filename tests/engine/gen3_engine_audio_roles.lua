-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local M=require('src.import.Gen3EngineAudioRoles')
local S=require('src.core.SaveSerializer')
local function fixture(edition)
 local kanto=edition=='firered'or edition=='leafgreen';local level=kanto and 257 or 367
 local ids={MUS_LEVEL_UP=level,SE_SAVE=55,SE_FLEE=17,SE_WIN_OPEN=6,SE_SELECT=5,SE_SHOP=95}
 local key=kanto and'gen3FrlgHall'or edition=='emerald'and'gen3EmeraldPresentation'or'gen3RsPresentation'
 local fanfare={index=level,song=('SONG_%03X'):format(level),frames=80}
 local constants={[key]={format=1,version=edition,songIds=ids},gen3Fanfares={fanfares={LEVEL_UP=fanfare}}}
 local audio={songs={},sfx={custom={file='retained.wav'}}}
 for _,index in pairs(ids)do audio.songs[('SONG_%03X'):format(index)]={index=index,header=index+100,tracks={index+200}}end
 return constants,audio,key
end
for _,edition in ipairs{'ruby','sapphire','emerald','firered','leafgreen'}do
 local c,a=fixture(edition);local custom=a.sfx.custom
 local proof=assert(M.bind(edition,c,a));T.eq(proof.edition,edition);T.eq(a.sfx.custom,custom)
 T.eq(a.sfx.Level_Up.m4a,(edition=='firered'or edition=='leafgreen')and 257 or 367,'A Kanto level-up cannot inherit Hoenn numbering')
 T.eq(a.sfx.Level_Up.fanfare,'LEVEL_UP','Native level-up ducks and resumes the music')
 for role,index in pairs{Save=55,Run=17,Start_Menu=6,Select=5,Purchase=95}do
  T.eq(a.sfx[role].m4a,index);T.eq(a.sfx[role].fanfare,nil,'Short effects must not interrupt music')
 end
 for _,change in ipairs{'wrong-edition','wrong-fanfare','wrong-label','missing-effect','empty-program','wrong-index'}do
  local constants,audio,key=fixture(edition)
  if change=='wrong-edition'then constants[key].version='red'
  elseif change=='wrong-fanfare'then constants.gen3Fanfares.fanfares.LEVEL_UP.index=1
  elseif change=='wrong-label'then constants.gen3Fanfares.fanfares.LEVEL_UP.song='SONG_001'
  elseif change=='missing-effect'then constants[key].songIds.SE_SHOP=nil
  elseif change=='empty-program'then audio.songs.SONG_005.tracks={}
  elseif change=='wrong-index'then audio.songs.SONG_005.index=6 end
  local before=S.encode(audio)
  T.eq(M.bind(edition,constants,audio),nil,'Refuse unproven audio: '..change)
  T.eq(S.encode(audio),before,'A failed bind cannot leave half-updated effects')
 end
end
T.finish('Native all-five engine sound roles, cartridge numbering and atomic admission')
