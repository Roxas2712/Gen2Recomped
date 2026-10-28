-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Detached names/indices from the current native import, never another ROM.
local Version=require('src.core.GameVersion')
local Native=require('src.compat.gen1.NativeSession')
local C={}
local function enum(rows,prefix)
 local names,ids={},{}
 for name,id in pairs(rows)do
  if type(name)=='string'and type(id)=='number'then names[(prefix or'')..name]=id;ids[id]=ids[id]or((prefix or'')..name)end
 end
 return{byName=names,byId=ids}
end
function C.of(edition)
 edition=edition or Version.get();assert(edition==Version.get(),'foreign native constant dataset')
 local g=Native.game();assert(g,'no native GBA constant dataset')
 local data=g.data;local rows={}
 local forms=data.field and data.field.playerForms or{}
 for who,r in pairs(forms)do
  if r.picIndex then
   local frlg=edition=='firered'or edition=='leafgreen'
   local name=who=='boy'and(frlg and'TRAINER_PIC_RED'or'TRAINER_PIC_BRENDAN')or who=='girl'and(frlg and'TRAINER_PIC_LEAF'or'TRAINER_PIC_MAY')
   if name then rows[name]=r.picIndex end
  end
 end
 -- Named special partners retain the picture identity on native trainer rows.
 for _,r in pairs(data.trainers or{})do
  if(r.name=='WALLY'or r.name=='STEVEN')and type(r.picIndex)=='number'then
   local key='TRAINER_PIC_'..r.name
   if rows[key]and rows[key]~=r.picIndex then error('ambiguous native trainer identity: '..r.name)end
   rows[key]=r.picIndex
  end
 end
 local sections={}
 for id,name in pairs(data.constants.gen3MapSections or{})do
  if type(name)=='table'then name=name.name end
  if type(name)=='string'then sections['MAPSEC_'..name:upper():gsub('[^%w]+','_')]=id end
 end
 local out={game=edition,trainer_classes=enum(rows),region_map_sections=enum(sections)}
 local labels=require('src.import.gba.field_label_facts').metatileLabels(edition)
 if labels then out.metatile_labels=enum(labels)end
 local refs=setmetatable({g,data,g.save,g.mods},{__mode='v'})
 local hadMods=g.mods~=nil
 function out:require(kind,name)
  local owner=refs[1]
  assert(owner and Native.game()==owner and Version.get()==edition and owner.data==refs[2]
   and owner.save==refs[3]and owner.mods==refs[4]and hadMods==(owner.mods~=nil),
   'native constant query retired')
  assert(type(kind)=='string'and type(name)=='string','invalid native constant name')
  local value=self:id(kind,name)
  assert(value~=nil,'missing native constant '..kind..'.'..name)
  return value
 end
 function out:raw(kind)local row=self[kind];return row and require('src.mods.Merge').deepCopy(row)end
 function out:id(kind,name)local row=self[kind];return row and row.byName[name]end
 function out:name(kind,id)local row=self[kind];return row and row.byId[id]end
 return out
end
C.active=function(session)
 if session~=nil then
  local record=require('src.compat.gen1.SessionView').record(session)
  local game=Native.game()
  assert(record and record:valid()and record.owner==game
   and session==require('src.core.Game3').forNative(game).session,'foreign or retired native constant session')
 end
 return C.of()
end
return C
