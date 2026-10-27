-- Edition-specific RS storage art and text; no Emerald offsets or labels.
local M={}
local ROOT='data/generated/gba/'
function M.extract(x,load,rom,cache)
  x:beginStage('Ruby/Sapphire native PC storage')
  local A=load('src.import.gba.rs.assets');A.text=function(_,off)return x:readText(off)end
  assert(load('src.import.gba.rs.extract_storage').run(rom,cache))
  local c=A.context(rom,cache,{},'rs/assets');local resources={ROOT..'pokemon/storage/manifest.lua'}
  for _,name in ipairs({'gPSSMenuMisc_Gfx','gPSSMenuMisc_Tilemap'})do
    resources[#resources+1]=c:write('pokemon_storage__'..name..'.bin',c:lz(name))
  end
  resources[#resources+1]=c:write('pokemon_storage__gBoxSelectionPopupPalette.rom',c:raw('gBoxSelectionPopupPalette',32))
  local S=load('src.import.gba.syms').of(x.version)
  local IR=load('src.core.game3.scripting.text_ir');local words={}
  local function text(key)
    local off=S.off(key);local bytes={}
    for i=0,2047 do
      local b=rom:get(off+i);bytes[#bytes+1]=b
      if b==255 then words[key]=IR.decode(bytes,{dialect='rs'});return end
    end
    error('Unterminated native RS storage text '..key)
  end
  for key in load('src.import.gba.syms.'..x.version).data:gmatch('([^ \n]+) %x+ ~?%x+[^\n]*')do
    if key:match('^PCText_')or key:match('^gPCText_')then text(key)end
  end
  text('gText_EggNickname')
  x._constants.gen3RsStorage={version=x.version,format=1,textIR=words,resources=resources,
    source='ROM: native RS 4-option PC, 14x30 storage, 16 wallpapers, sprites and text'}
end
function M.missing(version)
  local Fs=require('src.import.CacheFs');local missing={}
  local function read(path)
    local b=Fs.read(path);local f=b and loadstring(b);if not f then return end;setfenv(f,{})
    local ok,t=pcall(f);return ok and type(t)=='table'and t or nil
  end
  local spec=(read('data/generated/constants.lua')or {}).gen3RsStorage
  local man=read(ROOT..'pokemon/storage/manifest.lua')
  if not spec or spec.version~=version or spec.format~=1 or type(spec.textIR)~='table'
    or not spec.textIR.PCText_WithdrawPoke or not spec.textIR.PCText_LastPoke or type(spec.resources)~='table'or #spec.resources~=4
    or not man or man.game~=version or man.version~=6 or man.assetLayout~='rs'or not man.pcScreenEffect
    or type(man.files)~='table'or #man.files<30 then return {'<rs:native-storage>'}end
  for _,list in ipairs({spec.resources,man.files})do for _,path in ipairs(list)do
    if type(path)~='string'or not Fs.exists(path)then missing[#missing+1]=tostring(path)end
  end end
  return missing
end
return M
