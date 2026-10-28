-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
local Native=require('src.compat.gen1.NativeSession')
local Ids=require('src.compat.gen1.BattleIds')
local M={}
function M.displayName(value)
 if type(value)=='table'then value=value.id or value.move end
 if value==nil or value==false or value==0 or value==''or value=='-------'then return '-------'end
 if type(value)=='string'then value=tonumber(value)or value end
 local name=require('src.core.game3.pokemon').moveName(value)
 return name or nil,name==nil and'imported native move name unavailable'or nil
end
function M.get(number)
 local g=Native.game();if not g then return nil end
 local ids=Ids.new(g.data);local key=ids:native('moves',number)
 local row=key and g.data.moves[key];if not row then return nil end
 local out={id=ids:read('moves',key),name=row.name,type=ids:read('types',row.type),
  power=row.power,accuracy=row.accuracy,pp=row.pp,priority=row.priority,target=row.target,
  category=row.category or row.class,effect=row.effect,effectChance=row.effectChance,flags=row.flags}
 return out
end
return M
