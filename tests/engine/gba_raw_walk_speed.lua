-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local F=require('tools.player-runtime.fixture')
local V=require('src.core.GameVersion');local Commands=require('src.script.Commands')
require('src.script.Gen3Commands')
local Json=require('src.link.Json');local original=V.get()
for _,edition in ipairs{'ruby','sapphire','emerald','firered','leafgreen'}do
 local f=F.new(edition);local g,w=f.game,f.world;local hoenn=edition=='ruby'or edition=='sapphire'or edition=='emerald'
 local calls={};function w:scriptMove(actor,direction,count,done,keep,rate)
  calls[#calls+1]={actor=actor,direction=direction,count=count,rate=rate};done()
 end
 local ctx={game=g,save=g.save,overworld=w,runner={resume=function()end}}
 g.data.map_scripts={movements={OLD_CACHE={{'walk_down',0x2D},{'walk_up',0x2E},{'walk_left',0x2F},{'walk_right',0x30}},
  AUTHORED={{'walk_down'},{'walk_fast_down'},{'walk_fastest_down'}},
  COALESCED={{'walk_down',0x2D},{'walk_down',0x2D},{'walk_down',0x08}}}}
 local before=Json.encode(g.save)
 Commands.g3_move(ctx,255,'OLD_CACHE')
 T.eq(#calls,4,edition..' retains all four native directions')
 for i,direction in ipairs{'down','up','left','right'}do
  T.eq(calls[i].actor,w.player);T.eq(calls[i].direction,direction);T.eq(calls[i].count,1)
  T.eq(calls[i].rate,hoenn and .25 or 1,edition..' old-cache native faster byte owns its pace')
 end
 T.eq(ctx.g3Moving.player.done,true,'actual movement continuation completes')
 calls={};Commands.g3_move(ctx,255,'AUTHORED')
 T.eq(#calls,3,'different authored rates must not coalesce')
 for i,rate in ipairs{1,.5,.25}do T.eq(calls[i].rate,rate,'authored names without native bytes retain their pace')end
 calls={};Commands.g3_move(ctx,255,'COALESCED')
 T.eq(#calls,hoenn and 2 or 1,'only equal native paces coalesce')
 T.eq(calls[1].count,hoenn and 2 or 3)
 T.eq(calls[1].rate,hoenn and .25 or 1)
 if hoenn then T.eq(calls[2]and calls[2].count,1);T.eq(calls[2]and calls[2].rate,1)end
 T.eq(Json.encode(g.save),before,'lowering movement does not rewrite the save')
end
V.set(original)
T.finish('Hoenn native faster-walk bytes, legacy caches, authored pace, coalescing and FRLG isolation')
