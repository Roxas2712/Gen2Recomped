-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Read the native Safari owner's already-imported IR; no replacement prose,
-- decoder, interpreter or action clock. Named roles stay edition-bound.
local Version=require('src.core.GameVersion')
local Copy=require('src.mods.Merge').deepCopy
local M={PREFIX='native.safari.'}
function M.spec(data,edition)
 if type(data)~='table'then return end
 local info=Version.info(edition)
 local catalog=type(data.text_pointers)=='table'and data.text_pointers.namedIR
 local s=type(data.constants)=='table'and data.constants.gen3SafariNative
 if not(info and info.generation==3 and type(catalog)=='table'and catalog.schema==1
   and catalog.edition==edition and catalog.romSha1==info.sha1 and type(s)=='table')then return end
 local ok,owner=pcall(require,'src.import.Gen3SafariAssets')
 if ok and type(owner)=='table'and type(owner.valid)=='function'and owner.valid(s,edition)then return s end
end
function M.read(data,edition,key)
 if type(key)~='string'or key:sub(1,#M.PREFIX)~=M.PREFIX then return end
 local s=M.spec(data,edition);local role=key:sub(#M.PREFIX+1)
 local raw=s and s.textIR[role];if type(raw)~='table'then return end
 local profile=require('src.import.Gen3BattleTextCatalog').profile(edition)
 local nodes,plain={},{}
 local breaks={nl='\n',scroll='\v',para='\f'}
 for _,node in ipairs(raw)do
  local row=Copy(node)
  if row.t=='bph'then
   if not profile.placeholders[row.code]then return end
   row.t='ph';plain[#plain+1]=('{PH:%02X}'):format(row.code)
  elseif row.t=='text'then plain[#plain+1]=row.s
  elseif row.t=='tag'then plain[#plain+1]=row.tag
  elseif breaks[row.t]then plain[#plain+1]=breaks[row.t]
  elseif row.t~='ext'and row.t~='eos'then return end
  nodes[#nodes+1]=row
 end
 return table.concat(plain),nodes
end
return M
