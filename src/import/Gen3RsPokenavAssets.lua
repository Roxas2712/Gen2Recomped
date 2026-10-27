-- Native RS navigation resources; these editions have Trainer's Eyes,
-- rather than Emerald's Match Call menu and event flags.
local M={}
local SUBS={'pokenav','pokenav_shell','pokenav_detail','pokenav_condition','pokenav_ribbons','pokenav_markings'}
function M.extract(x,load,rom,cache)
  x:beginStage('Ruby/Sapphire native PokeNav')
  local A=load('src.import.gba.rs.assets')
  A.text=function(_,off)return x:readText(off)end
  for _,suffix in ipairs({'','_shell','_detail','_condition','_ribbons'})do
    assert(load('src.import.gba.rs.extract_pokenav'..suffix).run(rom,cache))
  end
  -- pokenav.c declares this palette as u8[]. Its [2], [16], [30]
  -- LoadPalette operands are BYTE offsets, not 16-bit colour indices.
  -- Preserve the pinned extractor and correct only these three metadata
  -- slots to the exact two-byte reads made by the cartridge.
  local path='data/generated/gba/rse/pokenav_condition/manifest.lua'
  local f=assert(loadstring(assert(require('src.import.CacheFs').read(path))));setfenv(f,{})
  local man=f();local S=load('src.import.gba.syms').of(x.version)
  local pal=S.off('gPokenavConditionMenu2_Pal')
  for index,offset in pairs({[177]=2,[181]=16,[191]=30})do
    man.palettes.condition[index+1]=rom:u16(pal+offset)
  end
  man.conditionTextPaletteSource='ROM:u8 gPokenavConditionMenu2_Pal +2/+16/+30 bytes'
  cache:write(path,require('src.import.LuaWriter').encode(man))
  local c=A.context(rom,cache,{},'rse/pokenav_markings')
  local at=c:off('gPokenavConditionMenuMisc_Gfx')
  local tiles=c:u8(at)==0x10 and c:lzAt(at)or c:raw('gPokenavConditionMenuMisc_Gfx')
  local gfx=c:write('markings.rom',tiles)
  local palette=c:write('palette.rom',c:raw('gUnknown_08E966B8'))
  assert(A.finish(c,{screen='pokenav_markings',tiles=gfx,palette=palette}))
  x._constants.gen3RsPokenav={version=x.version,format=1,
    source='Native RS PokeNav main/condition/map/Trainers Eyes/ribbons'}
end
function M.missing(version)
  local Fs=require('src.import.CacheFs');local missing={}
  for _,sub in ipairs(SUBS)do
    local path='data/generated/gba/rse/'..sub..'/manifest.lua'
    local raw=Fs.read(path);local f=raw and loadstring(raw,'@'..path)
    if f then setfenv(f,{})end
    local ok,man=false,nil;if f then ok,man=pcall(f)end
    if not ok or type(man)~='table'or man.game~=version or man.assetLayout~='rs'
      or type(man.files)~='table'or #man.files==0
      or (sub=='pokenav_condition'and man.conditionTextPaletteSource~='ROM:u8 gPokenavConditionMenu2_Pal +2/+16/+30 bytes')then missing[#missing+1]=path
    else for _,file in ipairs(man.files)do
      if type(file)~='string'or not Fs.exists(file)then missing[#missing+1]=tostring(file)end
    end end
  end
  return missing
end
return M
