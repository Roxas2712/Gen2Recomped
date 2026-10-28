-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local P=require('src.ui.Gen3HelpProgress')
local game={save={flags={},inventory={},pokedex={caught={}}},data={constants={itemOrder={[361]='TOWN_MAP'}},
 pokemon={A={dex=4},ALIAS={dex=4},B={dex=7},HOENN={dex=252}}}}
local function flag(id,value)game.save.flags[('FLAG_G3_%04X'):format(id)]=value end
local baseline={10,25,21,5,35}
for topic,limit in ipairs{44,48,43,7,35}do
 local count=0;for id=1,limit do if P.allowed(game,topic,id)then count=count+1 end end
 T.eq(count,baseline[topic],'retail fresh-progress question count for topic '..topic)
 T.eq(P.allowed(game,topic,0),false);T.eq(P.allowed(game,topic,limit+1),false)
end
T.eq(P.allowed(game,1,21),false);flag(0x829,0);T.eq(P.allowed(game,1,21),false)
flag(0x829,true);T.eq(P.allowed(game,1,21),true);T.eq(P.allowed(game,1,12),false)
for _,id in ipairs{0x237,0x238,0x239,0x23A,0x23B,0x2EF,0x1F1}do
 T.eq(P.allowed(game,1,28),false);flag(id,true)
 for _,pair in ipairs{{1,28},{1,40},{2,16},{2,17},{3,36},{3,37}}do T.eq(P.allowed(game,pair[1],pair[2]),true)end
 flag(id,nil)
end
T.eq(P.allowed(game,2,14),false);game.save.inventory.TOWN_MAP=1;T.eq(P.allowed(game,2,14),true)
game.save.inventory.TOWN_MAP=0;T.eq(P.allowed(game,2,14),false)
game.save.pokedex.caught={A=true,ALIAS=true,HOENN=true};T.eq(P.allowed(game,2,4),false,'duplicate/Hoenn dex IDs do not unlock Kanto switch help')
game.save.pokedex.caught.B=true;T.eq(P.allowed(game,2,4),true);T.eq(P.allowed(game,2,34),true)
local facts={basicTerms={1,3},contexts={[23]={{},{},{1,4,3,4,14}}}}
T.same(P.items(game,facts,23,3),{14})
flag(0x4B0,true);T.same(P.items(game,facts,23,3),{14,1,3},'Brock adds basic terms exactly once at the original end')
for _,id in ipairs{0x2CF,0x891,0x895,0x8A4,0x828,0x829,0x820,0x29B,0x892,0x271,0x82C,0x821,0x237}do flag(id,true)end
game.save.inventory.TOWN_MAP=1
for topic,limit in ipairs{44,48,43,7,35}do for id=1,limit do T.eq(P.allowed(game,topic,id),true,'fully unlocked original Help row')end end
T.finish('native Help progress, all question families, actual flag/item/dex identity and basic-term ordering')
