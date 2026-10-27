package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Commands=require('src.script.Commands');require('src.script.Gen3Commands')
local Runner=require('src.script.ScriptRunner');local VM=require('src.script.Gen3ScriptVM')
local Maps=require('src.script.MapScripts')
local n=0;local function check(v,why)n=n+1;assert(v,why)end
local mapId='G3_TEMPLATE_PLACEMENT_CONTRACT'
local def={index=1,x=6,y=6,sprite='SPRITE_G3_045',text='TEMPLATE_NPC'}
local npc={def=def,cellX=6,cellY=6,px=96,py=96,moving=true,targetX=6,targetY=5}
local world={map={id=mapId,def={objects={def}}},npcByIndex=function(_,i)return i==1 and npc end}
local game={save={},data={}};world.runner=Runner.new(game,world)
local ctx={mapId=mapId,save=game.save,game=game,overworld=world}
Commands.g3_place_perm(ctx,1,6,7)
check(npc.cellX==6 and npc.cellY==6,'A template write must not relocate the live NPC onto the player')
check(npc.moving and npc.targetY==5,'A template write must not cancel a live movement')
check(game.save.gen3ObjectHomes[mapId][1].y==7,'Template coordinates must still be recorded')
ctx.gen3MapSetup=true;Commands.g3_place_perm(ctx,1,5,4)
check(npc.cellX==5 and npc.cellY==4,'Deferred setup must stage the already-created host NPC')
check(not npc.moving and npc.targetX==nil and npc.targetY==nil,'Setup placement lands its actor')
ctx.gen3MapSetup=nil;Commands.g3_place(ctx,1,3,2)
check(npc.cellX==3 and npc.cellY==2,'The live SETOBJECTXY opcode still relocates immediately')
local data={maps={[mapId]={objects={def}}},map_scripts={source='RomExtractorGen3',generation=3,scripts={
  S0000001={{'setobjectxyperm',1,5,4},{'end'}},
  S0000002={{'setobjectxyperm',1,6,7},{'end'}},
  S0000003={{'setobjectxyperm',1,8,9},{'end'}},
},maps={[mapId]={callbacks={{type=1,script='S0000001'},{type=3,script='S0000001'},
  {type=5,script='S0000002'}},tables={{type=2,rows={{var=0x4000,value=0,script='S0000003'}}}}}}}}
game.data=data;check(VM.register(data,'scenes')==1,'Native template fixture must compile')
local queued={};world.queueScript=function(_,rows,extra)queued[#queued+1]={rows=rows,extra=extra}end
local hooks=assert(Maps.get(mapId));hooks.onEnter(game,world)
check(#queued==3,'All load, transition and resume callbacks are retained')
for i=1,3 do
  check(queued[i].extra.gen3MapSetup==(i<3),'Only load/transition callbacks carry setup context')
  world.runner:run(queued[i].rows,queued[i].extra)
  check(not world.runner:isRunning(),'Template callback must finish')
  check(npc.cellX==5 and npc.cellY==4,'Resume must preserve the current live actor position')
end
check(game.save.gen3ObjectHomes[mapId][1].x==6 and game.save.gen3ObjectHomes[mapId][1].y==7,
  'Resume retains its template update without moving the actor')
check(hooks.onFrame(game,world),'Native frame-table callback must run')
check(npc.cellX==5 and npc.cellY==4 and game.save.gen3ObjectHomes[mapId][1].y==9,
  'Frame-table template writes must not inherit a previous setup context')
print('GEN3_TEMPLATE_PLACEMENT_CHECKS',n)
