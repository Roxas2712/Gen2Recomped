-- Readiness for the FR/LG resources that replace generic Gen3 boot views.
local M={}
-- Matching retail ELF sections are verified by verify_frlg_text_symbols.py.
M.TEXT_WINDOWS={
  firered={message=0x41F1C8,sign=0x470B0C,standard=0x471A4C,palette=0x471DEC},
  leafgreen={message=0x41F004,sign=0x4703E8,standard=0x471328,palette=0x4716C8},
}
function M.textMissing(version,Fs)
  local expected=M.TEXT_WINDOWS[version];if not expected then return {}end
  local path='data/generated/font.lua';local raw=Fs.read(path)
  local chunk=raw and loadstring(raw,'@'..path);if chunk then setfenv(chunk,{})end
  local ok,font=false,nil;if chunk then ok,font=pcall(chunk)end
  if not ok or type(font)~='table'then return {path}end
  local missing={}
  for _,row in ipairs({
    {'dialogueFrame',string.format('ROM:gfx %07X, gTextWindowPalettes[0] %07X',expected.message,expected.palette)},
    {'signpostFrame',string.format('ROM:gfx %07X, gTextWindowPalettes[1] %07X',expected.sign,expected.palette+32)},
    {'standardFrame',string.format('ROM:gStdTextWindow_Gfx %07X, gTextWindowPalettes[3] %07X',expected.standard,expected.palette+96)},
  })do
    local frame=font[row[1]]
    if type(frame)~='table'or frame.source~=row[2]or type(frame.fill)~='table'
       or frame.fill[1]~=1 or frame.fill[2]~=1 or frame.fill[3]~=1 then
      missing[#missing+1]='<frlg:edition-text-window-'..row[1]..'>'
    elseif type(frame.image)~='string'or not Fs.exists(frame.image)then
      missing[#missing+1]='<frlg:text-window-image-'..row[1]..'>'
    end
  end
  return missing
end
M.IMAGES={
  gen3FRLGIntro={'gfBg','gfArt','gfText','star','sparkleSmall','sparkleBig','presents',
    'scene1Grass','scene1Bg','scene2Bg','scene2Plants','scene2GengarClose','scene2NidorinoClose',
    'scene2Gengar','scene2Nidorino','scene3Bg','scene3GengarBounce','scene3GengarBack','scene3Nidorino',
    'scene3Grass','scene3Swipe','scene3Dust','gengarPiece_tl','gengarPiece_tr','gengarPiece_bl','gengarPiece_br',
    'swipeBottom_a','swipeBottom_b'},
  gen3FRLGTitle={'logo','mon','copyright','copyrightBlink','border','flames','copyrightOnly','pressStart','borderNative','flamesNative','slash'},
  gen3FRLGOakSpeech={'guideAButton','guideBButton','guideCursor','dialogueArrow','pikachuBg','guidePage2',
    'guidePage3','oakBg','red','leaf','oak','rival','platform','pikachuBody','pikachuEars','pikachuEyes'},
  gen3FRLGSummary={'page_info','page_skills','page_moves','page_movesInfo','page_egg'},
  gen3FRLGMainMenu={'downArrow'},
}
function M.missing(version)
  if version~='firered'and version~='leafgreen'then return {}end
  local Fs=require('src.import.CacheFs');local missing={}
  for _,name in ipairs(M.textMissing(version,Fs))do missing[#missing+1]=name end
  local path='data/generated/constants.lua';local raw=Fs.read(path)
  local chunk=raw and loadstring(raw,'@'..path);if chunk then setfenv(chunk,{})end
  local ok,c=false,nil;if chunk then ok,c=pcall(chunk)end
  if not ok or type(c)~='table'then return {path}end
  local function image(group,key)
    local row=c[group];local value=type(row)=='table'and type(row.images)=='table'and row.images[key]
    local name=type(value)=='table'and value.path or value
    if type(name)~='string'or not name:match('^assets/generated/')then
      missing[#missing+1]='<frlg:'..group..'.'..key..'>'
    elseif not Fs.exists(name)then missing[#missing+1]=name end
  end
  for group,keys in pairs(M.IMAGES)do for _,key in ipairs(keys)do image(group,key)end end
  if version=='leafgreen'then image('gen3FRLGTitle','streak')end
  local trainers=type(c.gen3TrainerPresentation)=='table'and c.gen3TrainerPresentation or {}
  local classes=type(c.trainerClasses)=='table'and c.trainerClasses or {}
  if trainers.format~=1 or trainers.version~=version or trainers.classCount~=107
    or type(classes[106])~='string'or classes[106]==''then missing[#missing+1]='<frlg:native-trainer-classes>'end
  local menu=type(c.gen3FRLGMainMenu)=='table'and c.gen3FRLGMainMenu or {}
  if menu.format~=1 or menu.version~=version then missing[#missing+1]='<frlg:main-menu-version>'end
  local text=type(menu.text)=='table'and menu.text or {}
  for _,key in ipairs({'continue','newGame','player','time','pokedex','badges'})do
    if type(text[key])~='string'or text[key]==''then missing[#missing+1]='<frlg:main-menu-text-'..key..'>'end
  end
  local bounce=type(menu.bounce)=='table'and menu.bounce or {}
  if type(bounce.frequency)~='number'or type(bounce.multiplier)~='number'or type(bounce.bounceDir)~='number'then
    missing[#missing+1]='<frlg:main-menu-arrow-bounce>'
  end
  local title=type(c.gen3FRLGTitle)=='table'and c.gen3FRLGTitle or {}
  if title.nativeController~='frlg-native-title-v1'then missing[#missing+1]='<frlg:native-title-version>'end
  if title.cry~=(version=='leafgreen'and 'VENUSAUR'or 'CHARIZARD')
    or title.effect~=(version=='leafgreen'and 'leaves'or 'flames')then missing[#missing+1]='<frlg:title-edition>'end
  local oak=type(c.gen3FRLGOakSpeech)=='table'and c.gen3FRLGOakSpeech or {}
  if type(oak.text)~='table'or type(oak.text.welcome)~='string'then missing[#missing+1]='<frlg:oak-text>'end
  local songMeta=type(c.gen3SongNames)=='table'and c.gen3SongNames or {}
  local names=type(songMeta.names)=='table'and songMeta.names or {}
  for id,name in pairs({[321]='GAME_FREAK',[277]='INTRO_FIGHT',[278]='TITLE'})do
    if names[id]~=name then missing[#missing+1]='<frlg:song-'..name..'>'end
  end
  for _,path in ipairs(require('src.import.Gen3FrlgHallAssets').missing(version))do missing[#missing+1]=path end
  table.sort(missing);return missing
end
return M
