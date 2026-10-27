-- All original RS berry pictures, records, flavor circles and tag layers.
local M={};local ROOT='data/generated/gba/rse/berry_tag/'
function M.extract(x,load,rom,cache)
  x:beginStage('Ruby/Sapphire native berry tags')
  local reader=load('src.import.gba.rs.extract_berry_tag')
  assert(reader.run(rom,cache,{}))
  local resources={ROOT..'manifest.lua'}
  for _,name in ipairs(reader.FILES)do resources[#resources+1]=ROOT..name end
  x._constants.gen3RsBerryTag={format=1,version=x.version,resources=resources,
    source='ROM: native RS43 berries, pictures/palettes, size/firmness/descriptions/flavors, tag layers and original scroll geometry'}
end
function M.valid(spec,version)
  return(version=='ruby'or version=='sapphire')and type(spec)=='table'and spec.format==1
    and spec.version==version and type(spec.resources)=='table'and #spec.resources==49
end
function M.missing(version)
  local Fs=require('src.import.CacheFs')
  local function read(path)
    local bytes=Fs.read(path);local f=bytes and loadstring(bytes)
    if not f then return end;setfenv(f,{})
    local ok,t=pcall(f);return ok and type(t)=='table'and t or nil
  end
  local spec=(read('data/generated/constants.lua')or{}).gen3RsBerryTag
  if not M.valid(spec,version)then return{'<rs:native-berry-tags>'}end
  local out={}
  for _,path in ipairs(spec.resources)do
    if type(path)~='string'or path:sub(1,#ROOT)~=ROOT or not Fs.exists(path)then out[#out+1]=tostring(path)end
  end
  local man=read(ROOT..'manifest.lua')
  if not man or man.game~=version or man.layout~='rs'or type(man.berries)~='table'or #man.berries~=43
    or man.firstItem~=133 or man.lastItem~=175 or type(man.geometry)~='table'
    or man.geometry.scrollSpeed~=16 or man.geometry.scrollSteps~=16 or man.geometry.replacementStep~=9 then
    out[#out+1]=ROOT..'manifest.lua'
  end
  return out
end
return M
