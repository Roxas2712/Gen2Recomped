-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Own-cartridge resources for the exact shared FR/LG Hall controller.
local M={ROOT='data/generated/gba/'}
M.LABELS={'gText_Number','gText_Level','gText_IDNumber','gText_Name','gText_MainMenuTime',
  'gText_WelcomeToHOF','gText_SavingDontTurnOffThePower2','gText_EggNickname','gText_LeagueChamp'}
function M.resources()
  local paths={}
  for _,name in ipairs{'manifest.lua','bands.rgba','stripes.rgba','confetti.rgba','egg.rgba'}do paths[#paths+1]=M.ROOT..'hall_of_fame/'..name end
  for _,name in ipairs{'latin_normal_fg.rgba','latin_normal_shadow.rgba','latin_widths.lua',
    'latin_small_fg.rgba','latin_small_shadow.rgba','latin_small_widths.lua'}do paths[#paths+1]=M.ROOT..'chrome/fonts/'..name end
  for _,name in ipairs{'menu_message_rgba.rgba','std_rgba.rgba'}do paths[#paths+1]=M.ROOT..'chrome/'..name end
  for i=0,9 do paths[#paths+1]=M.ROOT..'chrome/user_frame_'..i..'.rgba'end
  return paths
end
function M.extract(x)
  local version=x.version;if version~='firered'and version~='leafgreen'then return end
  x:beginStage('FireRed/LeafGreen original Hall of Fame')
  local GV=require('src.core.GameVersion')
  assert(love.data.encode('string','hex',love.data.hash('sha1',x.rom.data))==GV.info(version).sha1,'FR/LG Hall cartridge mismatch')
  local Loader=require('compat.gen1-rs.Loader')
  local basic=Loader.new(version,{['src.core.GameVersion']=GV,__package={loaded={}}})
  local V=basic('src.import.gba.versions_frlg');V.select(version)
  local load=Loader.new(version,{['src.import.gba.versions']=V,['src.core.GameVersion']=GV,__package={loaded={}}})
  local rom={id=version}
  function rom:get(off)return x.rom:u8(off)end
  function rom:u16(off)return x.rom:u16(off)end
  function rom:u32(off)return x.rom:u32(off)end
  function rom:ptrOffset(value)local at=value-0x08000000;return at>=0 and at<x.rom.size and at or nil end
  local Fs=require('src.import.CacheFs');local Writer=require('src.import.LuaWriter')
  local function put(path,bytes)local ok,why=Fs.write(path,bytes);assert(ok,why);return true end
  -- The pinned league extractor also decodes unrelated diploma/lighting data.
  -- Only this scene's Hall resources enter its cache contract.
  load('src.import.gba.league_extract').run(rom,{write=function(_,path,bytes)
    if path:sub(1,#(M.ROOT..'hall_of_fame/'))==M.ROOT..'hall_of_fame/'then return put(path,bytes)end
    return true
  end})
  local chrome=load('src.import.gba.text_chrome_extract')
  for _,row in ipairs{{'Normal','normal','latin_widths.lua'},{'Small','small','latin_small_widths.lua'}}do
    local font=chrome['extractLatin'..row[1]](rom);assert(font.width==256 and font.height==512)
    put(M.ROOT..'chrome/fonts/latin_'..row[2]..'_fg.rgba',font.fgRgba)
    put(M.ROOT..'chrome/fonts/latin_'..row[2]..'_shadow.rgba',font.shRgba)
    put(M.ROOT..'chrome/fonts/'..row[3],Writer.encode(font.widths))
  end
  put(M.ROOT..'chrome/menu_message_rgba.rgba',chrome.extractMenuMessage(rom).rgba)
  put(M.ROOT..'chrome/std_rgba.rgba',chrome.extractStdFrame(rom).rgba)
  assert(chrome.USER_FRAME_COUNT==10)
  for i=0,9 do put(M.ROOT..'chrome/user_frame_'..i..'.rgba',chrome.extractUserFrame(rom,i).rgba)end
  local Lz=load('src.import.gba.lz77');local Bake=load('src.import.gba.bg_bake')
  local front=assert(x:symbol('gMonFrontPicTable'));local palettes=assert(x:symbol('gMonPaletteTable'))
  local eggAt=assert(rom:ptrOffset(rom:u32(front+412*8)))
  local eggPal=assert(rom:ptrOffset(rom:u32(palettes+412*8)))
  local gfx=Lz.decompress(function(at)return rom:get(at)end,eggAt)
  local pal=Lz.decompress(function(at)return rom:get(at)end,eggPal)
  assert(Bake.byteLen(gfx)==2048 and Bake.byteLen(pal)==32,'Invalid native FR/LG egg portrait')
  put(M.ROOT..'hall_of_fame/egg.rgba',Bake.bakeSpriteRgba(gfx,Bake.loadPalBanks(pal,1)[0],0,64,64,false,false))
  local labels=require('src.import.gba.text_labels.'..version);local IR=load('src.core.game3.scripting.text_ir');local text={}
  for _,name in ipairs(M.LABELS)do
    local at=assert(labels[name],'Missing original FR/LG Hall label '..name);local raw={}
    for i=0,2047 do local b=rom:get(at+i);raw[#raw+1]=b;if b==255 then break end end
    assert(raw[#raw]==255,'Unterminated original FR/LG Hall label '..name);text[name]=IR.decode(raw,{dialect='frlg'})
  end
  local forms=assert(x._field.playerForms)
  local spec={format=1,version=version,resources=M.resources(),textIR=text,
    trainerPics={boy=assert(forms.boy.card),girl=assert(forms.girl.card)},
    songIds=basic('src.core.game3.constants.firered.songs').byName}
  assert(M.valid(spec,version));x._constants.gen3FrlgHall=spec;x:write('constants',x._constants)
end
function M.valid(spec,version)
  if not((version=='firered'or version=='leafgreen')and type(spec)=='table'and spec.format==1 and spec.version==version
    and type(spec.resources)=='table'and#spec.resources==#M.resources()and type(spec.textIR)=='table'
    and type(spec.trainerPics)=='table'and type(spec.trainerPics.boy)=='string'and type(spec.trainerPics.girl)=='string'
    and type(spec.songIds)=='table'and spec.songIds.MUS_HALL_OF_FAME==286 and spec.songIds.SE_APPLAUSE==98)then return false end
  for i,path in ipairs(M.resources())do if spec.resources[i]~=path then return false end end
  for _,key in ipairs(M.LABELS)do if type(spec.textIR[key])~='table'or#spec.textIR[key]==0 then return false end end
  return true
end
function M.missing(version)
  local Fs=require('src.import.CacheFs')
  local function read(path)local raw=Fs.read(path);local f=raw and loadstring(raw,'@'..path)
    if not f then return end;setfenv(f,{});local ok,t=pcall(f);return ok and type(t)=='table'and t or nil end
  local spec=(read('data/generated/constants.lua')or{}).gen3FrlgHall
  if not M.valid(spec,version)then return{'<frlg:native-hall>'}end
  local missing={};for _,path in ipairs(spec.resources)do if not Fs.exists(path)then missing[#missing+1]=path end end
  for _,path in pairs(spec.trainerPics)do if not Fs.exists(path)then missing[#missing+1]=path end end
  local art=read(M.ROOT..'hall_of_fame/manifest.lua')
  if not(art and art.format_version==1 and art.width==240 and art.height==160 and type(art.confetti)=='table'
    and art.confetti.w==8 and art.confetti.h==8 and art.confetti.frames==17)then missing[#missing+1]='<frlg:hall-art>'end
  return missing
end
return M
