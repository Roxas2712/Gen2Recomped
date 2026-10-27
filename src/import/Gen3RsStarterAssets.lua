-- Native RS rescue starter scene; original script still grants the Pokemon.
local M={}
local LABELS={'gOtherText_BirchInTrouble','gOtherText_DoYouChoosePoke','gOtherText_Poke','OtherText_Yes','OtherText_No'}
function M.extract(x,load,rom,cache)
  x:beginStage('Ruby/Sapphire native starter choice')
  assert(load('src.import.gba.rs.extract_starter').run(rom,cache))
  local S=load('src.import.gba.syms').of(x.version)
  local IR=load('src.core.game3.scripting.text_ir');local words={}
  for _,key in ipairs(LABELS)do
    local bytes={};local at=S.off(key)
    for i=0,2047 do local b=rom:get(at+i);bytes[#bytes+1]=b;if b==255 then break end end
    assert(bytes[#bytes]==255,'Unterminated RS starter text');words[key]=IR.decode(bytes,{dialect='rs'})
  end
  local c=load('src.import.gba.rs.assets').context(rom,cache,nil,'starter_choose')
  local species,pics,required,dex={},{},{},{}
  for _,file in ipairs(load('src.import.gba.rs.extract_starter').REQUIRED)do required[#required+1]='data/generated/gba/'..file end
  for i=0,2 do
    local number=rom:u16(S.off('sStarterMons')+i*2);local id,row
    for key,p in pairs(x._pokemon)do if p.index==number then id,row=key,p;break end end
    assert(id and type(row.category)=='string'and type(row.dex)=='number','Native RS starter species metadata missing')
    local gfx=c:lzAt(c:ptr(S.off('gMonFrontPicTable')+number*8))
    local pic=c:strip('front_'..number,gfx,64,64,#gfx/2048,c:palFrom(c:lzAt(c:ptr(S.off('gMonPaletteTable')+number*8)),16))
    species[i+1]={id=id,index=number,name=row.name,dex=row.dex,category=row.category}
    pics[number]=pic.png;dex[row.dex]={category=row.category};required[#required+1]=pic.png
    assert(x._constants.gen3Starters.species[i+1]==id,'Native RS starter order differs from granting script')
  end
  x._constants.gen3RsStarter={format=1,version=x.version,textIR=words,species=species,pics=pics,dex=dex,
    resources=required,source='ROM: RS bag/grass/ball/hand, animation/affine tables, starter species, portraits and text'}
end
function M.missing(version)
  local Fs=require('src.import.CacheFs');local function read(path)
    local raw=Fs.read(path);local f=raw and loadstring(raw);if not f then return end;setfenv(f,{})
    local ok,r=pcall(f);return ok and type(r)=='table'and r or nil
  end
  local constants=read('data/generated/constants.lua')or {};local s=constants.gen3RsStarter
  if type(s)~='table'or s.format~=1 or s.version~=version or type(s.species)~='table'or #s.species~=3
    or type(s.pics)~='table'or type(s.dex)~='table'or type(s.textIR)~='table'or type(s.resources)~='table'or #s.resources==0 then
    return {'<rs:native-starter-choice>'}
  end
  local missing={};local path='data/generated/gba/starter_choose/manifest.lua';local man=read(path)
  local menu=constants.gen3StartMenu or {}
  if menu.pokedexFlag~='FLAG_G3_0801'or menu.pokenavFlag~='FLAG_G3_0802'or type(menu.nativeGateSource)~='string'then
    missing[#missing+1]='<rs:start-menu-native-row-flags>'
  end
  if not man or man.layout~='rs'or man.game~=version or type(man.files)~='table'or #man.files==0 then missing[#missing+1]=path
  else for _,name in ipairs(man.files)do if type(name)~='string'or not Fs.exists(name)then missing[#missing+1]=tostring(name)end end end
  for _,key in ipairs(LABELS)do if type(s.textIR[key])~='table'or #s.textIR[key]==0 then missing[#missing+1]='<rs:starter-text:'..key..'>'end end
  for _,name in ipairs(s.resources)do if type(name)~='string'or not Fs.exists(name)then missing[#missing+1]=tostring(name)end end
  return missing
end
return M
