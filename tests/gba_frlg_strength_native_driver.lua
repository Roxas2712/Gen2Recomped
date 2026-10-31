-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Prepared floor components; the ordinary failing campaign is retained separately.
return function(game)
 local U,J=require('tests.drivers.util'),require('src.link.Json')
 local V=require('src.core.GameVersion');local edition=V.get();assert(V.isFRLG())
 local out=assert(os.getenv('EDITION_QA_OUT'));assert(love.filesystem.getIdentity():match('^oasc%-edition%-qa%-'..edition..'%-'))
 for _,event in ipairs{'keypressed','keyreleased','textinput','gamepadpressed','gamepadreleased',
  'joystickpressed','joystickreleased','joystickaxis','joystickhat','touchpressed','touchreleased',
  'touchmoved','mousepressed','mousereleased'}do love[event]=function()end end
 game.input:reset();U.freshSave(game)
 game.save.party={require('src.pokemon.Pokemon').new(game.data,'BLASTOISE',40)}
 local C=require('src.script.Gen3Commands');local S=require('src.core.SaveSerializer')
 local report={edition=edition,status='running',preparedFixture=true,continuousStory=false,cases={},captures={}}
 local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
 local function shot(name)
  local save,rng=S.encode(game.save),love.math.getRandomState();local top=game.stack:top()
  assert(require('src.render.GraphicsScope').call(top.draw,top));assert(save==S.encode(game.save)and rng==love.math.getRandomState())
  assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
 end
 local function load(mapId,x,y)
  while game.stack:top()do game.stack:pop()end
  game.stack:push(require('src.world.OverworldController'),mapId,x or 1,y or 1,'down')
  local world=game.stack:top()
  -- These components exercise the original floor programs, not incidental
  -- trainer sight or random encounters while preparing their starting cells.
  world.checkTrainerSight=function()return false end
  world.checkTrainerBattle=function()return false end
  world.tryWildEncounter=function()return false end
  U.wait(90);assert(game.stack:top()==world and not world.runner:isRunning())
  return world
 end
 local dirs={{'up',0,-1},{'down',0,1},{'left',-1,0},{'right',1,0}}
 local revealed
 for _,row in ipairs{{'1f','MAP_G01_N39',5,20,16,0x4064},
  {'2f-west','MAP_G01_N40',11,2,19,0x4065},
  {'3f','MAP_G01_N41',7,7,7,0x4067},
  {'3f-hole','MAP_G01_N41',8,34,18},
  {'2f-east','MAP_G01_N40',12,14,19,0x4066}}do
  local name,mapId,index,tx,ty,var=unpack(row)
  if var then C.setVar(game.save,var,0)end
  local world=load(mapId);local npc=assert(world:npcByIndex(index),'Native fixture boulder absent: '..name)
  assert(npc.def.graphicsId==97)
  if name=='2f-east'then
   assert(revealed and not game.save.flags[revealed],'Fallen upper stone did not reveal its lower-floor partner')
   assert(npc.cellX==33 and npc.cellY==19,'Original lower-floor spawn differs')
  end
  local wanted=var and 0x20 or 0x66
  assert(world.map:sourceBehaviourAt(tx,ty)==wanted,'Original native floor behavior differs')
  local function free(x,y)
   if not world.map:inBounds(x,y)or not world.map:isWalkableCell(x,y)or world.map:isWarpTileCell(x,y)then return false end
   for _,e in ipairs(world.entities)do if e~=npc and e~=world.player and e.cellX==x and e.cellY==y then return false end end
   return true
  end
  local stand
  for _,d in ipairs(dirs)do
   local bx,by,sx,sy=tx-d[2],ty-d[3],tx-2*d[2],ty-2*d[3]
   if free(bx,by)and free(sx,sy)and world.map:arrowWarpDirAt(sx,sy)~=d[1]then stand={d[1],bx,by,sx,sy};break end
  end
  assert(stand,'No native push approach for '..name)
  local dir,bx,by,sx,sy=unpack(stand)
  npc.cellX,npc.cellY,npc.px,npc.py,npc.moving=bx,by,bx*16,by*16,false
  npc.gen3Elevation=world.map:cellElevation(bx,by);npc.progress=16
  local p=world.player;p.cellX,p.cellY,p.px,p.py,p.facing=sx,sy,sx*16,sy*16,dir
  p.elevation=world.map:cellElevation(sx,sy);p.moving=false;p.inputLocked=false;p.turnTimer=0
  world.lastCellX,world.lastCellY=sx,sy
  game.save.flags.FLAG_G3_0805=true
  local barrier=name=='1f'and{world.map:blockAt(12,14),world.map:blockAt(12,15)}or nil
  if not var then
   revealed=('FLAG_G3_%04X'):format(npc.def.trainerType)
   assert(npc.def.trainerType>0 and npc.def.trainerType~=npc.def.trainerRange)
   game.save.flags[revealed]=true
  end
  game.input:overlayPressed(dir);U.wait(1);game.input:overlayReleased(dir);U.wait(150)
  for _=1,600 do if game.stack:top()==world and not world.runner:isRunning()and #world.scriptMoves==0 then break end;U.wait(1)end
  assert(game.stack:top()==world and not world.runner:isRunning(),'Native floor script did not finish')
  if var then
   assert(npc.cellX==tx and npc.cellY==ty,'Normal push did not reach the original button')
   assert(C.getVar(game.save,var)==100,'Native Strength button script did not activate: '..name)
   if barrier then assert(world.map:blockAt(12,14)~=barrier[1]and world.map:blockAt(12,15)~=barrier[2],'Native rock barrier did not open')end
  else
   assert(not world:npcByIndex(index),'Fallen stone remains active')
   assert(not game.save.flags[revealed],'Native trainerType reveal flag was not cleared')
  end
  shot('native-strength-'..name)
  report.cases[#report.cases+1]={name=name,map=mapId,index=index,target={tx,ty},variable=var,
   value=var and C.getVar(game.save,var)or nil,revealFlag=not var and revealed or nil,direction=dir};persist()
  if barrier then
   world=load(mapId,13,14)
   assert(C.getVar(game.save,var)==100 and world:npcByIndex(index).cellX==tx and world:npcByIndex(index).cellY==ty,'Native switch/permanent boulder position did not survive map reload')
   assert(world.map:blockAt(12,14)~=barrier[1]and world.map:blockAt(12,15)~=barrier[2])
   shot('native-strength-1f-barrier-after-reload')
  end
 end
 report.drawPreservesSaveRng=true;report.status='pass';persist()
 print('PASS_NATIVE_FRLG_STRENGTH_FLOORS '..edition);love.event.quit(0)
end
