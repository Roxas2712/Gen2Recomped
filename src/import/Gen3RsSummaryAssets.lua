-- Native RS summary layers and text. No Emerald artwork or ROM payloads.
local M={}
local ROOT='data/generated/gba/rse/'
local TEXTS={
  'Accuracy2','Appeal2','Attack','CancelNoTerminator','CantForgetHMs','Comma','Defense',
  'Egg2','EggAbout','EggDayCare','EggHotSprings','EggLongTime','EggNicePlace',
  'EggObtainedInTrade','EggSomeTime','EggSoon','ExpPoints','FatefulEncounter','FemaleSymbol2',
  'Ferry','FiveQuestions','HP','Hideout','Jam2','MaleSymbol2','Met','Met2','Nature','NextLv',
  'None','ObtainedInTrade','OneDash','OriginalTrainer','Power2','Ribbons00','SecretBase',
  'SpAtk','SpDef','Speed','Status','Terminator4','ThreeDashes2','TwoDashes','Type2',
}

function M.extract(extractor,load,rom,cache)
  extractor:beginStage('Ruby/Sapphire native Pokemon summary')
  local A=load('src.import.gba.rs.assets')
  A.text=function(_,off)return extractor:readText(off)end
  assert(load('src.import.gba.rs.extract_summary').run(rom,cache))
  local S=load('src.import.gba.syms').of(extractor.version)
  local text={}
  for _,name in ipairs(TEXTS)do
    local key='gOtherText_'..name
    text[key]=assert(extractor:readText(S.off(key)),'Missing RS summary text '..key)
  end
  local names={}
  assert(S.count('gNatureNames',4)==25,'Native RS nature-name count')
  local c=A.context(rom,cache,{},'rse/summary_extras')
  for i=0,24 do
    names[i+1]=assert(extractor:readText(assert(c:ptr(S.off('gNatureNames')+i*4))))
  end
  local locations={}
  local regionAt=S.off('gRegionMapEntries')
  for i=0,S.count('gRegionMapEntries',8)-1 do
    local ptr=c:ptr(regionAt+i*8+4)
    if ptr then locations[i]=assert(extractor:readText(ptr,32,nil,{rsNameEnd=true}))end
  end
  -- Closed summary ball sprites use the cartridge's own RS tables. The
  -- remaining throw/open/particle animation is a separate battle subsystem.
  local K=load('src.import.gba.rse.boot_gfx')
  local sheets,pals=S.off('pokeball.o:sBallSpriteSheets'),S.off('pokeball.o:sBallSpritePalettes')
  assert(S.count('pokeball.o:sBallSpriteSheets',8)==12 and S.count('pokeball.o:sBallSpritePalettes',8)==12)
  local balls={}
  for i=0,11 do
    assert(c:u16(sheets+i*8+4)==384,'Native RS ball sheet size')
    local gfx=c:lzAt(assert(c:ptr(sheets+i*8)))
    local pal=c:palFrom(c:lzAt(assert(c:ptr(pals+i*8))),16)
    local pixels=K.bakeSprite(gfx,16,16,0,4)
    balls[i+1]=c:png('ball_'..i..'.png',16,16,pixels,pal,true)
  end
  local eggGfx=c:lz('gMonPic_Egg')
  assert(#eggGfx==2048,'Native RS egg picture size')
  local eggPalOff=S.off('gMonPalette_Egg')
  local eggPal=rom:get(eggPalOff)==0x10 and c:pal('gMonPalette_Egg',16,nil,nil,true) or c:pal('gMonPalette_Egg',16)
  local egg=c:png('egg.png',64,64,K.bakeSprite(eggGfx,64,64,0,4),eggPal,true)
  local eggName=assert(extractor:readText(S.off('gText_EggNickname')))
  assert(A.finish(c,{screen='summary_extras',balls=balls,egg=egg,locations=locations,eggName=eggName}))
  extractor._constants.gen3RsSummary={version=extractor.version,format=1,
    summary=ROOT..'summary/manifest.lua',extras=ROOT..'summary_extras/manifest.lua',
    text=text,natureNames=names,locations=locations,eggName=eggName}
end

function M.missing(version)
  local Fs=require('src.import.CacheFs')
  local missing={}
  for _,sub in ipairs({'summary','summary_extras'})do
    local path=ROOT..sub..'/manifest.lua'
    local raw=Fs.read(path);local chunk=raw and loadstring(raw,'@'..path)
    if chunk then setfenv(chunk,{})end
    local ok,m=false,nil;if chunk then ok,m=pcall(chunk)end
    if not ok or type(m)~='table' or m.game~=version or m.layout~='rs'
      or type(m.files)~='table' or #m.files==0
      or (sub=='summary_extras' and (type(m.egg)~='string' or type(m.balls)~='table' or #m.balls~=12
        or type(m.locations)~='table' or type(m.eggName)~='string')) then missing[#missing+1]=path
    else
      for _,file in ipairs(m.files)do
        if type(file)~='string' or not Fs.exists(file)then missing[#missing+1]=tostring(file)end
      end
    end
  end
  return missing
end

return M
