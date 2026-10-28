-- Native RS new-game presentation resources, isolated from the host's data.
local M={}
local ROOT='data/generated/gba/'
local LABELS={'gBirchSpeech_Welcome','gBirchSpeech_ThisIsPokemon','gSystemText_NewPara',
  'gBirchSpeech_WorldInhabitedByPokemon','gBirchSpeech_AndYouAre','gBirchSpeech_AreYouBoyOrGirl',
  'gBirchSpeech_WhatsYourName','gBirchSpeech_SoItsPlayer','gBirchSpeech_AhOkayYouArePlayer',
  'gBirchSpeech_AreYouReady','gBirchText_Boy','gBirchText_Girl'}
function M.extract(x,sourceLoad,rom,cache)
  x:beginStage('Ruby/Sapphire native Birch and naming')
  local S=sourceLoad('src.import.gba.syms').of(x.version)
  local V={BUILD=x.version,SYMS=S,sym=S.off,active=function()return x.version end}
  local load=require('compat.gen1-rs.Loader').new(x.version,{
    ['src.import.gba.versions']=V,
    ['src.core.GameVersion']={get=function()return x.version end},
    ['src.core.game3.constants']={of=function(version)
      assert(version==x.version)
      return {require=function(_,family,key)
        assert(family=='species'and key=='SPECIES_AZURILL')
        return assert(x._pokemon.AZURILL.index)
      end}
    end},
  })
  load('src.import.gba.games.rs.text_chrome')(V)
  load('src.import.gba.games.rs.battle')(V)
  function rom:ptrOffset(ptr)
    local off=ptr-0x08000000
    return off>=0 and off<x.rom.size and off or nil
  end
  assert(load('src.import.gba.rs.extract_birch').run(rom,cache))
  assert(load('src.import.gba.rs.extract_naming').run(rom,cache))
  assert(load('src.import.gba.rs.text_chrome_extract').run(rom,cache))
  assert(load('src.import.gba.ball_open_extract').run(rom,cache,{cacheRoot=ROOT:sub(1,-2)}))
  local IR=load('src.core.game3.scripting.text_ir')
  local function text(off)
    local bytes={}
    for i=0,2047 do
      local b=rom:get(off+i);bytes[#bytes+1]=b
      if b==255 then return IR.decode(bytes,{dialect='rs'})end
    end
    error('Native RS Birch text is unterminated')
  end
  local words={}
  for _,key in ipairs(LABELS)do words[key]=text(S.off(key))end
  local lists={};lists.gMenuYesNoItems={}
  assert(S.count('gMenuYesNoItems',8)==2)
  for i=0,1 do lists.gMenuYesNoItems[i]=text(assert(rom:ptrOffset(rom:u32(S.off('gMenuYesNoItems')+i*8))))end
  local required={}
  for _,file in ipairs(load('src.import.gba.rs.text_chrome_extract').REQUIRED)do required[#required+1]=ROOT..file end
  for _,file in ipairs({'pokemon/battle/ball_open/manifest.lua','pokemon/battle/ball_open/balls.rgba',
    'pokemon/battle/ball_open/particles.rgba'})do required[#required+1]=ROOT..file end
  local icons={};local at=S.off('sRivalAvatarGfxIds')
  for i,key in ipairs({'boy','girl'})do
    local id=rom:get(at+i-1);icons[key]=('SPRITE_G3_%03d'):format(id)
    required[#required+1]=('assets/generated/overworld/g3_%03d.png'):format(id)
  end
  x._constants.gen3RsBirch={version=x.version,format=1,textIR=words,textLists=lists,
    resources=required,azurillSpecies=x._pokemon.AZURILL.index,namingIcons=icons,
    source='ROM: native RS Birch, Azurill, gradients, naming keyboard/templates, text and fonts'}
end
function M.missing(version)
  local Fs=require('src.import.CacheFs');local missing={}
  local function read(path)
    local raw=Fs.read(path);local f=raw and loadstring(raw,'@'..path)
    if not f then return nil end;setfenv(f,{})
    local ok,t=pcall(f);return ok and type(t)=='table'and t or nil
  end
  local c=read('data/generated/constants.lua')or {};local spec=c.gen3RsBirch
  if type(spec)~='table'or spec.format~=1 or spec.version~=version or type(spec.textIR)~='table'
    or type(spec.resources)~='table'or #spec.resources==0
    or type(spec.textLists)~='table'or type(spec.textLists.gMenuYesNoItems)~='table'
    or type(spec.textLists.gMenuYesNoItems[0])~='table'or type(spec.textLists.gMenuYesNoItems[1])~='table'
    or type(spec.namingIcons)~='table'or type(spec.namingIcons.boy)~='string'or type(spec.namingIcons.girl)~='string'
    or type(spec.azurillSpecies)~='number'then
    return {'<rs:native-birch-and-naming>'}
  end
  for _,key in ipairs(LABELS)do
    if type(spec.textIR[key])~='table'or #spec.textIR[key]==0 then missing[#missing+1]='<rs:birch-text:'..key..'>'end
  end
  for _,sub in ipairs({'birch','naming'})do
    local path=ROOT..sub..'/manifest.lua';local m=read(path)
    if not m or m.layout~='rs'or m.game~=version or type(m.files)~='table'or #m.files==0 then missing[#missing+1]=path
    else for _,file in ipairs(m.files)do if type(file)~='string'or not Fs.exists(file)then missing[#missing+1]=tostring(file)end end end
  end
  for _,path in ipairs(spec.resources)do if type(path)~='string'or not Fs.exists(path)then missing[#missing+1]=tostring(path)end end
  return missing
end
return M
