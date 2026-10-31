-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local M=require('src.import.Gen3FirstBattle')
local maps={MAP_G00_N16={objects={{localId=4,graphicsId=98}}}}
local encounters={MAP_G00_N16={grass={slots={{species='POOCHYENA',min=2},{species='ZIGZAGOON',min=2}}}}}
for _,edition in ipairs{'ruby','sapphire','emerald'}do
 local r=assert(M.extract(edition,maps,encounters))
 T.eq(r.species,edition=='emerald'and'ZIGZAGOON'or'POOCHYENA','Emerald cannot inherit the paired-game rescue opponent')
 T.eq(r.level,2);T.eq(r.localId,4);T.eq(r.graphicsId,98);T.eq(r.canLose,true)
 local other=edition=='emerald'and'POOCHYENA'or'ZIGZAGOON'
 T.eq(M.extract(edition,maps,{MAP_G00_N16={grass={slots={{species=other,min=2}}}}}),nil,'A different animal in the grass is not rescue evidence')
 T.eq(M.extract(edition,maps,{MAP_G00_N16={grass={slots={{species=r.species,min=3}}}}}),nil,'An unrelated encounter level cannot retime the scripted battle')
end
T.eq(M.extract('firered',maps,encounters),nil)
T.eq(M.extract('emerald',{},encounters),nil)
T.eq(M.extract('emerald',{MAP_G00_N16={objects={{localId=4},{localId=4}}}},encounters),nil)
T.finish('Edition-correct native Hoenn rescue species and level, with own-route evidence')
