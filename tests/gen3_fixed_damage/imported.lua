-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Run the real move-byte importer, retaining its numeric MOVE IDs and fields.
local M={}
function M.read()
 local rows={[82]={41,'DRAGON RAGE'},[49]={130,'SONICBOOM'},[69]={87,'SEISMIC TOSS'},[101]={87,'NIGHT SHADE'},[149]={88,'PSYWAVE'}}
 local bytes,names,ids={},{},{}
 for n=0,149 do
  local row=rows[n];names[n]=row and row[2]or('MOVE %d'):format(n);ids[n]=('MOVE_%03d'):format(n)
  bytes[#bytes+1]=string.char(row and row[1]or 0,1,0,100,40,0,0,0,51,0,0,0)
 end
 local E=require('src.import.RomExtractorGen3')
 local extractor=setmetatable({rom=require('src.import.RomGba').new(table.concat(bytes)),_moveIds=ids,
  _constants={typeOrder={'NORMAL'}}},E)
 function extractor:beginStage()end
 function extractor:need(key)assert(key=='gBattleMoves');return 0 end
 function extractor:names(key)assert(key=='gMoveNames');return names end
 function extractor:layoutValue(key,default)if key=='numMoves'then return 150 end;return default end
 function extractor:tick()end
 function extractor:write(key,value)assert(key=='moves');self.published=value end
 extractor:extractMoves();assert(extractor.published==extractor._moves)
 local out={}
 for n in pairs(rows)do
  local id=ids[n];local row=assert(extractor._moves[id]);assert(row.fixedDamage==nil and row.index==n and row.effect=='SPECIAL_DAMAGE_EFFECT')
  out[id]=row
 end
 return out
end
return M
