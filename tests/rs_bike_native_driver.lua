-- Prepared riding/hop consumer checks; this is not ordinary story progress.
return function(game)
  local U=require('tests.drivers.util');local J=require('src.link.Json')
  local Save=require('src.core.SaveSerializer');local Sound=require('src.core.Sound')
  local out=assert(os.getenv('EDITION_QA_OUT'));local version=require('src.core.GameVersion').get()
  assert(love.filesystem.getIdentity():match('^oasc%-edition%-qa%-'..version..'%-'))
  assert(require('src.import.RomImporter').readyReport(version).ok)
  local bike=game.data.constants.gen3Bike;assert(require('src.import.Gen3RsBike').valid(bike,version))
  for _,event in ipairs({'keypressed','keyreleased','textinput','gamepadpressed',
    'gamepadreleased','joystickpressed','joystickreleased','joystickaxis','joystickhat',
    'touchpressed','touchreleased','touchmoved','mousepressed','mousereleased'})do love[event]=function()end end
  game.input:reset()
  local report={edition=version,status='running',preparedBikeFixture=true,continuousStory=false,
    rules=bike.rules,cases={},captures={},hopSounds=0,drawSaveAndRngPreserved=true}
  local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
  local function shot(name)
    local before=Save.encode(game.save);local rng=love.math.getRandomState()
    assert(require('src.render.GraphicsScope').call(function()game.stack:top():draw()end))
    assert(before==Save.encode(game.save)and rng==love.math.getRandomState(),'Bike draw changed save/RNG')
    assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
  end
  persist();U.freshSave(game)
  game.save.party={require('src.pokemon.Pokemon').new(game.data,'GROVYLE',22)}
  local function mount(kind)
    game.input:reset();game.save.onBike=false;game.save.bikeKind=nil
    U.teleport(game,'MAP_G00_N01',20,28,'right');U.wait(60)
    local w=game.overworld;assert(w:bikeAllowed(w.map.id))
    local action,value=require('src.inventory.ItemEffects').use(game.data,game.save,
      kind=='mach'and 'MACH_BIKE'or 'ACRO_BIKE',nil,false,nil,w)
    assert(action=='bicycle'and value==kind,'Native bike item did not dispatch')
    game.save.onBike=true;game.save.bikeKind=value;U.wait(1)
    assert(w.player.onBike and (kind=='mach'and w.player.machBike or w.player.acroBike))
    return w
  end
  local function ride(w,dir,steps,keepHeld)
    local rows={};local p=w.player;local active=false;local finished=0
    game.input:overlayPressed(dir)
    for _=1,1200 do
      U.wait(1)
      assert(game.stack:top()==w and not w.runner:isRunning(),'Unexpected prepared riding event')
      if p.moving and not active then
        active=true;rows[#rows+1]={frames=p.stepFramesCur,speed=w:playerSpeed(),counter=p.bikeCounter}
        assert(p.stepFramesCur==bike.rules.speedFrames[w:playerSpeed()],'Imported speed did not reach the actual step')
      elseif active and not p.moving then
        active=false;finished=finished+1
        if finished==steps then break end
      end
    end
    if finished~=steps then
      local ok,why=require('src.world.Collision').canMove(w.map,w.entities,p,dir)
      report.failedRide={dir=dir,finished=finished,steps=steps,x=p.cellX,y=p.cellY,
        moving=p.moving,facing=p.facing,turnTimer=p.turnTimer,counter=p.bikeCounter,
        held=game.input:isDown(dir),canMove=ok,why=why,rows=rows}
      shot('bike-native-failed-ride');error('Prepared bike ride did not complete: '..J.encode(report.failedRide))
    end
    if not keepHeld then game.input:overlayReleased(dir);U.wait(4)end
    return rows
  end
  local function coast(w,held)
    game.input:overlayReleased(held)
    local p=w.player;local rows={};local active=false;local finished=0
    for _=1,160 do
      U.wait(1)
      assert(game.stack:top()==w and not w.runner:isRunning(),'Unexpected coasting event')
      if p.moving and not active then
        active=true;rows[#rows+1]={frames=p.stepFramesCur,x=p.cellX,y=p.cellY,targetX=p.targetX,targetY=p.targetY}
      elseif active and not p.moving then active=false;finished=finished+1 end
      if not p.moving and p.rsMachRunning=='still'then break end
    end
    assert(not p.moving and p.rsMachRunning=='still'and p.bikeCounter==0 and p.rsMachSpeed==0,
      'Native coast did not stop at a tile boundary')
    assert(finished==#rows,'Last coasting tile did not land')
    return rows
  end
  local w=mount('mach');shot('bike-native-mach-standing')
  report.machSteps=ride(w,'right',6,true)
  assert(report.machSteps[1].frames==16 and report.machSteps[6].frames==4,'Mach bike did not accelerate')
  for i,value in ipairs({16,8,4,4,4,4})do
    assert(report.machSteps[i].frames==value,'Mach acceleration is one tile late at '..i)
  end
  local middle=false;for _,r in ipairs(report.machSteps)do if r.frames==8 then middle=true end end
  assert(middle and w.player.bikeCounter==2,'Mach middle speed or full acceleration missing')
  report.machCoast=coast(w,'right')
  assert(#report.machCoast==3,'Top speed must coast across three more real tiles')
  for i,frames in ipairs({4,8,16})do
    assert(report.machCoast[i].frames==frames,'Native coast duration '..i)
    assert(report.machCoast[i].targetX==report.machCoast[i].x+1,'Coast must physically advance')
  end
  report.cases.machDistinctSpeedsAndCoast=true;shot('bike-native-mach-after-run')
  w=mount('mach');ride(w,'left',3,true)
  assert(w.player.bikeCounter==2,'Prepared turn must start from a real accelerated run')
  assert(require('src.world.Collision').canMove(w.map,w.entities,w.player,'up'),
    'The prepared corner must be free of scenery and NPCs')
  game.input:overlayReleased('left')
  report.machTurn=ride(w,'up',1,true)
  assert(report.machTurn[1].frames==4,'A continuously moving corner must retain full speed')
  report.cases.machMovingTurnKeepsSpeed=true;shot('bike-native-mach-after-turn')
  -- Stop in the open straight corridor, then turn from a genuine standstill.
  w=mount('mach');ride(w,'right',3,true);coast(w,'right')
  assert(require('src.world.Collision').canMove(w.map,w.entities,w.player,'left'))
  local x,y=w.player.cellX,w.player.cellY
  game.input:overlayPressed('left');U.wait(1)
  assert(not w.player.moving and w.player.facing=='left'and w.player.turnTimer>0
    and w.player.cellX==x and w.player.cellY==y,'Standing turn must not start a tile')
  game.input:overlayReleased('left');U.wait(12)
  report.standingTurn=ride(w,'left',1,true)
  assert(report.standingTurn[1].frames==16,'A standing turn must restart at the first rung')
  game.input:overlayReleased('left');U.wait(20)
  report.cases.machStandingTurnRestarts=true;shot('bike-native-mach-after-standing-turn')
  w=mount('mach');ride(w,'right',2,true)
  for _=1,20 do U.wait(1);if w.player.moving then break end end
  assert(w.player.moving and w.player.stepFramesCur==4,'Release fixture must be inside the third real tile')
  report.midStepRelease=coast(w,'right')
  assert(#report.midStepRelease==4,'Mid-tile release must finish that tile and all three coast tiles')
  for i,frames in ipairs({4,4,8,16})do
    assert(report.midStepRelease[i].frames==frames,'Mid-tile release changed a movement duration')
  end
  report.cases.midStepReleaseCompletesTileAndCoasts=true;shot('bike-native-mid-step-release-rest')
  w=mount('mach')
  local distance=0;local p=w.player;local Collision=require('src.world.Collision')
  for i=1,30 do
    local mover=setmetatable({cellX=p.cellX+i-1,cellY=p.cellY,elevation=p.elevation},{__index=p})
    if not Collision.canMove(w.map,w.entities,mover,'right')then break end
    distance=i
  end
  assert(distance>=3 and distance<30,'The prepared collision needs an actual acceleration corridor')
  ride(w,'right',distance,true)
  assert(w.player.bikeCounter==2,'Collision must start from a real run')
  assert(not Collision.canMove(w.map,w.entities,w.player,'right'),'The corridor must end at an obstacle')
  local x,y=w.player.cellX,w.player.cellY
  U.wait(50) -- Keep the SAME direction held: a turn must not clear this run.
  assert(not w.player.moving and w.player.cellX==x and w.player.cellY==y
    and w.player.bikeCounter==0,'Straight collision retained the old Mach run')
  game.input:overlayReleased('right');U.wait(3)
  report.cases.machCollisionClearsRun=true;shot('bike-native-mach-after-collision')
  w=mount('acro');report.acroSteps=ride(w,'right',4)
  for _,r in ipairs(report.acroSteps)do assert(r.frames==6,'Acro bike must keep its own pace')end
  report.cases.acroConstantSpeed=true;shot('bike-native-acro-after-run')
  w=mount('acro');local play=Sound.playId
  Sound.playId=function(data,id,...)
    local source=play(data,id,...)
    if data==game.data and id==bike.rules.acroHopSound then
      assert(source,'Native hop sound missing');report.hopSounds=report.hopSounds+1
    end
    return source
  end
  game.input:overlayPressed('b');U.wait(1)
  assert(w.player.acroState=='wheelieStanding'and report.hopSounds==0)
  shot('bike-native-acro-wheelie')
  -- Captures consume frames: wait against the actual held count instead of
  -- assuming a screenshot is instantaneous in the fixed-step coroutine.
  for _=1,100 do
    if w.player.acroState=='bunnyHop'then break end
    assert((w.player.acroHold or 0)<bike.rules.acroHopFrames,'Hop failed at the native threshold')
    U.wait(1)
  end
  assert(w.player.acroState=='bunnyHop'and w.player.acroHold>=40 and report.hopSounds>=1)
  shot('bike-native-acro-bunny-hop');U.wait(24)
  assert(report.hopSounds>=3,'Standing bunny hop did not repeat its real sound')
  game.input:overlayReleased('b');U.wait(3)
  assert(w.player.acroState=='normal'and not w.player.acroTrick and not w.player.acroHopClock)
  report.cases.delayedWheelieHopSoundAndRelease=true;shot('bike-native-acro-released')
  Sound.playId=play;game.save.onBike=false;U.wait(1)
  assert(w:bikeFrames()==nil,'Dismount retained bike movement speed')
  report.cases.dismountRestoresFoot=true
  local spec=assert(game.data.constants.gen3RsBikeSprites)
  assert(require('src.import.Gen3RsBikeSprites').valid(spec,version))
  local View=require('src.world.Gen3RsBikeView')
  for _,gender in ipairs({'boy','girl'})do
    game.save.player.gender=gender
    for _,kind in ipairs({'mach','acro'})do
      w=mount(kind)
      local sprite,frame,flip=View.pose(w.player,game.save)
      assert(sprite and sprite.def.image==spec.avatars[gender][kind].image)
      local actual,_,_,_,actualFrame,actualFlip=w.player:pose()
      assert(actual==sprite and actualFrame==frame and actualFlip==flip,'Player pose bypassed native bicycle graphics')
      shot('bike-'..gender..'-'..kind..'-native-body')
    end
    for _,dir in ipairs({'down','up','left','right'})do
      w.player.facing=dir;game.input:overlayPressed('b');U.wait(12)
      local body,frame,flip,role=View.pose(w.player,game.save)
      assert(role=='wheelie'and frame==({down=10,up=14,left=18,right=18})[dir]
        and flip==(dir=='right'),'Wrong native held wheelie frame or mirror')
      assert(body:reflectionImage():getHeight()==body.image:getHeight(),'Reflection lost native trick frames')
      shot('bike-'..gender..'-wheelie-'..dir)
      game.input:overlayReleased('b');U.wait(10)
    end
  end
  report.cases.nativeBodiesForBothGendersAndBikes=true
  report.cases.nativeWheeliesAllDirectionsAndReflections=true
  U.freshSave(game);game.save.money=1000
  local mon=require('src.pokemon.Pokemon').new(game.data,'GROVYLE',24);mon.hp=0;mon.status='PAR'
  game.save.party={mon};game.save.inventory={POKE_BALL=21}
  game.save.gen3RespawnIndex=15;game.save.gen3Vars=game.save.gen3Vars or{}
  game.save.gen3Vars[16534]=2 -- native backed-up Mr. Briney location: Dewford
  game.save.flags.FLAG_G3_02E4=true;game.save.flags.FLAG_G3_02E7=true
  game.save.flags.UNRELATED_RECOVERY_SENTINEL=true
  assert(game.data.constants.gen3HealLocations[15].map=='MAP_G00_N11')
  U.teleport(game,'MAP_G09_N12',3,3,'left');U.wait(60)
  w=game.overworld;shot('whiteout-before-native-reset')
  w:afterBattle('lose')
  for _=1,1200 do
    U.wait(1);w=game.overworld
    if w.map.id=='MAP_G00_N11'and not w.transitioning and not w.runner:isRunning()
      and game.stack:top()==w and not w.player.moving then break end
  end
  assert(w.map.id=='MAP_G00_N11'and not w.transitioning,'Native whiteout did not land on Dewford')
  local found=false
  for _,e in ipairs(w.entities)do
    if e.def and e.def.script==game.data.constants.gen3RsWhiteout.brineyDewfordScript then found=true end
  end
  assert(found and not game.save.flags.FLAG_G3_02E4 and not game.save.flags.FLAG_G3_02E7,
    'Native whiteout left Mr. Briney hidden on Dewford')
  assert(game.save.money==500 and game.save.party[1].hp==game.save.party[1].stats.hp
    and not game.save.party[1].status,'Normal blackout healing/money was bypassed')
  assert(game.save.inventory.POKE_BALL==21 and game.save.flags.UNRELATED_RECOVERY_SENTINEL)
  report.cases.whiteoutRestoresDewfordFerry=true
  report.cases.whiteoutPreservesNormalRecoveryAndUnrelatedState=true
  shot('whiteout-after-native-reset-briney-restored')
  report.status='pass';persist();love.event.quit(0)
end
