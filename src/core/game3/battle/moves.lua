-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
local Native=require('src.compat.gen1.NativeSession')
local Ids=require('src.compat.gen1.BattleIds')
local M={}
local function detached(value,seen)
 if type(value)~='table'then return type(value)~='function'and type(value)~='userdata'and value or nil end
 seen=seen or{};if seen[value]then return seen[value]end
 local out={};seen[value]=out
 for k,v in pairs(value)do if type(k)=='string'or type(k)=='number'then out[k]=detached(v,seen)end end
 return out
end
function M.displayName(value)
 if type(value)=='table'then value=value.id or value.move end
 if value==nil or value==false or value==0 or value==''or value=='-------'then return '-------'end
 if type(value)=='string'then value=tonumber(value)or value end
 local name=require('src.core.game3.pokemon').moveName(value)
 return name or nil,name==nil and'imported native move name unavailable'or nil
end
function M.get(number)
 if type(number)=='table'then number=number.id or number.move end
 if type(number)=='string'then number=tonumber(number)or number end
 local g=Native.game();if not g then return nil end
 local ids=Ids.new(g.data);local key=ids:native('moves',number)
 local row=key and g.data.moves[key];if not row then return nil end
 local effect=row.gen3Effect
 if effect~=nil and(type(effect)~='number'or effect~=effect or effect%1~=0 or effect<0 or effect>255)then
  return nil,'invalid imported native move-effect byte'
 end
 local id=ids:read('moves',key)
 local out={id=id,numId=id,nativeId=key,name=row.name,type=ids:read('types',row.type),
  power=row.power,accuracy=row.accuracy,pp=row.pp,priority=row.priority,target=row.target,
  category=row.category or row.class,effect=effect~=nil and effect or row.effect,
  gen3Effect=effect,nativeEffect=row.effect,effectChance=row.effectChance,
  secondaryChance=row.secondaryChance,flags=detached(row.flags),hits=detached(row.hits),
  highCrit=row.highCrit,makesContact=row.makesContact,protectAffected=row.protectAffected,
  magicCoatAffected=row.magicCoatAffected,snatchAffected=row.snatchAffected,
  mirrorMoveAffected=row.mirrorMoveAffected,kingsRockAffected=row.kingsRockAffected}
 return out
end
return M
