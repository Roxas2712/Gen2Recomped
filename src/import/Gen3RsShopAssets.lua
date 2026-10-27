-- Native RS shop graphics, money label and authored printer-control text.
local M={};local ROOT='data/generated/gba/items/shop/'
function M.extract(x,load,rom,cache)
  x:beginStage('Ruby/Sapphire native shop')
  local extract=load('src.import.gba.rs.extract_shop')
  assert(extract.run(rom,cache,{}))
  local resources={ROOT..'manifest.lua'}
  for _,name in ipairs(extract.FILES)do resources[#resources+1]=ROOT..name end
  x._constants.gen3RsShop={format=1,version=x.version,resources=resources,
    source='ROM: native RS buy menu tilemap/palette, money label, text and window policy'}
end
function M.missing(version)
  local Fs=require('src.import.CacheFs')
  local function read(path)
    local raw=Fs.read(path);local f=raw and loadstring(raw);if not f then return end
    setfenv(f,{});local ok,value=pcall(f);return ok and type(value)=='table'and value or nil
  end
  local spec=(read('data/generated/constants.lua')or {}).gen3RsShop
  if not spec or spec.version~=version or spec.format~=1 or type(spec.resources)~='table'or #spec.resources~=8 then
    return {'<rs:native-shop>'}
  end
  local out={};for _,path in ipairs(spec.resources)do
    if type(path)~='string'or path:sub(1,#ROOT)~=ROOT or not Fs.exists(path)then out[#out+1]=tostring(path)end
  end
  local man=read(ROOT..'manifest.lua')
  if not man or man.game~=version or man.assetLayout~='rs'or man.shopVersion~=2
    or type(man.textBytes)~='table'or type(man.textAliases)~='table'or type(man.geometry)~='table'
    or man.geometry.iconPane~=false or man.geometry.ownedQuantityLabel~=false then out[#out+1]=ROOT..'manifest.lua'end
  return out
end
return M
