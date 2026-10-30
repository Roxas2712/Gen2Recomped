-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Original Emerald list graphics and narrow font from the selected cartridge.
local M={ROOT='data/generated/gba/native_emerald_bag/',FONTS='data/generated/gba/credits_rse/fonts/'}
M.labels={count='gText_xVar1',close='gText_CloseBag',returnTo='gText_ReturnToVar1',
 selected='gText_Var1IsSelected',moveWhere='gText_MoveVar1Where',number='gText_NumberItem_TMBerry',hmNumber='gText_NumberItem_HM'}
M.files={'manifest.lua','bg.png','bg_female.png','indicator.png','indicator_female.png',
 'bag_male.png','bag_female.png','arrows.png','hm.png','select.png','move_info.png','swap.png'}
M.fonts={'latin_narrow_fg.rgba','latin_narrow_shadow.rgba','latin_narrow_widths.lua'}
function M.extract(x)
 if x.version~='emerald'then return end
 local load=require('compat.gen1-rs.Loader').new('emerald',{
  ['src.core.GameVersion']=require('src.core.GameVersion'),__package={loaded={}}})
 local S=load('src.import.gba.syms').of('emerald');local IR=load('src.core.game3.scripting.text_ir')
 local rom={id='emerald'}
 function rom:get(at)return x.rom:u8(at)end
 function rom:u16(at)return x.rom:u16(at)end
 function rom:u32(at)return x.rom:u32(at)end
 function rom:readString(at,n)assert(at>=0 and at+n<=x.rom.size);return x.rom.data:sub(at+1,at+n)end
 local Fs=require('src.import.CacheFs');local cache={write=function(_,p,b)local ok,why=Fs.write(p,b);assert(ok,why);return true end}
 local K=load('src.import.gba.rse.boot_gfx');local c=K.context(rom,cache,{game='emerald'},'native_emerald_bag')
 local function text(at)
  local raw={};for i=0,2047 do local b=x.rom:u8(at+i);raw[#raw+1]=b;if b==255 then break end end
  assert(raw[#raw]==255);return IR.decode(raw,{dialect='rse'})
 end
 local words={};for key,name in pairs(M.labels)do words[key]=text(S.off(name))end
 local returns={};local at=S.off('gBagMenu_ReturnToStrings')
 for i=0,S.size('gBagMenu_ReturnToStrings')/4-1 do returns[i]=text(x.rom:u32(at+i*4)-0x08000000)end
 local gfx,map=c:lz('gBagScreen_Gfx'),c:lz('gBagScreen_GfxTileMap')
 local male=c:pal('gBagScreenMale_Pal',32,nil,0,true)
 local female=c:pal('gBagScreenFemale_Pal',32,nil,0,true)
 local indices,w,h=K.bakeText(gfx,map,30,20)
 local bg=c:layer({key='bg',opaque=true,variants={{name='',pal=male},{name='female',pal=female}}},indices,w,h,male)
 local cells=string.char(0x17,0x10,0x2B,0x10)
 local dots,dw,dh=K.bakeText(gfx,cells,2,1,{linear=true,mapWidth=2})
 local indicator=c:layer({key='indicator',opaque=true,variants={{name='',pal=male},{name='female',pal=female}}},dots,dw,dh,male)
 local bagPalette=c:pal('gBagPalette',16,nil,0,true)
 local sprites={male=c:strip('bag_male',c:lz('gBagMaleTiles'),64,64,6,bagPalette),
  female=c:strip('bag_female',c:lz('gBagFemaleTiles'),64,64,6,bagPalette),
  arrows=c:strip('arrows',c:lz('list_menu.o:sScrollIndicator_Gfx'),16,16,2,c:pal('sRedInterface_Pal',16)),
  swap=c:strip('swap',c:lz('gSwapLineGfx'),16,16,2,c:pal('gSwapLinePal',16,nil,0,true))}
 local palette={};for i=0,15 do palette[i]=male[16+i]end
 c:png('hm.png',16,16,K.bakeSprite(c:raw('gBagMenuHMIcon_Gfx'),16,16,0,4),palette,true)
 c:png('select.png',24,16,K.bakeSprite(c:raw('sRegisteredSelect_Gfx'),24,16,0,4),palette,true)
 local infoPalette=c:pal('gMenuInfoElements2_Pal',16)
 local infoPath=c:png('move_info.png',128,128,K.bakeSprite(c:raw('gMenuInfoElements_Gfx'),128,128,0,4),infoPalette,true)
 local infoBytes=c:raw('sMenuInfoIcons');local infoRects={}
 for offset=1,#infoBytes,4 do
  local width,height,lo,hi=infoBytes:byte(offset,offset+3);local tile=lo+hi*256
  infoRects[#infoRects+1]={x=tile%16*8,y=math.floor(tile/16)*8,w=width,h=height}
 end
 c:finish({game='emerald',format=1,background=bg,indicator=indicator,sprites=sprites,
  palettes={male=K.palList(male,0,32),female=K.palList(female,0,32)},textIR=words,returnToIR=returns,
  moveInfo={image=infoPath,rects=infoRects,palette=K.palList(infoPalette,0,16)}})
 local V={BUILD='emerald',FONTS={narrow={glyphs=S.off('gFontNarrowLatinGlyphs'),widths=S.off('gFontNarrowLatinGlyphWidths')}},
  FONT_GLYPH_COUNTS={narrow=S.count('gFontNarrowLatinGlyphs',64)}}
 assert(V.FONT_GLYPH_COUNTS.narrow==512)
 local fonts=require('compat.gen1-rs.Loader').new('emerald',{['src.import.gba.versions']=V})
 local font=fonts('src.import.gba.rse.text_chrome_extract').extractLatin(rom,'narrow')
 local root=assert(x._constants.gen3EmeraldCredits).fonts
 cache:write(root..M.fonts[1],font.fgRgba);cache:write(root..M.fonts[2],font.shRgba)
 cache:write(root..M.fonts[3],require('src.import.LuaWriter').encode(font.widths))
 local resources={};for _,p in ipairs(M.files)do resources[#resources+1]=M.ROOT..p end
 for _,p in ipairs(M.fonts)do resources[#resources+1]=root..p end
 x._constants.gen3EmeraldBag={format=1,version='emerald',manifest=M.ROOT..'manifest.lua',resources=resources}
 x:write('constants',x._constants)
end
function M.valid(s,v)
 if not(v=='emerald'and type(s)=='table'and s.format==1 and s.version==v
  and s.manifest==M.ROOT..'manifest.lua'and type(s.resources)=='table'and#s.resources==#M.files+#M.fonts)then return false end
 local i=0
 for _,name in ipairs(M.files)do i=i+1;if s.resources[i]~=M.ROOT..name then return false end end
 for _,name in ipairs(M.fonts)do i=i+1;if s.resources[i]~=M.FONTS..name then return false end end
 return true
end
function M.missing(v)
 if v~='emerald'then return{}end
 local Fs=require('src.import.CacheFs')
 local function readLua(path)
  local raw=Fs.read(path);local f=raw and loadstring(raw)
  if not f then return end;setfenv(f,{})
  local ok,value=pcall(f);if ok and type(value)=='table'then return value end
 end
 local c=readLua('data/generated/constants.lua');local s=c and c.gen3EmeraldBag
 if M.valid(s,v)then
  local manifest=readLua(s.manifest)
  local ready=manifest and manifest.game==v and manifest.format==1
  for _,path in ipairs(s.resources)do
   local bytes=Fs.read(path)
   if type(bytes)~='string'or#bytes==0 then ready=false end
  end
  for _,name in ipairs({'latin_narrow_fg.rgba','latin_narrow_shadow.rgba'})do
   local bytes=Fs.read(M.FONTS..name)
   if type(bytes)~='string'or#bytes~=512*16*16*4 then ready=false end
  end
  local widths=readLua(M.FONTS..'latin_narrow_widths.lua')
  if not widths then ready=false
  else for i=0,511 do
   if type(widths[i])~='number'or widths[i]<0 or widths[i]>16 then ready=false;break end
  end end
  if ready then return{}end
 end
 return{'<emerald:native-bag-list>'}
end
return M
