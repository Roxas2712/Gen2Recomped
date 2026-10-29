-- Explicit, data-only Gen1 Save-5 <-> native Save-4 interchange.
-- Contributions by Roxas2712. No profile is read, replaced or written here.
local Serializer=require('src.core.SaveSerializer')
local LuaData=require('src.storage.LuaData')
local M={REVISION=1,MAX_BYTES=16*1024*1024,SOURCE_FORMAT=5,NATIVE_FORMAT=4}
local editions={red=true,blue=true,yellow=true}
local directions={up=true,down=true,left=true,right=true}
local function uint(v,hi)return type(v)=='number'and v==v and v>=0 and v<=hi and v%1==0 end
local function clone(v)
  if type(v)~='table'then return v end
  local out={};for k,sub in pairs(v)do out[k]=clone(sub)end;return out
end
local function array(t,limit)
  if type(t)~='table'then return false end
  local count=0
  for k in pairs(t)do if not uint(k,limit)or k==0 then return false end;count=count+1 end
  for i=1,count do if t[i]==nil then return false end end
  return true
end
local function validate(save,format,data)
  local inventory=LuaData.inspect(save)
  if not inventory.serializable then return nil,inventory.reason end
  if type(save)~='table'or not editions[save.version]or type(save.meta)~='table'or save.meta.format~=format then
    return nil,'expected a Gen1 '..tostring(format)..' save (Red/Blue/Yellow); GSC and Game3 use separate upstream schemas'
  end
  local p=save.player
  if type(p)~='table'or type(p.name)~='string'or #p.name>32 or not uint(p.id,65535)
      or type(p.map)~='string'or not uint(p.x,65535)or not uint(p.y,65535)or not directions[p.facing]then
    return nil,'invalid saved player identity or destination'
  end
  if data then
    if type(data.maps)~='table'or not data.maps[p.map]then return nil,'saved map is unavailable in the target dataset'end
    local map=data.maps[p.map]
    -- GB definitions store 32-pixel blocks, whereas saved positions are cells.
    if type(map.width)=='number'and p.x>=map.width*2 or type(map.height)=='number'and p.y>=map.height*2 then
      return nil,'saved position is outside the target map'
    end
  end
  if not array(save.party,6)then return nil,'invalid party array'end
  local function mon(record)
    if type(record)~='table'or type(record.species)~='string'or not uint(record.level,100)or record.level<1
        or not uint(record.hp,65535)or type(record.moves)~='table'or not array(record.moves,4)then return nil,'invalid saved Pokemon'end
    if data and not(data.pokemon and data.pokemon[record.species])then return nil,'unknown saved species: '..record.species end
    for _,move in ipairs(record.moves)do
      if type(move)~='table'or type(move.id)~='string'or not uint(move.pp,255)
          or move.ppUps~=nil and not uint(move.ppUps,3)then return nil,'invalid saved move'end
      if data and not(data.moves and data.moves[move.id])then return nil,'unknown saved move: '..move.id end
    end
    return true
  end
  for _,record in ipairs(save.party)do local ok,why=mon(record);if not ok then return nil,why end end
  if save.boxes~=nil then
    if not array(save.boxes,32)then return nil,'invalid box array'end
    for _,box in ipairs(save.boxes)do
      if not array(box,30)then return nil,'invalid box contents'end
      for _,record in ipairs(box)do local ok,why=mon(record);if not ok then return nil,why end end
    end
  end
  if save.box~=nil then
    if not array(save.box,30)then return nil,'invalid legacy box'end
    for _,record in ipairs(save.box)do local ok,why=mon(record);if not ok then return nil,why end end
  end
  return true
end
function M.import(bytes,data)
  if type(bytes)~='string'or #bytes>M.MAX_BYTES then return nil,'invalid Save-5 byte limit'end
  local ok,save=pcall(Serializer.decode,bytes)
  if not ok then return nil,'invalid data-only Save-5: '..tostring(save)end
  local valid,why=validate(save,M.SOURCE_FORMAT,data);if not valid then return nil,why end
  local converted=clone(save);converted.meta.format=M.NATIVE_FORMAT
  -- Save-5's traded-OT repair already happened upstream. Do not run it again:
  -- a legitimate partner may share the local trainer ID.
  return converted,{revision=M.REVISION,version=save.version,sourceFormat=5,targetFormat=4,
    nativeWrites=0,unknownFieldsPreserved=true}
end
function M.export(save,data)
  local valid,why=validate(save,M.NATIVE_FORMAT,data);if not valid then return nil,why end
  local converted=clone(save);converted.meta.format=M.SOURCE_FORMAT
  local ok,bytes=pcall(Serializer.encodeExact,converted)
  if not ok then return nil,tostring(bytes)end
  if #bytes>M.MAX_BYTES then return nil,'Save-5 byte limit exceeded'end
  return bytes,{revision=M.REVISION,version=save.version,sourceFormat=4,targetFormat=5,
    nativeWrites=0,unknownFieldsPreserved=true}
end
return M
