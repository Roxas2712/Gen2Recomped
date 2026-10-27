-- Source vocabulary used by older GSC content mods. Translate at the content
-- boundary; the native catalogue and battle code retain their actual IDs.
local M={}
local Contract=require('src.mods.MoveEffectContract')
local sourceEffects,nativeEffects={},{ }
local ids={};for id in pairs(Contract.bindings)do ids[#ids+1]=id end;table.sort(ids)
local ranks={}
for _,id in ipairs(ids)do
  local row=Contract.bindings[id]['2']
  if row and row.semantic and type(row.native)=='string' then
    local names=Contract.native3[tostring(row.semantic)] or {}
    nativeEffects[row.native]=names
    for _,name in ipairs(names)do
      if ranks[name]==nil or row.semantic<ranks[name] then
        sourceEffects[name],ranks[name]=row.native,row.semantic
      end
    end
  end
end
function M.typeId(loader,id)
  if loader:_generation()~=2 or id~='PSYCHIC_TYPE' then return id end
  local chart=loader.content.type_chart
  if chart:get(id)==nil and chart:get('PSYCHIC')~=nil then return 'PSYCHIC' end
  return id
end
function M.id(loader,name,id)
  if name~='type_chart' or type(id)~='string' then return id end
  local a,b=id:match('^([^>]+)>([^>]+)$')
  if a then return M.typeId(loader,a)..'>'..M.typeId(loader,b) end
  return M.typeId(loader,id)
end
function M.write(loader,name,value,current)
  if loader:_generation()~=2 or type(value)~='table' then return value end
  local out={};for k,v in pairs(value)do out[k]=v end
  if name=='move_effects' then return require('src.mods.Gen2MoveEffects').adapt(out) end
  if name=='pokemon' and value.types then
    out.types={};for i,id in ipairs(value.types)do out.types[i]=M.typeId(loader,id)end
  elseif name=='moves' then
    if value.type then out.type=M.typeId(loader,value.type)end
    if value.effect then
      local names=nativeEffects[value.effect]
      if current and sourceEffects[current.effect]==value.effect then out.effect=current.effect
      elseif names and names[1] then
        out.effect=names[2] and (tonumber(value.effectChance)or 0)>25 and names[2] or names[1]
      end
      if value.effect=='EFFECT_PRIORITY_HIT' and value.priority==nil then out.priority=1 end
    end
  end
  if name=='pokemon' and value.levelMoves then
    out.levelMoves=nil;out.learnset=value.levelMoves
    if value.level1Moves==nil then
      out.level1Moves={}
      for _,row in ipairs(value.levelMoves)do if row.level<=1 then out.level1Moves[#out.level1Moves+1]=row.move end end
      if #out.level1Moves==0 then out.level1Moves=current and current.level1Moves or {} end
    end
  end
  return out
end
function M.read(loader,name,value)
  if loader:_generation()~=2 or type(value)~='table' then return value end
  if name=='moves' and sourceEffects[value.effect] then
    local out={};for k,v in pairs(value)do out[k]=v end
    out.effect=sourceEffects[value.effect]
    if value.effect=='NO_ADDITIONAL_EFFECT' and value.priority==1 then out.effect='EFFECT_PRIORITY_HIT' end
    return out
  end
  if name~='pokemon' or value.levelMoves~=nil then return value end
  local out={};for k,v in pairs(value)do out[k]=v end
  out.levelMoves=value.learnset
  return out
end
return M
