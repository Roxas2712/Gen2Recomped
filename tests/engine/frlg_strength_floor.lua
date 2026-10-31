-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local V=require('src.core.GameVersion');local G=require('src.core.Game')
local World=require('src.world.OverworldController')
local VM=require('src.script.Gen3ScriptVM');local Scripts=require('src.script.MapScripts')
local C=require('src.script.Gen3Commands');local Sound=require('src.core.Sound')
-- Production binds this shared upvalue on world entry. Isolate the push
-- callback without constructing an unrelated renderer or importing a ROM.
local gameSlot,priorGame,mapSlot,priorMaps
for i=1,100 do
 local name,value=debug.getupvalue(World.checkBoulderPush,i)
 if not name then break end
 if name=='Game'then gameSlot,priorGame=i,value;debug.setupvalue(World.checkBoulderPush,i,G)end
 if name=='mapScripts'then mapSlot,priorMaps=i,value;debug.setupvalue(World.checkBoulderPush,i,Scripts)end
end
assert(gameSlot and mapSlot,'native world entry bindings missing')
local oldPlay,oldId=Sound.play,Sound.playId
local cues={};Sound.play=function()end;Sound.playId=function(_,id)cues[#cues+1]=id end
for _,version in ipairs{'firered','leafgreen','ruby','sapphire','emerald'}do
 V.set(version)
 local frlg=V.isFRLG();local id='STRENGTH_'..version:upper()
 local def={id=id,generation=3,objects={}}
 local data={maps={[id]=def},constants={gen3StrengthFlag=0x805},map_scripts={
  source='RomExtractorGen3',scripts={SW={{'setvar',0x4064,100},{'end'}},
   LAST={{'setvar',0x4064,101},{'end'}}},maps={[id]={coords={
    {x=20,y=16,elevation=3,var=0x4064,value=99,script='SW'}}}}}}
 G.data=data;G.save={flags={FLAG_G3_0805=true},vars={}}
 require('src.core.Data').maps=data.maps
 C.setVar(G.save,0x4064,0)
 T.eq(VM.register(data,'scenes'),1)
 local hooks=assert(Scripts.get(id));T.eq(type(hooks.onBoulderMoved),'function','scene registration retains native boulder dispatch')
 local behavior=0x20;local starts={};local busy=false
 local map={id=id,def=def,sourceBehaviourAt=function()return behavior end,
  inBounds=function()return true end,isWalkableCell=function()return true end,
  isWarpTileCell=function()return false end}
 local npc={id=id..'_obj_5',cellX=20,cellY=15,def={index=5,graphicsId=97,pushable=true}}
 def.objects={npc.def}
 local world=setmetatable({map=map,player={cellX=20,cellY=14},entities={npc},npcs={npc},
  frlgBehaviours=function()return frlg and{}or nil end,
  npcAtCell=function(_,x,y)if npc.cellX==x and npc.cellY==y then return npc end end,
  startDustAnim=function()end,gen2BoulderIntoPit=function()return false end,
  boulderIntoHole=function()return false end},{__index=World})
 world.runner={isRunning=function()return busy end,run=function(_,rows,ctx)starts[#starts+1]={rows=rows,ctx=ctx}end}
 T.eq(hooks.onStep(G,world,20,16),false,'ordinary player step keeps the native value-99 gate')
 T.eq(#starts,0)
 local done
 world.scriptMove=function(_,entity,dir,count,callback)
  T.eq(entity,npc);T.eq(dir,'down');T.eq(count,1);done=callback
 end
 T.eq(world:checkBoulderPush('down'),true,'actual push admission reaches its completion callback')
 T.eq(#starts,0,'no coordinate script before the stone has landed')
 npc.cellY=16;done()
 T.eq(#starts,frlg and 1 or 0,'only FRLG starts the native button after the push')
 if frlg then
  T.eq(starts[1].rows,VM.compile(data,'SW'),'run the original compiled coordinate program')
  T.eq(starts[1].ctx.mapId,id)
 end
 for _,value in ipairs{0,99,100}do
  starts={};C.setVar(G.save,0x4064,value)
  T.eq(hooks.onBoulderMoved(G,world,npc),frlg,'boulder activation bypasses the player var gate')
  T.eq(#starts,frlg and 1 or 0)
 end
 starts={};npc.cellX=19;T.eq(hooks.onBoulderMoved(G,world,npc),false);T.eq(#starts,0);npc.cellX=20
 for _,b in ipairs{0,0x66,0x67}do behavior=b;starts={};T.eq(hooks.onBoulderMoved(G,world,npc),false);T.eq(#starts,0)end
 behavior=0x20;busy=true;starts={};T.eq(hooks.onBoulderMoved(G,world,npc),false);T.eq(#starts,0);busy=false
 if frlg then
  -- The native loop assigns the script for every matching coordinate: the
  -- final matching row wins, without using the player's elevation or var.
  data.map_scripts.maps[id].coords[2]={x=20,y=16,elevation=9,var=0x4064,value=77,script='LAST'}
  VM.register(data,'scenes');hooks=Scripts.get(id);starts={}
  T.eq(hooks.onBoulderMoved(G,world,npc),true);T.eq(starts[1].rows,VM.compile(data,'LAST'))
 end
 -- A fallen stone is hidden for the current map visit. Its own permanent
 -- event flag and the unrelated trainerRange flag must stay untouched.
 behavior=0x66;npc.def.trainerType=0x260;npc.def.trainerRange=0x261
 npc.def.eventFlag='FLAG_G3_0250';G.save.flags.FLAG_G3_0250=false
 G.save.flags.FLAG_G3_0260=true;G.save.flags.FLAG_G3_0261=true
 G.save.gen3SessionObjects={mapId='OLD',[2]=false}
 world.scriptMoves={{entity=npc},{entity=world.player}}
 world.syncObjectVisibility=function(_,only)
  T.eq(only,npc.def)
  if G.save.gen3SessionObjects and G.save.gen3SessionObjects[5]==false then world.entities={};world.npcs={}end
 end
 cues={};T.eq(world:gen3BoulderIntoHole(npc),frlg)
 if frlg then
  T.eq(#world.entities,0);T.eq(#world.npcs,0)
  T.eq(G.save.gen3SessionObjects.mapId,id);T.eq(G.save.gen3SessionObjects[5],false)
  T.eq(G.save.gen3SessionObjects[2],nil,'another map session cannot leak')
  T.eq(G.save.flags.FLAG_G3_0260==true,false,'trainerType is the lower-floor reveal flag')
  T.eq(#cues,1);T.eq(cues[1],37,'original FRLG SE_FALL')
  T.eq(#world.scriptMoves,1);T.eq(world.scriptMoves[1].entity,world.player)
 else
  T.eq(#world.entities,1);T.eq(G.save.flags.FLAG_G3_0260,true);T.eq(#cues,0)
 end
 T.eq(G.save.flags.FLAG_G3_0250,false,'no permanent removal of the upper stone')
 T.eq(G.save.flags.FLAG_G3_0261,true,'trainerRange is not the reveal flag')
end
Sound.play,Sound.playId=oldPlay,oldId
debug.setupvalue(World.checkBoulderPush,gameSlot,priorGame)
debug.setupvalue(World.checkBoulderPush,mapSlot,priorMaps)
T.finish('Native FRLG Strength button dispatch and lower-floor boulder reveal; other editions retain their own behavior')
