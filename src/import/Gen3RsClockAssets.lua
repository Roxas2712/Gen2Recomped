-- Original RS clock layers, hand/AM/PM sprites and the confirmation prompt.
local M={};local ROOT='data/generated/gba/wallclock/'
function M.extract(x,load,rom,cache)
  x:beginStage('Ruby/Sapphire native wall clock')
  local reader=load('src.import.gba.rs.extract_wallclock')
  assert(reader.run(rom,cache,{}))
  local resources={ROOT..'manifest.lua'}
  for _,name in ipairs(reader.FILES)do resources[#resources+1]=ROOT..name end
  local S=load('src.import.gba.syms').of(x.version)
  local at=assert(S.off('gOtherText_CorrectTimePrompt'));local bytes={};local ended=false
  for i=0,1023 do
    local b=rom:get(at+i);bytes[#bytes+1]=b
    if b==255 then ended=true;break end
  end
  assert(ended,'Unterminated native RS clock prompt')
  x._constants.gen3RsClock={format=1,version=x.version,resources=resources,
    textIR={gOtherText_CorrectTimePrompt=load('src.core.game3.scripting.text_ir').decode(bytes,{dialect='rs'})},
    source='ROM: native RS wallclock layers, gender palettes, hand coordinates, AM/PM sprites and original prompt'}
end
function M.valid(spec,version)
  return (version=='ruby'or version=='sapphire')and type(spec)=='table'and spec.format==1
    and spec.version==version and type(spec.resources)=='table'and #spec.resources==15
    and type(spec.textIR)=='table'and type(spec.textIR.gOtherText_CorrectTimePrompt)=='table'
end
function M.missing(version)
  local Fs=require('src.import.CacheFs')
  local function read(path)
    local bytes=Fs.read(path);local f=bytes and loadstring(bytes)
    if not f then return end;setfenv(f,{})
    local ok,value=pcall(f);return ok and type(value)=='table'and value or nil
  end
  local spec=(read('data/generated/constants.lua')or{}).gen3RsClock
  if not M.valid(spec,version)then return{'<rs:native-wall-clock>'}end
  local out={}
  for _,path in ipairs(spec.resources)do
    if type(path)~='string'or path:sub(1,#ROOT)~=ROOT or not Fs.exists(path)then out[#out+1]=tostring(path)end
  end
  local man=read(ROOT..'manifest.lua')
  if not man or man.game~=version or man.layout~='rs'or type(man.handCoords)~='table'or #man.handCoords~=360
    or type(man.sprites)~='table'or type(man.layers)~='table'then out[#out+1]=ROOT..'manifest.lua'end
  return out
end
return M
