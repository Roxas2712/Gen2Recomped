package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.harness')
love=require('tests.love_stub')
local C=require('src.world.Collision')
for _,version in ipairs({'ruby','sapphire','firered','leafgreen','emerald'})do
  local f=require('tests.api3_contract.npcs').fixture('tests/api3_contract','gen2',version)
  local data=f.game.data
  data.constants=data.constants or {}
  data.constants.gen3BuriedMovement=63;data.constants.gen3HiddenMovement=76
  data.constants.gen3MovementTypes={[8]={facing='down'},[63]={facing='down'},[76]={hides=true}}
  local row={index=2,localId=2,name='BURIED',sprite='PROBE',x=3,y=3,movementType=8}
  local actor=f:make(f.home,row)
  T.check(not actor.hidden and not actor.buried,'ordinary initial template is visible')
  T.check(actor:setMovementType(data,63),'transition applies imported buried movement')
  T.eq(actor.hidden,true,'transition hides already spawned trainer')
  T.eq(actor.buried,true,'hidden reason is available to trainer sight')
  T.check(C.occupied({actor},3,3,f.player),'buried trainer still occupies its actual cell')
  T.eq(row.movementType,8,'movement command never rewrites the imported template')
  actor:setMovementType(data,8)
  T.check(not actor.hidden and not actor.buried,'ordinary re-pose clears the burial reason and visibility')
  actor:setMovementType(data,76)
  T.check(actor.hidden and actor.gen3Hidden and not actor.buried,'invisible Kecleon retains its distinct reason')
  T.eq(C.occupied({actor},3,3,f.player),actor,'invisible Kecleon remains a physical obstacle')
  f.ow.npcs={actor}
  local World=require('src.world.OverworldController')
  T.eq(World.npcAtCell(f.ow,3,3),actor,'invisible Kecleon still answers the Devon Scope interaction')
  actor:setMovementType(data,63)
  T.check(actor.hidden and actor.buried and not actor.gen3Hidden,'invisible-to-buried transition stays hidden')
  actor:setMovementType(data,76)
  T.check(actor.hidden and actor.gen3Hidden and not actor.buried,'buried-to-invisible transition stays hidden')
  actor:setMovementType(data,8)
  T.check(not actor.hidden and not actor.buried and not actor.gen3Hidden,'ordinary type clears movement-derived visibility')
  f.ow.npcByIndex=World.npcByIndex
  require('src.script.Gen3Commands')
  local commands=require('src.script.Commands')
  local ctx={overworld=f.ow,save=f.game.save,mapId=f.home}
  commands.g3_object_invisible(ctx,2)
  T.check(actor.hidden and actor.gen3Invisible,'hideobjectat marks an active invisible object')
  T.eq(C.occupied({actor},3,3,f.player),actor,'script invisibility preserves collision')
  T.eq(World.npcAtCell(f.ow,3,3),actor,'script invisibility preserves interaction')
  commands.g3_object_visible(ctx,2)
  T.check(not actor.hidden and not actor.gen3Invisible,'showobjectat clears only script invisibility')
  actor.hidden=true
  T.eq(C.occupied({actor},3,3,f.player),nil,'removed ordinary figures remain passable')
  T.eq(World.npcAtCell(f.ow,3,3),nil,'removed ordinary figures cannot answer')
  row.movementType=63
  local rebuilt=f:make(f.home,row)
  T.check(rebuilt.hidden and rebuilt.buried,'reconstruction honors a stored buried movement override')
  T.eq(rebuilt.gen3Hidden,nil,'burial never becomes permanent invisibility')
  data.constants.gen3BuriedMovement=nil
  local unknown=f:make(f.home,row)
  T.check(not unknown.hidden and not unknown.buried,'missing ROM derivation never guesses a hidden type')
  f.restoreRenderer()
end
T.finish('five-edition movement-defined buried trainers and hidden-state transitions')
