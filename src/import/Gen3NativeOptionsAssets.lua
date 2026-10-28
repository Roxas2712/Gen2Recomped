-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Own-cartridge vocabulary and Emerald window/palette metadata for options.
local M={MANIFEST='data/generated/gba/rse/menus/manifest.lua'}
local versions={emerald=true,firered=true,leafgreen=true}
M.rows={
 {'textSpeed','gText_TextSpeed','gText_TextSpeedSlow','gText_TextSpeedMid','gText_TextSpeedFast'},
 {'battleScene','gText_BattleScene','gText_BattleSceneOn','gText_BattleSceneOff'},
 {'battleStyle','gText_BattleStyle','gText_BattleStyleShift','gText_BattleStyleSet'},
 {'sound','gText_Sound','gText_SoundMono','gText_SoundStereo'},
 {'buttonMode','gText_ButtonMode'}, {'frameType','gText_Frame'},
}
function M.labels(version)
 local out={version=='emerald'and'gText_Option'or'gText_MenuOption','gText_OptionMenuCancel','gText_FrameType'}
 for _,row in ipairs(M.rows)do for i=2,#row do out[#out+1]=row[i]end end
 for _,name in ipairs(version=='emerald'and{'gText_ButtonTypeNormal','gText_ButtonTypeLR','gText_ButtonTypeLEqualsA','gText_FrameTypeNumber'}
  or{'gText_ButtonTypeHelp','gText_ButtonTypeLR','gText_ButtonTypeLEqualsA','gText_PickSwitchCancel'})do out[#out+1]=name end
 return out
end
function M.extract(x)
 local version=x.version;if not versions[version]then return end
 x:beginStage('Original edition options')
 local load=require('compat.gen1-rs.Loader').new(version)
 local IR=load('src.core.game3.scripting.text_ir');local S,labels
 if version=='emerald'then S=load('src.import.gba.syms').of(version)
 else labels=require('src.import.gba.text_labels.'..version)end
 local text={}
 for _,name in ipairs(M.labels(version))do
  local at=assert(S and S.off(name)or labels[name],'Missing native option label '..name);local raw={}
  for i=0,2047 do local b=x.rom:u8(at+i);raw[#raw+1]=b;if b==255 then break end end
  assert(raw[#raw]==255,'Unterminated native option label '..name)
  text[name]=IR.decode(raw,{dialect=version=='emerald'and'rse'or'frlg'})
 end
 local arrow
 if version=='emerald'then
  local rom={id=version}
  function rom:get(at)return x.rom:u8(at)end
  function rom:u16(at)return x.rom:u16(at)end
  function rom:u32(at)return x.rom:u32(at)end
  function rom:readString(at,n)assert(at>=0 and at+n<=x.rom.size);return x.rom.data:sub(at+1,at+n)end
  local cache={write=function(_,path,bytes)local ok,why=require('src.import.CacheFs').write(path,bytes);assert(ok,why);return true end}
  assert(load('src.import.gba.rse.menus_extract').run(rom,cache,{game=version}))
  local c=load('src.import.gba.rse.boot_gfx').context(rom,cache,{game=version},'native_options')
  arrow=c:strip('arrows',c:lz('list_menu.o:sScrollIndicator_Gfx'),16,16,2,c:pal('sRedInterface_Pal',16))
 end
 x._constants.gen3NativeOptions={format=1,version=version,textIR=text,frameCount=version=='emerald'and 20 or 10,
  manifest=version=='emerald'and M.MANIFEST or nil,arrow=arrow}
end
function M.valid(spec,version)
 if not(versions[version]and type(spec)=='table'and spec.format==1 and spec.version==version
  and spec.frameCount==(version=='emerald'and 20 or 10)and type(spec.textIR)=='table')then return false end
 if version=='emerald'and not(spec.manifest==M.MANIFEST and type(spec.arrow)=='table'
  and spec.arrow.png=='data/generated/gba/native_options/arrows.png'and spec.arrow.w==16 and spec.arrow.h==16)then return false end
 for _,name in ipairs(M.labels(version))do if type(spec.textIR[name])~='table'or#spec.textIR[name]==0 then return false end end
 return true
end
function M.missing(version)
 if not versions[version]then return{}end
 local Fs=require('src.import.CacheFs')
 local function read(path)local raw=Fs.read(path);local f=raw and loadstring(raw);if not f then return end
  setfenv(f,{});local ok,t=pcall(f);return ok and type(t)=='table'and t or nil end
 local spec=(read('data/generated/constants.lua')or{}).gen3NativeOptions
 if not M.valid(spec,version)then return{'<'..version..':native-options>'}end
 if version=='emerald'then
  if not Fs.exists(spec.arrow.png)then return{spec.arrow.png}end
  local m=read(M.MANIFEST);local o=m and m.option
  if not(m and m.game==version and m.format==1 and type(o)=='table'and type(o.textPalette)=='table'and#o.textPalette==16
   and type(o.bgColor)=='number'and type(o.windows)=='table'and#o.windows==2)then return{M.MANIFEST}end
  for _,w in ipairs(o.windows)do for _,k in ipairs{'left','top','width','height'}do
   if type(w[k])~='number'or w[k]%1~=0 or w[k]<0 then return{M.MANIFEST}end
  end end
 end
 return{}
end
return M
