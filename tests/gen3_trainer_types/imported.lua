-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Exercise the real move importer over controlled, authored battle-move bytes.
local M={}
M.names={[0]='NORMAL','FIGHTING','FLYING','POISON','GROUND','ROCK','BUG','GHOST',
 'STEEL','MYSTERY','FIRE','WATER','GRASS','ELECTRIC','PSYCHIC','ICE','DRAGON','DARK'}
M.encodings={'abbreviated','numeric','canonical','legacy-ids','constant-ids','explicit-native'}
function M.records()
 local rows={}
 for powerIndex,power in ipairs({60,0})do
  for kind=0,17 do
   local number=200+(powerIndex-1)*18+kind
   rows[#rows+1]={number=number,name=('TYPE_%02d_%s'):format(kind,power==0 and'STATUS'or'POWER'),
    kind=kind,power=power,priority=kind%2==0 and -3 or 1}
  end
 end
 return rows
end
function M.import(encoding)
 local E=require('src.import.RomExtractorGen3')
 local records=M.records();local byNumber={}
 for _,row in ipairs(records)do byNumber[row.number]=row end
 local bytes,names,ids={},{},{}
 for number=0,235 do
  local row=byNumber[number]
  names[number]=row and row.name or('MOVE %d'):format(number)
  ids[number]=('MOVE_%03d'):format(number)
  bytes[#bytes+1]=string.char(0,row and row.power or 0,row and row.kind or 0,95,10,15,0,
   row and row.priority%256 or 0,51,0,0,0)
 end
 local constants={types={},typeOrder={}}
 for kind=0,17 do
  local id=M.names[kind]
  if encoding=='abbreviated'then id=({[1]='FIGHT',[13]='ELECTR',[14]='PSYCHC'})[kind]or id
  elseif encoding=='legacy-ids'then id=({[9]='CURSE_TYPE',[14]='PSYCHIC_TYPE'})[kind]or id
  elseif encoding=='constant-ids'then id=('IMPORTED_TYPE_%02d'):format(kind)
  elseif encoding=='explicit-native'then id=('DISPLAY_TYPE_%02d'):format(kind)end
  if encoding~='numeric'then constants.typeOrder[kind+1]=id end
  constants.types[id]={id=id,index=kind,name=id}
 end
 local published
 local extractor=setmetatable({rom=require('src.import.RomGba').new(table.concat(bytes)),
  _moveIds=ids,_constants=constants},E)
 function extractor:beginStage()end
 function extractor:need(key)assert(key=='gBattleMoves');return 0 end
 function extractor:names(key)assert(key=='gMoveNames');return names end
 function extractor:layoutValue(key,default)
  if key=='numMoves'then return 236 end
  return default
 end
 function extractor:tick()end
 function extractor:write(key,value)assert(key=='moves');published=value end
 extractor:extractMoves()
 assert(published==extractor._moves,'actual importer publishes its native move rows')
 local out={}
 for _,row in ipairs(records)do
  local key=ids[row.number];local def=assert(published[key])
  if encoding=='explicit-native'then def.gen3Type=row.kind end
  assert(def.index==row.number and def.power==row.power and def.priority==row.priority)
  out[key]=def
 end
 return out,constants
end
return M
