-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Emerald's own tutorial text and uncompressed four-frame Wally back sheet.
local M={REVISION=1,ROOT='data/generated/gba/native_emerald_wally/'}
local SHA1='f3ae088181bf583e55daf962a92bb46f4f1d07b7'
M.labels={
 BattleText_WallyMenu='gText_WhatWillWallyDo',
 BattleText_WallyBall='sText_YouThrowABallNowRight',
 BattleText_ComeBackSingle1='sText_PkmnThatsEnough',
 BattleText_ComeBackSingle2='sText_PkmnComeBack',
 BattleText_ComeBackSingle3='sText_PkmnOkComeBack',
 BattleText_ComeBackSingle4='sText_PkmnGoodComeBack',
 BattleText_TutorialUsed='sText_WallyUsedItem',
 BattleText_BallCaught2='sText_GotchaPkmnCaughtWally',
}
function M.resources()return{M.ROOT..'manifest.lua',M.ROOT..'idle.png',M.ROOT..'strip.png'}end
function M.valid(s,version)
 if version~='emerald'or type(s)~='table'or s.format~=M.REVISION or s.version~=version
  or s.romSha1~=SHA1 or s.dialect~='rse' or s.backIndex~=6
  or s.manifest~=M.ROOT..'manifest.lua' or type(s.images)~='table'
  or s.images.idle~=M.ROOT..'idle.png'or s.images.strip~=M.ROOT..'strip.png'
  or type(s.resources)~='table'or#s.resources~=3 or type(s.textIR)~='table'
  or type(s.anim)~='table'or s.anim.rest~=3 or type(s.anim.throw)~='table'or#s.anim.throw~=5 then return false end
 for i,path in ipairs(M.resources())do if s.resources[i]~=path then return false end end
 for key in pairs(M.labels)do if type(s.textIR[key])~='table'or#s.textIR[key]==0 then return false end end
 for _,frame in ipairs(s.anim.throw)do
  if type(frame)~='table'or type(frame[1])~='number'or frame[1]%1~=0 or frame[1]<0 or frame[1]>3
   or type(frame[2])~='number'or frame[2]%1~=0 or frame[2]<1 then return false end
 end
 return true
end
function M.extract(x)
 if x.version~='emerald'then return end
 x:beginStage('Emerald original Wally tutorial')
 assert(x.manifest.romSha1==SHA1 and require('src.import.RomVerification').sha1(x.rom.data)==SHA1,
  'Unverified Emerald tutorial cartridge')
 local load=require('compat.gen1-rs.Loader').new('emerald')
 local S=load('src.import.gba.syms').of('emerald')
 local IR=load('src.core.game3.scripting.text_ir')
 local rom={id='emerald'}
 function rom:get(at)return x.rom:u8(at)end
 function rom:readString(at,n)assert(at>=0 and at+n<=x.rom.size);return x.rom.data:sub(at+1,at+n)end
 local Fs=require('src.import.CacheFs')
 local cache={write=function(_,p,b)local ok,why=Fs.write(p,b);assert(ok,why);return true end}
 local K=load('src.import.gba.rse.boot_gfx')
 local c=K.context(rom,cache,{game='emerald'},'native_emerald_wally')
 local text={}
 for key,symbol in pairs(M.labels)do
  local at=S.off(symbol);local bytes={}
  for i=0,2047 do assert(at+i<x.rom.size);local b=rom:get(at+i);bytes[#bytes+1]=b;if b==255 then break end end
  assert(bytes[#bytes]==255,'Unterminated Emerald tutorial label '..symbol)
  text[key]=IR.decode(bytes,{dialect='rse',battle=true})
 end
 local native=assert(x._constants.gen3TrainerBack)
 local index=assert(native.named.wally);assert(index==6)
 local at=x.rom:u32(S.off('gTrainerBackPicTable')+index*8)-0x08000000
 assert(at==S.off('gTrainerBackPic_Wally') and S.size('gTrainerBackPic_Wally')==8192)
 local gfx=c:raw('gTrainerBackPic_Wally')
 local pal=c:palFrom(c:lz('gTrainerPalette_Wally'))
 local anim=assert(native.anims[index]);local frames,strip={},{}
 for f=0,3 do
  frames[f]=K.bakeSprite(gfx,64,64,f*64)
  for y=0,63 do for xx=0,63 do strip[y*256+f*64+xx+1]=frames[f][y*64+xx+1]end end
 end
 local images={idle=c:png('idle.png',64,64,assert(frames[anim.rest]),pal,true),
  strip=c:png('strip.png',256,64,strip,pal,true)}
 local record={format=M.REVISION,version='emerald',game='emerald',dialect='rse',romSha1=SHA1,
  backIndex=index,images=images,anim=anim,textIR=text,manifest=M.ROOT..'manifest.lua',resources=M.resources()}
 assert(M.valid(record,'emerald'),'Incomplete original Emerald tutorial')
 c:finish(record);x._constants.gen3EmeraldWally=record;x:write('constants',x._constants)
end
function M.missing(version)
 if version~='emerald'then return{}end
 local Fs=require('src.import.CacheFs')
 local function read(path)
  local raw=Fs.read(path);local f=raw and loadstring(raw);if not f then return end;setfenv(f,{})
  local ok,t=pcall(f);return ok and type(t)=='table'and t or nil
 end
 local c=read('data/generated/constants.lua')or{};local s=c.gen3EmeraldWally
 if not M.valid(s,version)then return{'<emerald:original-wally-tutorial>'}end
 local m=read(s.manifest)
 if not M.valid(m,version)or type(m.files)~='table'or#m.files~=2 then return{'<emerald:wally-manifest>'}end
 local absent={};for _,path in ipairs(M.resources())do if not Fs.exists(path)then absent[#absent+1]=path end end
 return absent
end
return M
