-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Exact-edition RS credits, decoded by the pinned reference extractor.
local M={};local ROOT='data/generated/gba/credits_rse/'
function M.extract(x,load,rom,cache)
  x:beginStage('Ruby/Sapphire native credits scenery and ending')
  local reader=load('src.import.gba.rs.extract_credits')
  local ok,man=reader.run(rom,cache,{})
  assert(ok and type(man)=='table'and man.creditsVersion==2 and man.assetLayout=='rs'and man.game==x.version
    and man.pageCount==52 and man.entriesPerPage==5 and man.numMonSlides==68)
  local resources={ROOT..'manifest.lua'}
  for _,name in ipairs(reader.FILES)do resources[#resources+1]=ROOT..name end
  x._constants.gen3RsCredits={format=1,version=x.version,resources=resources,
    pageCount=52,numMonSlides=68,source='ROM: native RS credit pages, palettes, riders, scene transitions and THE END'}
end
function M.valid(spec,version)
  return (version=='ruby'or version=='sapphire')and type(spec)=='table'and spec.format==1
    and spec.version==version and spec.pageCount==52 and spec.numMonSlides==68
    and type(spec.resources)=='table'and #spec.resources==7
end
function M.manifestValid(man,version)
  if type(man)~='table'or man.game~=version or man.assetLayout~='rs'or man.creditsVersion~=2
    or man.pageCount~=52 or man.entriesPerPage~=5 or man.numMonSlides~=68
    or type(man.pages)~='table'or #man.pages~=52 or type(man.pageTransitions)~='table'
    or type(man.credits)~='table'or not man.credits.brendan_credits or not man.credits.may_credits then return false end
  for _,page in ipairs(man.pages)do
    if type(page)~='table'or #page~=5 then return false end
    for _,entry in ipairs(page)do
      if type(entry)~='table'or type(entry.text)~='string'or type(entry.isTitle)~='boolean'
        or(entry.palette~=8 and entry.palette~=9)then return false end
    end
  end
  return true
end
function M.missing(version)
  local Fs=require('src.import.CacheFs')
  local function read(path)
    local raw=Fs.read(path);local f=raw and loadstring(raw,'@'..path)
    if not f then return end;setfenv(f,{})
    local ok,m=pcall(f);return ok and type(m)=='table'and m or nil
  end
  local spec=(read('data/generated/constants.lua')or{}).gen3RsCredits
  if not M.valid(spec,version)then return{'<rs:native-credits>'}end
  local out={}
  for _,path in ipairs(spec.resources)do
    if type(path)~='string'or path:sub(1,#ROOT)~=ROOT or not Fs.exists(path)then out[#out+1]=tostring(path)end
  end
  local man=read(ROOT..'manifest.lua')
  if not M.manifestValid(man,version)then
    out[#out+1]=ROOT..'manifest.lua'
  end
  return out
end
return M
