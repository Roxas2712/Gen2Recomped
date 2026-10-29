-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Original PC labels; the existing native Hall pack owns pictures and frames.
local M={};local versions={ruby=true,sapphire=true,emerald=true,firered=true,leafgreen=true}
local common={'gText_Number','gText_Level','gText_IDNumber','gText_HOFNumber','gText_HOFCorrupted'}
function M.labels(version)
 local names={};for _,key in ipairs(common)do names[#names+1]=key end
 if version=='emerald'then
  for _,key in ipairs{'gText_AButtonExit','gText_PickCancel','gText_PickNextCancel'}do names[#names+1]=key end
 elseif version=='firered'or version=='leafgreen'then
  for _,key in ipairs{'gText_ABUTTONExit','gText_UPDOWNPick_ABUTTONBBUTTONCancel','gText_UPDOWNPick_ABUTTONNext_BBUTTONBack'}do names[#names+1]=key end
 end
 return names
end
function M.extract(x)
 local version=x.version;if not versions[version]then return end
 x:beginStage('Original Hall of Fame PC labels')
 local load=require('compat.gen1-rs.Loader').new(version);local IR=load('src.core.game3.scripting.text_ir')
 local rs=version=='ruby'or version=='sapphire';local symbols,aliases,labels
 if rs or version=='emerald'then symbols=load('src.import.gba.syms').of(version)
 else labels=require('src.import.gba.text_labels.'..version)end
 if rs then aliases=load('src.ui.game3.rs.hall_of_fame_policy').aliases end
 local text={}
 for _,key in ipairs(M.labels(version))do
  local name=aliases and aliases[key]or key
  local at=assert(symbols and symbols.off(name)or(labels and labels[name]),'Missing original Hall PC text '..name)
  local bytes={};for i=0,2047 do local b=x.rom:u8(at+i);bytes[#bytes+1]=b;if b==255 then break end end
  assert(bytes[#bytes]==255,'Unterminated original Hall PC text '..name)
  text[key]=IR.decode(bytes,{dialect=rs and'rs'or version=='emerald'and'rse'or'frlg'})
 end
 x._constants.gen3HallPc={format=1,version=version,textIR=text}
 x:write('constants',x._constants)
end
function M.valid(spec,version)
 if not(versions[version]and type(spec)=='table'and spec.format==1 and spec.version==version and type(spec.textIR)=='table')then return false end
 for _,key in ipairs(M.labels(version))do if type(spec.textIR[key])~='table'or#spec.textIR[key]==0 then return false end end
 return true
end
function M.missing(version)
 if not versions[version]then return{}end
 local raw=require('src.import.CacheFs').read('data/generated/constants.lua');local f=raw and loadstring(raw)
 if f then setfenv(f,{})end;local ok,c=false,nil;if f then ok,c=pcall(f)end
 if ok and type(c)=='table'and M.valid(c.gen3HallPc,version)then return{}end
 return{'<'..version..':native-hall-pc>'}
end
return M
