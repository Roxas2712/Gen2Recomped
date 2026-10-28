-- Prepared physical terrain fixture; never ordinary story progress.
return function(game)
  local U=require('tests.drivers.util');local J=require('src.link.Json')
  local Save=require('src.core.SaveSerializer');local Collision=require('src.world.Collision')
  local edition=require('src.core.GameVersion').get();local out=assert(os.getenv('EDITION_QA_OUT'))
  assert(require('src.import.RomImporter').readyReport(edition).ok)
  local ice=assert(game.data.constants.gen3Ice)
  assert(require('src.import.Gen3RsTerrain').valid(ice.nativeRsTerrain,edition))
  local report={edition=edition,status='running',preparedTerrainFixture=true,continuousStory=false,
    captures={},cases={},drawSaveAndRngPreserved=true,predicates=ice.nativeRsTerrain}
  local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
  local function shot(name)
    local before=Save.encode(game.save);local rng=love.math.getRandomState()
    assert(require('src.render.GraphicsScope').call(function()game.stack:top():draw()end))
    assert(before==Save.encode(game.save)and rng==love.math.getRandomState(),'Terrain draw changed save/RNG')
    assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
  end
  persist();local pairsChecked=0
  for _,tile in pairs(game.data.tilesets)do
    if type(tile)=='table'and tile.behaviourBytes then
      assert(#tile.iceBehaviours==2 and tile.iceBehaviours[1]==0x20 and tile.iceBehaviours[2]==0x48)
      assert(tile.thinIceBehaviour==0x26)
      assert(#tile.crackedFloorBehaviours==2 and tile.crackedFloorBehaviours[1]==0xD2 and tile.crackedFloorBehaviours[2]==0x66)
      pairsChecked=pairsChecked+1
    end
  end
  assert(pairsChecked==55,'Expected all native RS tileset pairs');report.tilesetPairsChecked=pairsChecked
  report.cases.allPairsUseCartridgePredicates=true
  U.freshSave(game);game.save.party={require('src.pokemon.Pokemon').new(game.data,'GROVYLE',18)}
  U.teleport(game,'MAP_G24_N08',25,13,'down');U.wait(120)
  local w=game.overworld;local map=w.map;assert(map.id=='MAP_G24_N08')
  local dirs={{'up',0,-1},{'down',0,1},{'left',-1,0},{'right',1,0}};local target
  for y=1,map.heightCells-2 do for x=1,map.widthCells-2 do
    if not target and map:cellBehaviour(x,y)==0xD2 then
      for _,d in ipairs(dirs)do
        local sx,sy=x-d[2],y-d[3]
        local elevation=map:cellElevation(sx,sy);local destElevation=map:cellElevation(x,y)
        if map:isWalkableCell(sx,sy)and map:cellBehaviour(sx,sy)~=0xD2
          and not map:isIceCell(sx,sy)and (elevation==0 or elevation==3)
          and (destElevation==0 or destElevation==3)then
          local mover=setmetatable({cellX=sx,cellY=sy,elevation=3},{__index=w.player})
          if Collision.mayEnter(map,w.entities,mover,x,y,d[1])then
            target={x=x,y=y,sx=sx,sy=sy,dir=d[1]};break
          end
        end
      end
    end
  end end
  assert(target,'No accessible cracked-floor movement fixture')
  U.teleport(game,'MAP_G24_N08',target.sx,target.sy,target.dir);U.wait(100)
  w=game.overworld;map=w.map
  assert(map:cellBehaviour(target.x,target.y)==0xD2 and not map:isIceCell(target.x,target.y))
  assert(map:isCrackedFloorCell(target.x,target.y))
  report.fixture=target;shot('terrain-native-granite-before-cracked-step')
  local beforeX,beforeY=w.player.cellX,w.player.cellY
  game.input:overlayPressed(target.dir)
  for _=1,60 do
    U.wait(1)
    if w.player.moving or w.player.cellX~=beforeX or w.player.cellY~=beforeY then break end
  end
  game.input:overlayReleased(target.dir)
  for _=1,160 do
    assert(not w.iceSlide,'Native cracked floor was treated as sliding ice')
    U.wait(1)
    if not w.player.moving and game.stack:top()==w then break end
  end
  U.wait(80);assert(not game.overworld.iceSlide)
  assert(w.player.cellX~=beforeX or w.player.cellY~=beforeY,'The actual movement never started')
  report.after={map=game.overworld.map.id,x=game.overworld.player.cellX,y=game.overworld.player.cellY,
    iceSlide=game.overworld.iceSlide or false,scriptRunning=game.overworld.runner and game.overworld.runner:isRunning()or false}
  report.cases.crackedFloorDoesNotSlide=true
  local below=assert(ice.holeBelow.MAP_G24_N08)
  for _=1,1800 do
    local world=game.overworld
    assert(not world.iceSlide,'Fall path started an ice slide')
    if world.map.id==below and not world.transitioning and not world.runner:isRunning()
      and not world.player.moving and game.stack:top()==world then break end
    U.wait(1)
  end
  w=game.overworld
  assert(w.map.id==below and not w.transitioning and not w.runner:isRunning()
    and not w.player.moving and game.stack:top()==w,'Cracked floor did not finish its native scripted fall')
  report.landed={map=w.map.id,x=w.player.cellX,y=w.player.cellY}
  shot('terrain-native-granite-after-scripted-fall');report.cases.nativeFloorFallFollowsMapScript=true
  local walk
  for _,d in ipairs(dirs)do
    local x,y=w.player.cellX+d[2],w.player.cellY+d[3]
    if w.map:isWalkableCell(x,y)and not w.map:isCrackedFloorCell(x,y)
      and Collision.mayEnter(w.map,w.entities,w.player,x,y,d[1])then walk={x=x,y=y,dir=d[1]};break end
  end
  assert(walk,'No accessible landing step')
  game.input:overlayPressed(walk.dir)
  for _=1,90 do U.wait(1);if w.player.moving then break end end
  game.input:overlayReleased(walk.dir)
  for _=1,120 do U.wait(1);if not w.player.moving then break end end
  assert(w.player.cellX==walk.x and w.player.cellY==walk.y,'Player input did not resume after native floor fall')
  report.walkAfterFall=walk;report.cases.playerCanWalkAfterFall=true
  shot('terrain-native-granite-walk-after-fall')
  local source=game.data.tilesets[game.data.maps.MAP_G24_N08.tileset]
  for _,b in ipairs({0x45,0x46,0x47})do
    local probe=setmetatable({tileset=source,cellBehaviour=function()return b end},require('src.world.Map'))
    assert(not probe:isCrackedFloorCell(0,0),'Directional floor falsely classified as cracked')
  end
  report.cases.directionalSlidesAreNotCrackedFloor=true
  report.status='pass';persist();love.event.quit(0)
end
