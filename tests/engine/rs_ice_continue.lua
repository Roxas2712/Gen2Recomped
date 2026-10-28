-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local V=require('src.core.GameVersion')
local C=require('src.script.Gen3Commands')
local Ice=require('src.world.Gen3RsIce')
local Sound=require('src.core.Sound');local play=Sound.playSe
local F=require('tools.battle-source-runtime.fixture')
local R=require('src.script.ScriptRunner')
for _,edition in ipairs{'ruby','sapphire'} do
  local f=F.new(edition);local game=f.game
  local sound,draw={},0;Sound.playSe=function(_,id)sound[#sound+1]=id end
  local cells={};local map={id='MAP_G15_N00',widthCells=17,heightCells=26,def={tileset='ICE'}}
  function map:cellBehaviour(x,y)return cells[y*17+x] or 1 end
  function map:isThinIceCell(x,y)return self:cellBehaviour(x,y)==1 end
  function map:setBlock(x,y,id)cells[y*17+x]=id end
  game.data.constants.gen3Ice={swap={ICE={cracked=2,crackedBehaviour=2,hole=3}},
    fallTrigger={[map.id]={var=0x4022,value=0}}}
  local world={map=map,player={cellX=8,cellY=19},
    redrawBlocks=function()draw=draw+1 end,
    thinIceState=function()game.save.gen3ThinIce=game.save.gen3ThinIce or {};local ice=game.save.gen3ThinIce
      ice[map.id]=ice[map.id] or {};return ice[map.id]end}
  Ice.enter(world,game,false);C.setVar(game.save,0x4022,1)
  local path={{8,19},{9,19},{9,18},{8,18},{7,18},{7,17},{8,17}}
  for i,xy in ipairs(path) do
    world.player.cellX,world.player.cellY=xy[1],xy[2]
    T.eq(Ice.step(world,game),false,'fresh ice allows ordinary walking')
    T.eq(C.getVar(game.save,0x4022),i+1,'each new cell advances the native counter')
    for frame=1,4 do Ice.tick(world,game);T.eq(map:cellBehaviour(xy[1],xy[2]),1,'native delay precedes visible crack') end
    Ice.tick(world,game);T.eq(map:cellBehaviour(xy[1],xy[2]),2)
    T.eq(sound[#sound],'SE_ICE_CRACK','native ice cue accompanies tile swap')
  end
  T.eq(C.getVar(game.save,0x4008),48);T.eq(C.getVar(game.save,0x4009),112)
  T.eq(C.getVar(game.save,0x400A),96)
  local old=game.save.gen3ThinIce[map.id]
  -- Native row masks independently rebuild a fresh map after CONTINUE.
  game.save.gen3ThinIce=nil;cells={};Ice.enter(world,game,true)
  C.SPECIALS[311]({game=game,save=game.save,overworld=world})
  for _,xy in ipairs(path) do T.eq(map:cellBehaviour(xy[1],xy[2]),2,'saved cracks restored') end
  T.eq(map:cellBehaviour(9,17),1,'unvisited cell is untouched')
  T.eq(C.getVar(game.save,0x4022),8,'restoration does not reset puzzle progress')
  world.player.cellX,world.player.cellY=7,17
  T.eq(Ice.step(world,game),true,'stepping on restored cracked ice triggers native fall')
  T.eq(C.getVar(game.save,0x4022),0,'actual map frame table owns falling')
  for frame=1,5 do Ice.tick(world,game) end
  T.eq(map:cellBehaviour(7,17),3);T.eq(sound[#sound],'SE_ICE_BREAK')
  Ice.enter(world,game,false)
  for id=0x4001,0x400A do T.eq(C.getVar(game.save,id),0,'fresh visit resets native row masks') end
  -- An upgrade retains cells witnessed by the previous public fork.
  game.save.gen3RsIceFormat=nil
  for id=0x4001,0x400A do C.setVar(game.save,id,2047) end
  game.save.gen3ThinIce={[map.id]=old};Ice.enter(world,game,true);cells={}
  T.eq(Ice.restore(world,game),true)
  for _,xy in ipairs(path) do T.eq(map:cellBehaviour(xy[1],xy[2]),2,'legacy witnessed cells migrate') end
  T.eq(map:cellBehaviour(3,6),1,'old unrelated temporary variables are not interpreted as ice masks')
  T.eq(game.save.gen3RsIceFormat,1,'migration is explicitly versioned')
  T.check(draw>0)
  map.id='OTHER_MAP';T.eq(Ice.step(world,game),nil);T.eq(Ice.restore(world,game),false)
  f.close()
end
Sound.playSe=play
-- Real lowering/registration/runner: continue runs LOAD and RESUME, while
-- fresh entry also runs TRANSITION and the warp-into table.
for _,edition in ipairs{'ruby','sapphire','emerald','firered','leafgreen'} do
  local f=F.new(edition);local g=f.game;local id='OWNED_ICE_CALLBACK_'..edition
  g.data.map_scripts={source='RomExtractorGen3',maps={[id]={callbacks={
    {type=1,script='LOAD'},{type=3,script='TRANSITION'},{type=5,script='RESUME'}},
    tables={{type=4,rows={{var=0x4023,value=0,script='WARP'}}}}}},scripts={
    LOAD={{'setvar',0x400B,11},{'end'}},TRANSITION={{'setvar',0x4022,1},{'end'}},
    RESUME={{'setvar',0x400C,12},{'end'}},WARP={{'setvar',0x400D,13},{'end'}}}}
  g.data.maps[id]={}
  require('src.script.Gen3ScriptVM').register(g.data,'scenes')
  local scene=require('src.script.MapScripts').get(id)
  for _,continuing in ipairs{false,true} do
    local world={gen3RsContinuing=continuing and (edition=='ruby' or edition=='sapphire'),queue={}}
    world.runner=R.new(g,world)
    function world:queueScript(rows,ctx)self.queue[#self.queue+1]={rows,ctx}end
    g.save.gen3Vars={[0x4022]=29}
    scene.onEnter(g,world)
    for _,job in ipairs(world.queue) do world.runner:run(job[1],job[2]) end
    T.eq(C.getVar(g.save,0x400B),11);T.eq(C.getVar(g.save,0x400C),12)
    T.eq(C.getVar(g.save,0x4022),world.gen3RsContinuing and 29 or 1)
    T.eq(C.getVar(g.save,0x400D),world.gen3RsContinuing and 0 or 13)
  end
  f.close()
end
for _,edition in ipairs{'emerald','firered','leafgreen','gold'} do
  V.set(edition);T.eq(Ice.step({},{}),nil);T.eq(Ice.restore({},{}),false)
end
-- Actual world entry used to clear the saved masks after restoring them.
for _,edition in ipairs{'ruby','sapphire'} do
  local f=require('tests.checkpoint_fixture').boot(edition,3)
  local g,w=f.game,f.world
  g.save.gen3Vars={[0x4008]=48,[0x4022]=29}
  g.save.flags.FLAG_G3_0011=true
  w.continuingSave=true
  w:setMap('FIX_TOWN',2,3,'down',{via='boot'})
  T.eq(g.save.gen3Vars[0x4008],48,'actual CONTINUE map setup preserves saved temporary vars')
  T.eq(g.save.flags.FLAG_G3_0011,true,'actual CONTINUE preserves temporary field flags')
  w:setMap('FIX_TOWN',2,3,'down',{via='warp'})
  T.eq(g.save.gen3Vars[0x4008],nil,'fresh map setup still clears temporary vars')
  T.eq(g.save.flags.FLAG_G3_0011,nil,'fresh map setup still clears temporary flags')
  f.close()
end
T.finish('RS native ice timing, sound, saved row restoration, falls and continue callback phases')
