-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Original Emerald Hall art, text and frames; font belongs to the movie pack.
local M={ROOT='data/generated/gba/hall_of_fame/'}
local names={'gText_Number','gText_Level','gText_IDNumber','gText_Name','gText_Time',
  'gText_WelcomeToHOF','gText_SavingDontTurnOffPower','gText_EggNickname','gText_LeagueChamp','gText_SaveFailed'}
function M.resources()
  local paths={};for _,name in ipairs{'manifest.lua','bands.rgba','stripes.rgba','confetti.rgba'}do paths[#paths+1]=M.ROOT..name end
  for i=0,19 do paths[#paths+1]=M.ROOT..'frame_'..i..'.rgba'end
  paths[#paths+1]=M.ROOT..'message_box.rgba';paths[#paths+1]=M.ROOT..'egg.rgba';paths[#paths+1]=M.ROOT..'emerald.lua';return paths
end
function M.extract(x)
  assert(x.version=='emerald');x:beginStage('Emerald original Hall of Fame')
  local Loader=require('compat.gen1-rs.Loader');local basic=Loader.new('emerald')
  local S=basic('src.import.gba.syms').of('emerald')
  local V={BUILD='emerald',SYMS=S,sym=function(name)return assert(S.off(name),'Missing Emerald Hall symbol '..name)end,
    count=function(name,stride)return assert(S.count(name,stride))end}
  basic('src.import.gba.games.emerald.uc')(V)
  V.TEXT_WINDOW_FRAMES=V.sym('text_window.o:sWindowFrames')
  V.MESSAGE_BOX_GFX=V.sym('gMessageBox_Gfx');V.MESSAGE_BOX_GFX_BYTES=assert(S.size('gMessageBox_Gfx'))
  V.MESSAGE_BOX_PAL=V.sym('gMessageBox_Pal')
  assert(V.count('text_window.o:sWindowFrames',8)==20)
  local load=Loader.new('emerald',{['src.import.gba.versions']=V,
    ['src.core.GameVersion']=require('src.import.Gen3EmeraldCreditsAssets').versionBinding()})
  local rom={id='emerald'}
  function rom:get(off)return x.rom:u8(off)end
  function rom:u16(off)return x.rom:u16(off)end
  function rom:u32(off)return x.rom:u32(off)end
  function rom:ptrOffset(value)local off=value-0x08000000;return off>=0 and off<x.rom.size and off or nil end
  local Fs=require('src.import.CacheFs');local Writer=require('src.import.LuaWriter')
  local cache={write=function(_,path,bytes)local ok,why=Fs.write(path,bytes);assert(ok,why);return true end}
  load('src.import.gba.rse.hall_of_fame_extract').run(rom,cache)
  local resources={};local function resource(name)resources[#resources+1]=M.ROOT..name;return M.ROOT..name end
  for _,name in ipairs{'manifest.lua','bands.rgba','stripes.rgba','confetti.rgba'}do resource(name)end
  local chrome=load('src.import.gba.rse.text_chrome_extract')
  for i=0,19 do cache:write(resource('frame_'..i..'.rgba'),chrome.extractUserFrame(rom,i).rgba)end
  local box=chrome.extractMessageBox(rom);cache:write(resource('message_box.rgba'),box.rgba)
  local Lz=load('src.import.gba.lz77');local Bake=load('src.import.gba.bg_bake')
  local function lz(symbol)return Lz.decompress(function(off)return rom:get(off)end,V.sym(symbol))end
  local egg,palette=lz('gMonFrontPic_Egg'),lz('gMonPalette_Egg')
  assert(Bake.byteLen(egg)>=2048 and Bake.byteLen(palette)==32,'Invalid original Emerald egg image')
  cache:write(resource('egg.rgba'),Bake.bakeSpriteRgba(egg,Bake.loadPalBanks(palette,1)[0],0,64,64,false,false))
  local text={};local IR=load('src.core.game3.scripting.text_ir')
  for _,name in ipairs(names)do
    local at=V.sym(name);local raw={}
    for i=0,2047 do local b=rom:get(at+i);raw[#raw+1]=b;if b==255 then break end end
    assert(raw[#raw]==255,'Unterminated native Emerald Hall text '..name);text[name]=IR.decode(raw,{dialect='rse'})
  end
  local man={format=1,version='emerald',width=240,height=160,confettiFrames=17,
    frames={message_box={width=box.width,height=box.height}},textIR=text}
  cache:write(resource('emerald.lua'),Writer.encode(man))
  local trainers=basic('src.core.game3.constants.emerald.trainer_classes').byName
  local pics={boy=('assets/generated/battle/trainers/%03d.png'):format(assert(trainers.TRAINER_PIC_BRENDAN)),
    girl=('assets/generated/battle/trainers/%03d.png'):format(assert(trainers.TRAINER_PIC_MAY))}
  x._constants.gen3EmeraldHall={format=1,version='emerald',resources=resources,manifest=M.ROOT..'emerald.lua',textIR=text,trainerPics=pics}
end
function M.valid(spec,version)
  if version~='emerald'or type(spec)~='table'or spec.format~=1 or spec.version~='emerald'
    or spec.manifest~=M.ROOT..'emerald.lua'or type(spec.resources)~='table'or#spec.resources~=27
    or type(spec.textIR)~='table'or type(spec.trainerPics)~='table'
    or type(spec.trainerPics.boy)~='string'or type(spec.trainerPics.girl)~='string'then return false end
  for _,name in ipairs(names)do if type(spec.textIR[name])~='table'or#spec.textIR[name]==0 then return false end end
  for i,path in ipairs(M.resources())do if spec.resources[i]~=path then return false end end
  return true
end
function M.missing()
  local Fs=require('src.import.CacheFs')
  local function read(path)
    local raw=Fs.read(path);local f=raw and loadstring(raw,'@'..path);if not f then return end
    setfenv(f,{});local ok,value=pcall(f);return ok and type(value)=='table'and value or nil
  end
  local spec=(read('data/generated/constants.lua')or{}).gen3EmeraldHall
  if not M.valid(spec,'emerald')then return{'<emerald:native-hall>'}end
  local out={};for _,path in ipairs(spec.resources)do if type(path)~='string'or not Fs.exists(path)then out[#out+1]=tostring(path)end end
  for _,path in pairs(spec.trainerPics)do if not Fs.exists(path)then out[#out+1]=path end end
  local m=read(spec.manifest)
  if not m or m.format~=1 or m.version~='emerald'or m.width~=240 or m.height~=160 or m.confettiFrames~=17
    or type(m.frames)~='table'or type(m.frames.message_box)~='table'
    or type(m.frames.message_box.width)~='number'or type(m.frames.message_box.height)~='number'then out[#out+1]=spec.manifest end
  local art=read(M.ROOT..'manifest.lua')
  if not art or art.format_version~=1 or art.width~=240 or art.height~=160 or type(art.confetti)~='table'
    or art.confetti.w~=8 or art.confetti.h~=8 or art.confetti.frames~=17 then out[#out+1]=M.ROOT..'manifest.lua'end
  return out
end
return M
