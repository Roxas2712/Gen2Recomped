-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local F=require('tools.player-runtime.fixture')
local C=require('src.script.Commands');require('src.script.Gen3Commands')
local J=require('src.link.Json');local V=require('src.core.GameVersion');local original=V.get()
for _,edition in ipairs{'ruby','sapphire','emerald','firered','leafgreen'}do
 local f=F.new(edition);local g,w=f.game,f.world;w.map.id='MAP_G00_N20'
 local here={id='MAP_G00_N20_obj_7',def={index=7}}
 local carried={id='MAP_G00_N19_obj_7',def={index=7}}
 local absent={id='MAP_G00_N18_obj_7',def={index=7}}
 w.npcs={here,carried};w.entities={w.player,here,carried};w.npcPool={[absent.id]=absent}
 g.data.map_scripts={movements={MOVE={{'walk_down',8}}}}
 local calls={};function w:scriptMove(e,dir,n,done)calls[#calls+1]={entity=e,done=done}end
 local yields,resumes=0,0
 local ctx={game=g,save=g.save,overworld=w,runner={yield=function()yields=yields+1 end,resume=function()resumes=resumes+1 end}}
 local before=J.encode(g.save)
 C.g3_move(ctx,7,'MOVE',0,19)
 T.eq(#calls,1,edition..' explicit owner finds a carried live actor')
 T.eq(calls[1]and calls[1].entity,carried,'same-index destination bystander is untouched')
 C.g3_wait_move(ctx,7,0,20);T.eq(yields,0,'a same-index different owner must not wait on this move')
 C.g3_wait_move(ctx,7,0,19);T.eq(yields,1,'explicit wait follows the carried owner')
 if calls[1]then calls[1].done()end
 T.eq(resumes,1,'the actual carried movement completes its wait')
 calls={};C.g3_move(ctx,7,'MOVE',0,18)
 T.eq(#calls,0,'an unloaded pooled actor cannot be moved or substituted')
 C.g3_wait_move(ctx,7,0,18);T.eq(yields,1,'an unloaded actor never owns a wait')
 C.g3_move(ctx,7,'MOVE');T.eq(#calls,1,'ordinary current-map lookup is retained')
 T.eq(calls[1]and calls[1].entity,here,'ordinary lookup addresses the destination actor')
 C.g3_move(ctx,255,'MOVE',0,18);T.eq(#calls,1,'explicit player movement on another map remains refused')
 calls={};carried.removed=true;C.g3_move(ctx,7,'MOVE',0,19)
 T.eq(#calls,0,'a retired actor is not a live carried owner')
 carried.removed=nil;carried.despawned=true;C.g3_move(ctx,7,'MOVE',0,19)
 T.eq(#calls,0,'a despawned actor cannot restart movement')
 carried.despawned=nil;w.npcs={here};C.g3_move(ctx,7,'MOVE',0,19)
 T.eq(#calls,0,'entity pool membership alone cannot resurrect a departed actor')
 T.eq(J.encode(g.save),before,'live movement ownership does not rewrite any save field')
end
V.set(original);T.finish('Five-edition explicit movement/wait owners across seams, bystander and unloaded-map isolation')
