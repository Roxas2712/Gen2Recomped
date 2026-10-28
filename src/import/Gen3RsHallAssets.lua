-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
local M={};local ROOT='data/generated/gba/hall_of_fame/'
local EXTRA={'gOtherText_IDNumber2','gText_EggNickname'}
function M.extract(x,load,rom,cache)
  x:beginStage('Ruby/Sapphire native Hall of Fame presentation')
  local reader=load('src.import.gba.rs.extract_hall_of_fame')
  local ok,man=reader.run(rom,cache,{})
  assert(ok and man.game==x.version and man.assetLayout=='rs'and man.hofVersion==1
    and man.confetti.frames==17,'Native RS Hall of Fame extraction failed')
  local S=load('src.import.gba.syms').of(x.version)
  local IR=load('src.core.game3.scripting.text_ir');local text={}
  local function read(name)
    local at=assert(S.off(name),'Missing native RS Hall of Fame text '..name);local raw={}
    for i=0,2047 do local b=rom:get(at+i);raw[#raw+1]=b;if b==255 then return IR.decode(raw,{dialect='rs'})end end
    error('Unterminated native Hall of Fame text '..name)
  end
  for alias,symbol in pairs(load('src.ui.game3.rs.hall_of_fame_policy').aliases)do text[alias]=read(symbol)end
  for _,name in ipairs(EXTRA)do text[name]=read(name)end
  local pics={boy='data/generated/gba/birch/brendan.png',girl='data/generated/gba/birch/may.png'}
  local resources={ROOT..'manifest.lua'}
  for _,name in ipairs(reader.FILES)do resources[#resources+1]=ROOT..name end
  for _,key in ipairs{'boy','girl'}do resources[#resources+1]=pics[key]end
  x._constants.gen3RsHall={format=1,version=x.version,resources=resources,textIR=text,trainerPics=pics,
    source='ROM: native RS Hall of Fame bands, stripes, confetti, trainer portraits and original text'}
end
function M.valid(spec,version)
  return (version=='ruby'or version=='sapphire')and type(spec)=='table'and spec.format==1 and spec.version==version
    and type(spec.resources)=='table'and #spec.resources==6 and type(spec.textIR)=='table'
    and type(spec.trainerPics)=='table'and type(spec.trainerPics.boy)=='string'and type(spec.trainerPics.girl)=='string'
end
function M.missing(version)
  local Fs=require('src.import.CacheFs')
  local function read(path)
    local raw=Fs.read(path);local f=raw and loadstring(raw,'@'..path)
    if not f then return end;setfenv(f,{})
    local ok,t=pcall(f);return ok and type(t)=='table'and t or nil
  end
  local spec=(read('data/generated/constants.lua')or{}).gen3RsHall
  if not M.valid(spec,version)then return{'<rs:native-hall-of-fame>'}end
  local out={}
  for _,path in ipairs(spec.resources)do if type(path)~='string'or not Fs.exists(path)then out[#out+1]=tostring(path)end end
  local aliases=require('compat.gen1-rs.Loader').new(version)('src.ui.game3.rs.hall_of_fame_policy').aliases
  for name in pairs(aliases)do if type(spec.textIR[name])~='table'or #spec.textIR[name]==0 then out[#out+1]='<rs:hall-text:'..name..'>'end end
  for _,name in ipairs(EXTRA)do if type(spec.textIR[name])~='table'or #spec.textIR[name]==0 then out[#out+1]='<rs:hall-text:'..name..'>'end end
  local man=read(ROOT..'manifest.lua')
  if not man or man.game~=version or man.assetLayout~='rs'or man.hofVersion~=1 or man.width~=240 or man.height~=160
    or type(man.confetti)~='table'or man.confetti.frames~=17 or man.confetti.w~=8 or man.confetti.h~=8 then
    out[#out+1]=ROOT..'manifest.lua'
  end
  return out
end
return M
