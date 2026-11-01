-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Emerald owns these palettes, Lotad, player pictures, text and 20-name lists.
local M={ROOT='data/generated/gba/emerald_birch/'}
local labels={'gText_Birch_Welcome','gText_ThisIsAPokemon','gText_Birch_MainSpeech',
  'gText_Birch_AndYouAre','gText_Birch_BoyOrGirl','gText_Birch_WhatsYourName',
  'gText_Birch_SoItsPlayer','gText_Birch_YourePlayer','gText_Birch_AreYouReady',
  'gText_BirchBoy','gText_BirchGirl','gText_Yes','gText_No','sText_NewParagraph'}
M.LABELS=labels
function M.extract(x)
  assert(x.version=='emerald','Native Emerald Birch requires Emerald')
  x:beginStage('Emerald original Birch, Lotad and player naming')
  local load=require('compat.gen1-rs.Loader').new('emerald')
  local K=load('src.import.gba.rse.boot_gfx');local S=load('src.import.gba.syms').of('emerald')
  local IR=load('src.core.game3.scripting.text_ir')
  local rom={id='emerald'}
  function rom:get(off)return x.rom:u8(off)end
  function rom:u16(off)return x.rom:u16(off)end
  function rom:u32(off)return x.rom:u32(off)end
  function rom:ptrOffset(value)local off=value-0x08000000;return off>=0 and off<x.rom.size and off or nil end
  function rom:readString(off,size)
    assert(off>=0 and off+size<=x.rom.size,'Emerald Birch resource outside cartridge')
    return x.rom.data:sub(off+1,off+size)
  end
  local Fs=require('src.import.CacheFs')
  local cache={write=function(_,path,bytes)local ok,why=Fs.write(path,bytes);assert(ok,why);return true end}
  local c=K.context(rom,cache,{},'emerald_birch')
  local V={BUILD='emerald',SYMS=S,sym=function(name)return assert(S.off(name))end,
    count=function(name,stride)return S.count(name,stride)end}
  load('src.import.gba.games.emerald.uc')(V)
  V.MESSAGE_BOX_PAL=V.sym('gMessageBox_Pal')
  local chromeLoad=require('compat.gen1-rs.Loader').new('emerald',{
    ['src.import.gba.versions']=V,
    ['src.core.GameVersion']=require('src.import.Gen3EmeraldCreditsAssets').versionBinding()})
  local arrow=chromeLoad('src.import.gba.rse.text_chrome_extract').extractDownArrow(rom,false)
  local arrowPath=c:write('down_arrow.rgba',arrow.rgba)
  local base=c:pal('sBirchSpeechBgPals',32)
  local gradient=c:pal('sBirchSpeechBgGradientPal',16)
  local variants={}
  for state=0,8 do
    local pal={};for i=0,31 do pal[i]=base[i]end
    for i=0,7 do pal[i+1]=gradient[state+i]end
    variants[#variants+1]={name=tostring(state),pal=pal}
  end
  local indices,width,height=K.bakeText(c:lz('sBirchSpeechShadowGfx'),c:lz('sBirchSpeechBgMap'),32,20)
  local bg=c:layer({key='bg',opaque=true,indexMap=true,variants=variants},indices,width,height)
  bg.bg,bg.priority,bg.initialState,bg.backdrop=1,3,8,base[0]
  local pics={birch=c:strip('birch',c:raw('sNewGameBirch_Gfx'),64,64,1,c:pal('sNewGameBirch_Pal',16))}
  local playerPics=assert(x.manifest.introSprites.birch.playerPics)
  for key,id in pairs{brendan=playerPics.boy,may=playerPics.girl}do
    assert(type(id)=='number'and id>=0 and id<93)
    local gfx=c:lzAt(c:ptr(c:off('gTrainerFrontPicTable')+id*8))
    local palette=c:palFrom(c:lzAt(c:ptr(c:off('gTrainerFrontPicPaletteTable')+id*8)),16)
    pics[key]=c:strip(key,gfx,64,64,#gfx/0x800,palette);pics[key].trainerPic=id
  end
  local species=assert(x._pokemon.LOTAD.index)
  local gfx=c:lzAt(c:ptr(c:off('gMonFrontPicTable')+species*8))
  pics.lotad=c:strip('lotad',gfx,64,64,#gfx/0x800,
    c:palFrom(c:lzAt(c:ptr(c:off('gMonPaletteTable')+species*8)),16))
  pics.lotad.species=species
  local function textAt(at)
    local bytes={}
    for n=0,2047 do local b=rom:get(at+n);bytes[#bytes+1]=b;if b==255 then break end end
    assert(bytes[#bytes]==255,'Unterminated Emerald Birch label')
    return IR.decode(bytes,{dialect='rse'})
  end
  local text={};for _,name in ipairs(labels)do text[name]=textAt(S.off(name))end
  local defaults={male={},female={}}
  for gender,symbol in pairs{male='sMalePresetNames',female='sFemalePresetNames'}do
    assert(S.count(symbol,4)==20,'Invalid original Emerald default-name pointer count')
    for n=0,19 do
      defaults[gender][n+1]=IR.toAscii(textAt(c:ptr(S.off(symbol)+n*4))):sub(1,7)
    end
  end
  local windows={}
  for n,key in ipairs{'dialogue','gender','reservedName'}do
    local at=S.off('sNewGameBirchSpeechTextWindows')+(n-1)*8
    windows[key]={left=c:u8(at+1),top=c:u8(at+2),width=c:u8(at+3),height=c:u8(at+4)}
  end
  local manifest=c:finish({screen='emerald_birch',layout='emerald',assetLayout='emerald',
    build='emerald',layers={bg=bg},pics=pics,presetNames=defaults,windows=windows,
    palettes={bg=K.palList(base,0,32),gradient=K.palList(gradient,0,16),gradientSlot=1,gradientColors=8},
    mainMenuPalette=K.palList(c:pal('sMainMenuBgPal',16),0,16)})
  local resources={M.ROOT..'manifest.lua'}
  for _,file in ipairs(manifest.files)do resources[#resources+1]=file end
  -- The common release effect still decodes the selected Emerald cartridge.
  assert(load('src.import.gba.ball_open_extract').run(rom,cache,{cacheRoot='data/generated/gba'}))
  for _,file in ipairs{'manifest.lua','balls.rgba','particles.rgba'}do
    resources[#resources+1]='data/generated/gba/pokemon/battle/ball_open/'..file
  end
  x._constants.gen3EmeraldBirch={format=1,version='emerald',manifest=M.ROOT..'manifest.lua',
    resources=resources,textIR=text,lotadSpecies=species,windows=windows,
    arrow=arrowPath,
    defaultNameCount=20,source='ROM: Emerald Birch/Lotad, original palettes, windows, encoded text and 20 pointer names per gender'}
end
function M.valid(spec)
  if type(spec)~='table'or spec.format~=1 or spec.version~='emerald'
    or spec.manifest~=M.ROOT..'manifest.lua'or type(spec.resources)~='table'or#spec.resources<10
    or type(spec.textIR)~='table'or type(spec.lotadSpecies)~='number'
    or spec.defaultNameCount~=20 or type(spec.windows)~='table'
    or spec.arrow~=M.ROOT..'down_arrow.rgba'then return false end
  local seen={}
  for _,path in ipairs(spec.resources)do
    if type(path)~='string'or path:find('..',1,true)or seen[path]
      or not(path:sub(1,#M.ROOT)==M.ROOT or path:match('^data/generated/gba/pokemon/battle/ball_open/[%w_]+%.[%w]+$'))then return false end
    seen[path]=true
  end
  if not seen[spec.manifest]or not seen[spec.arrow]then return false end
  for _,name in ipairs(labels)do if type(spec.textIR[name])~='table'or#spec.textIR[name]==0 then return false end end
  for key,expected in pairs{dialogue={2,15,27,4},gender={3,5,6,4}}do
    local window=spec.windows[key]
    if type(window)~='table'or window.left~=expected[1]or window.top~=expected[2]
      or window.width~=expected[3]or window.height~=expected[4]then return false end
  end
  return true
end
function M.validManifest(man,spec)
  if not M.valid(spec)or type(man)~='table'or man.format~=1
    or man.game~='emerald'or man.layout~='emerald'or man.build~='emerald'
    or type(man.pics)~='table'or type(man.layers)~='table'
    or type(man.layers.bg)~='table'or type(man.presetNames)~='table'
    or type(man.files)~='table'then return false end
  local resources={};for _,path in ipairs(spec.resources)do resources[path]=true end
  for _,path in ipairs(man.files)do if not resources[path]then return false end end
  for _,key in ipairs{'birch','brendan','may','lotad'}do
    local pic=man.pics[key]
    if type(pic)~='table'or pic.w~=64 or pic.h~=64 or type(pic.frames)~='number'
      or pic.frames<1 or pic.frames%1~=0 or not resources[pic.png]then return false end
  end
  if man.pics.brendan.trainerPic~=91 or man.pics.may.trainerPic~=92
    or man.pics.lotad.species~=spec.lotadSpecies then return false end
  for _,gender in ipairs{'male','female'}do
    local names=man.presetNames[gender]
    if type(names)~='table'or#names~=20 then return false end
    for _,name in ipairs(names)do
      if type(name)~='string'or#name<1 or#name>7 then return false end
    end
  end
  return true
end
function M.missing()
  local Fs=require('src.import.CacheFs')
  local function read(path)
    local raw=Fs.read(path);local f=raw and loadstring(raw,'@'..path)
    if not f then return end
    setfenv(f,{});local ok,value=pcall(f)
    return ok and type(value)=='table'and value or nil
  end
  local spec=(read('data/generated/constants.lua')or{}).gen3EmeraldBirch
  if not M.valid(spec)then return{'<emerald:native-birch-lotad>'}end
  local missing={}
  for _,path in ipairs(spec.resources)do if not Fs.exists(path)then missing[#missing+1]=path end end
  if not M.validManifest(read(spec.manifest),spec)then missing[#missing+1]=spec.manifest end
  return missing
end
return M
