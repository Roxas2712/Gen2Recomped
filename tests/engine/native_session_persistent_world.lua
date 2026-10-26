-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Session=require('src.compat.gen1.NativeSession')
local _,imageFile=require('tools.sprite-runtime.cpu-gpu').install(love)
imageFile('assets/generated/persistent-world-fixture.png',16,16,string.rep('\255',16*16*4))
for _,edition in ipairs{'firered','leafgreen','emerald','ruby','sapphire'}do
  local fixture=require('tools.session-runtime.fixture').new(edition)
  local game,world,player=fixture.game,fixture.world,fixture.player
  world.busy=function()return false end
  local g,w,p=Session.resolve();T.eq(g,game);T.eq(w,world);T.eq(p,player)
  T.eq(Session.acceptsInput(game,world,player),true,'ordinary native stack remains eligible')
  local stack=game.stack;stack.states={};stack:setWorldOwner({})
  world.enter=false -- avoid importing a map in this native admission fixture
  stack:push(world)
  T.eq(#stack.states,0,'persistent world is not a physical overlay')
  T.eq(stack.worldState,world);T.eq(stack:active(),world)
  g,w,p=Session.resolve()
  T.eq(g,game,'persistent native world resolves the current game')
  T.eq(w,world,'the admitted persistent world supplies observations')
  T.eq(p,player,'persistent world resolves the actual native player')
  T.eq(Session.acceptsInput(game,world,player),true,'active persistent world accepts native input')
  local cover={};stack:push(cover)
  g,w,p=Session.resolve();T.eq(g,game);T.eq(w,world);T.eq(p,player)
  T.eq(Session.acceptsInput(game,world,player),false,'a covering native UI still owns input')
  stack:pop();T.eq(Session.acceptsInput(game,world,player),true)
  game.data.pokemon={[1]={spriteFront='assets/generated/persistent-world-fixture.png'}}
  local strip={width=256,height=80,indexed=string.rep('\1',256*80),palette={}}
  for i=1,16 do strip.palette[i]=i end
  game.data.constants.gen3FieldMovePresentation={schema=1,edition=edition,romSha1=require('src.core.GameVersion').info(edition).sha1,strips={outdoors=strip,indoors=strip}}
  local show=require('src.core.game3.field_move_show_mon')
  T.eq(show.start(1,{pose=true}),true,'native field-move requests reach an admitted persistent world')
  T.eq(stack.worldState,world);T.eq(#stack.states,1)
  T.eq(player.fieldMove,true);show.reset()
  T.eq(stack.worldState,world);T.eq(#stack.states,0)
  T.eq(Session.acceptsInput(game,world,player),true,'retiring a native cut-in returns input to the persistent world')
  game.overworld={isOverworld=true,player={},map=fixture.map}
  T.eq(select(2,Session.resolve()),world,'an unadmitted convenience pointer cannot replace the native world')
  T.eq(show.start(1,{pose=true}),true,'field move uses the admitted world under an unrelated convenience view')
  T.eq(player.fieldMove,true);T.eq(game.overworld.player.fieldMove,nil)
  T.eq(stack:top().actor,player);show.reset();T.eq(player.fieldMove,nil)
  game.overworld=world
  local original=game.data
  game.data={maps={TEST={}},constants={}}
  T.eq(Session.resolve(),nil,'persistent worlds from a retired dataset remain unavailable')
  T.eq(Session.acceptsInput(game,world,player),false)
  game.data=original;stack.worldState=nil
  T.eq(Session.resolve(),nil,'a modern empty stack cannot revive an unadmitted overworld pointer')
  stack.worldState=world
  T.raises(function()Session.withWorld(game,world,function()error('scope probe')end)end,'scope probe','native world scopes restore after failure')
  T.eq(select(2,Session.resolve()),world)
  game.stack=nil
  T.eq(select(2,Session.resolve()),world,'legacy tool hosts without a state list retain their explicit world fallback')
end
T.finish('native persistent-world resolution and input ownership')
