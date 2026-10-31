-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local C=require('src.script.Gen3Commands');local VM=require('src.script.Gen3ScriptVM')
local R=require('src.script.ScriptRunner');local Scripts=require('src.script.MapScripts')
local F=require('tools.battle-source-runtime.fixture')
for _,edition in ipairs{'firered','leafgreen','ruby','sapphire','emerald'}do
 local f=F.new(edition);local g=f.game;local id='OWNED_CONTINUE_'..edition
 g.data.maps[id]={}
 g.data.map_scripts={source='RomExtractorGen3',maps={[id]={callbacks={
  {type=5,script='RESUME'},{type=1,script='LOAD'},{type=3,script='TRANSITION'}},
  tables={{type=4,rows={{var=0x4023,value=0,script='WARP'}}}}}},scripts={
  LOAD={{'setvar',0x400B,11},{'end'}},TRANSITION={{'setvar',0x4064,1},{'end'}},
  RESUME={{'addvar',0x400B,1},{'end'}},WARP={{'setvar',0x400D,13},{'end'}}}}
 VM.register(g.data,'scenes');local scene=Scripts.get(id)
 for _,continuing in ipairs{false,true}do
  local saved=continuing and edition~='emerald'
  local world={gen3RsContinuing=continuing and(edition=='ruby'or edition=='sapphire'),
   gen3FrlgContinuing=continuing and(edition=='firered'or edition=='leafgreen'),queue={}}
  world.runner=R.new(g,world)
  function world:queueScript(rows,ctx)self.queue[#self.queue+1]={rows,ctx}end
  g.save.gen3Vars={[0x4064]=29}
  scene.onEnter(g,world)
  for _,job in ipairs(world.queue)do world.runner:run(job[1],job[2])end
  local nativeOrder=edition=='ruby'or edition=='sapphire'or world.gen3FrlgContinuing
  T.eq(C.getVar(g.save,0x400B),nativeOrder and 12 or 11,'saved field runs LOAD before RESUME regardless of header order')
  T.eq(C.getVar(g.save,0x4064),saved and 29 or 1,'Continue skips fresh-entry TRANSITION')
  T.eq(C.getVar(g.save,0x400D),saved and 0 or 13,'Continue skips warp-into callbacks')
 end
 f.close()
end
for _,edition in ipairs{'firered','leafgreen'}do
 local f=require('tests.checkpoint_fixture').boot(edition,3);local g,w=f.game,f.world
 g.data.constants.gen3FRLGBehaviours={}
 g.save.gen3Vars={[0x4008]=48,[0x4064]=29}
 g.save.flags.FLAG_G3_0011=true;g.save.flags.FLAG_G3_0805=true;g.save.flags.FLAG_G3_0827=true
 local homes={[1]={x=3,y=3}};g.save.gen3ObjectHomes={FIX_TOWN=homes}
 local objects={mapId='FIX_TOWN',[1]=false};g.save.gen3SessionObjects=objects
 w.continuingSave=true;w:setMap('FIX_TOWN',2,3,'down',{via='boot'})
 T.eq(w.gen3FrlgContinuing,true)
 T.eq(g.save.gen3Vars[0x4008],48,'actual Continue preserves temporary field variables')
 T.eq(g.save.gen3Vars[0x4064],29,'permanent scene variable survives')
 T.eq(g.save.flags.FLAG_G3_0011,true,'actual Continue preserves temporary flags')
 T.eq(g.save.flags.FLAG_G3_0805,true,'actual Continue retains active Strength')
 T.eq(g.save.flags.FLAG_G3_0827,true,'badge is permanent')
 T.eq(g.save.gen3ObjectHomes.FIX_TOWN,homes,'saved object templates survive Continue')
 T.eq(g.save.gen3SessionObjects,objects,'saved object removals survive Continue')
 w:setMap('FIX_TOWN',2,3,'down',{via='warp'})
 T.eq(w.gen3FrlgContinuing,nil,'saved-entry mode cannot leak to the next map setup')
 T.eq(g.save.gen3Vars[0x4008],nil,'normal warp clears temporary variables')
 T.eq(g.save.flags.FLAG_G3_0011,nil,'normal warp clears temporary flags')
 T.eq(g.save.flags.FLAG_G3_0805,nil,'normal warp puts Strength down')
 T.eq(g.save.gen3Vars[0x4064],29);T.eq(g.save.flags.FLAG_G3_0827,true)
 w:setMap('FIX_TOWN',2,3,'down',{via='boot'})
 T.eq(g.save.gen3ObjectHomes.FIX_TOWN,nil,'fresh entry restores the map header templates')
 T.eq(g.save.gen3SessionObjects,nil,'fresh entry clears the old removal session')
 f.close()
end
T.finish('Actual FRLG Continue field state, templates and script phases; fresh entry and other editions retained')
