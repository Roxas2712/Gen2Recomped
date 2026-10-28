-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Native Emerald credits and their font, isolated from field UI resources.
local M={PAGE_COUNT=57,MON_SLIDES=71};local ROOT='data/generated/gba/credits_rse/'
local files={'manifest.lua','the_end.rgba','the_end_blank.rgba','grass.rgba',
  'fonts/latin_normal_fg.rgba','fonts/latin_normal_shadow.rgba','fonts/latin_widths.lua',
  'fonts/metrics.lua','fonts/palette.lua'}
local function read(path)
  local raw=require('src.import.CacheFs').read(path);local f=raw and loadstring(raw,'@'..path)
  if not f then return end;setfenv(f,{})
  local ok,t=pcall(f);return ok and type(t)=='table'and t or nil
end
function M.extract(x)
  assert(x.version=='emerald');x:beginStage('Emerald original cycling credits and THE END')
  local Loader=require('compat.gen1-rs.Loader');local basic=Loader.new('emerald')
  local S=basic('src.import.gba.syms').of('emerald')
  local V={BUILD='emerald',SYMS=S,sym=function(name)return assert(S.off(name),'Missing Emerald credit symbol '..name)end,
    count=function(name,stride)return assert(S.count(name,stride))end}
  basic('src.import.gba.games.emerald.uc')(V)
  assert(V.CREDITS_RSE.pageCount==M.PAGE_COUNT)
  local load=Loader.new('emerald',{['src.import.gba.versions']=V})
  local rom={id='emerald'}
  function rom:get(off)return x.rom:u8(off)end
  function rom:u16(off)return x.rom:u16(off)end
  function rom:u32(off)return x.rom:u32(off)end
  function rom:ptrOffset(value)
    local off=value-0x08000000;return off>=0 and off<x.rom.size and off or nil
  end
  local cache={write=function(_,path,bytes)
    local ok,why=require('src.import.CacheFs').write(path,bytes);assert(ok,why);return true
  end}
  assert(load('src.import.gba.rse.credits_extract').run(rom,cache,{game='emerald'}))
  local man=assert(read(ROOT..'manifest.lua'));man.game='emerald';man.assetLayout='emerald';man.numMonSlides=M.MON_SLIDES
  assert(M.manifestValid(man))
  local Writer=require('src.import.LuaWriter');cache:write(ROOT..'manifest.lua',Writer.encode(man))
  -- fonts.c: the source normal face contains 512 four-tile Latin glyphs.
  local stem='gFontNormalLatin'
  V.FONTS={normal={glyphs=V.sym(stem..'Glyphs'),widths=V.sym(stem..'GlyphWidths')}}
  V.FONT_GLYPH_COUNTS={normal=S.count(stem..'Glyphs',64)}
  assert(V.FONT_GLYPH_COUNTS.normal==512 and S.size(stem..'GlyphWidths')==512)
  local font=load('src.import.gba.rse.text_chrome_extract').extractLatin(rom,'normal')
  assert(font.width==256 and font.height==512)
  cache:write(ROOT..'fonts/latin_normal_fg.rgba',font.fgRgba)
  cache:write(ROOT..'fonts/latin_normal_shadow.rgba',font.shRgba)
  cache:write(ROOT..'fonts/latin_widths.lua',Writer.encode(font.widths))
  local metrics=load('src.import.gba.rse.text_chrome_extract').extractFontMetrics(rom)
  cache:write(ROOT..'fonts/metrics.lua',Writer.encode(metrics))
  local palette={};local Bake=load('src.import.gba.bg_bake')
  for i=0,15 do
    local r,g,b=Bake.bgr555ToRgb8(rom:u16(V.sym('gMessageBox_Pal')+i*2));palette[i]={r,g,b}
  end
  cache:write(ROOT..'fonts/palette.lua',Writer.encode(palette))
  local resources={};for _,path in ipairs(files)do resources[#resources+1]=ROOT..path end
  x._constants.gen3EmeraldCredits={format=1,version='emerald',pageCount=M.PAGE_COUNT,numMonSlides=M.MON_SLIDES,
    resources=resources,fonts=ROOT..'fonts/',source='ROM: original Emerald credits, cycling scenery, 71 slides, THE END and Latin font'}
end
function M.valid(spec,version)
  return version=='emerald'and type(spec)=='table'and spec.format==1 and spec.version=='emerald'
    and spec.pageCount==M.PAGE_COUNT and spec.numMonSlides==M.MON_SLIDES and spec.fonts==ROOT..'fonts/'
    and type(spec.resources)=='table'and#spec.resources==#files
end
function M.manifestValid(man)
  if not(type(man)=='table'and man.game=='emerald'and man.assetLayout=='emerald'and man.format_version==1
    and man.pageCount==M.PAGE_COUNT and man.entriesPerPage==5 and man.numMonSlides==M.MON_SLIDES
    and type(man.pages)=='table'and#man.pages==M.PAGE_COUNT and type(man.palette)=='table'and#man.palette==32
    and type(man.animsPlayer)=='table'and#man.animsPlayer>0 and type(man.animsRival)=='table'and#man.animsRival>0
    and type(man.monSpritePos)=='table'and#man.monSpritePos>0
    and man.theEnd=='the_end.rgba'and man.theEndBlank=='the_end_blank.rgba'and man.grass=='grass.rgba')then return false end
  for _,page in ipairs(man.pages)do
    if type(page)~='table'or#page~=5 then return false end
    for _,entry in ipairs(page)do if type(entry)~='table'or type(entry.text)~='string'or type(entry.isTitle)~='boolean'then return false end end
  end
  return true
end
function M.missing()
  local spec=(read('data/generated/constants.lua')or{}).gen3EmeraldCredits
  if not M.valid(spec,'emerald')then return{'<emerald:native-credits>'}end
  local Fs=require('src.import.CacheFs');local out={}
  for i,rel in ipairs(files)do
    local expected=ROOT..rel
    if spec.resources[i]~=expected or not Fs.exists(expected)then out[#out+1]=expected end
  end
  if not M.manifestValid(read(ROOT..'manifest.lua'))then out[#out+1]=ROOT..'manifest.lua'end
  local widths,metrics,palette=read(ROOT..'fonts/latin_widths.lua'),read(ROOT..'fonts/metrics.lua'),read(ROOT..'fonts/palette.lua')
  if not widths or type(widths[0])~='number'or type(widths[511])~='number'then out[#out+1]='<emerald:credits-font-widths>'end
  local normal=false;for _,row in pairs(metrics or{})do if type(row)=='table'and row.name=='FONT_NORMAL'and row.maxLetterHeight==16 then normal=true end end
  if not normal then out[#out+1]='<emerald:credits-font-metrics>'end
  if not palette or type(palette[1])~='table'or type(palette[15])~='table'then out[#out+1]='<emerald:credits-font-palette>'end
  return out
end
return M
