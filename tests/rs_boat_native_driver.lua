-- Prepared native Route104 boarding fixture, not a continuous story claim.
return function(game)
  local U=require('tests.drivers.util');local J=require('src.link.Json')
  local Music=require('src.core.Music');local Commands=require('src.script.Commands')
  local edition=require('src.core.GameVersion').get();local out=assert(os.getenv('EDITION_QA_OUT'))
  assert(edition=='ruby'or edition=='sapphire')
  assert(love.filesystem.getIdentity():match('^oasc%-edition%-qa%-'..edition..'%-'))
  for _,event in ipairs({'keypressed','keyreleased','textinput','gamepadpressed','gamepadreleased',
    'joystickpressed','joystickreleased','touchpressed','touchreleased','mousepressed','mousereleased'})do
    love[event]=function()end
  end
  local report={edition=edition,status='running',preparedBoatFixture=true,continuousStory=false,
    captures={},maps={},cases={},samples=0,maxPixelGapError=0}
  -- Independent ROM-byte timing oracle for this native movement list.
  local rf=assert(io.open(assert(os.getenv('POKEPORT_IMPORT_ROM')),'rb'))
  local rom=rf:read('*a');rf:close()
  local at=edition=='ruby'and 0x14F09F or 0x14F033
  local expectedFrames,tiles=0,0
  for offset=0,256 do
    local action=rom:byte(at+offset+1);if action==0xFE then break end
    local frames=(action>=8 and action<=11)and 16
      or(action>=0x15 and action<=0x18)and 8
      or(action>=0x2D and action<=0x30)and 4
    assert(frames,'Unexpected action in independent native boat path')
    expectedFrames=expectedFrames+frames;tiles=tiles+1
  end
  assert(tiles==194);report.nativeMovementTiles=tiles;report.nativeMovementFrames=expectedFrames
  local function persist()
    local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()
  end
  local function shot(name)
    assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name
  end
  persist();U.freshSave(game);U.teleport(game,'MAP_G00_N19',13,51,'down');U.wait(120)
  local world=game.overworld;local ctx=world.runner:makeContext()
  Commands.g3_show_object(ctx,7);Commands.g3_show_object(ctx,8)
  game.save.gen3Vars=game.save.gen3Vars or {};game.save.gen3Vars[16526]=1
  local boat=assert(world:npcByIndex(7));local boatId=boat.id
  local seen={};local arrival=false
  for frame=1,3600 do
    U.wait(1)
    local held=game.save.flags.FLAG_G3_4001
    if held then
      assert(Music.current()=='SONG_1AF','Native sailing music replaced on '..world.map.id)
      assert(world.player.hidden,'Player visible during native boat trip')
      local count=0;for _,e in ipairs(world.entities)do if e==boat then count=count+1 end end
      assert(count==1,'Boat missing/duplicated from final renderer entities')
      for _,g in ipairs(world.ghosts)do assert(g.npc~=boat,'Boat also updates as an old-map ghost')end
      local moving=world.runner.ctx and world.runner.ctx.g3Moving
      if not report.cases.originalMovementByteTiming and moving and moving[7]then
        local frames,count=0,0
        for _,step in ipairs(moving[7].steps)do
          assert(step.kind=='walk');count=count+step.count
          frames=frames+step.count*16*(step.rate or 1)
        end
        assert(count==tiles and frames==expectedFrames,'Cached action names lost native sailing speed')
        report.cases.originalMovementByteTiming=true
      end
      -- The player takes a separate step off the boat before releasing BGM.
      if moving and moving[7]and not moving[7].done then
        local dx=(boat.px or 0)-world.player.px
        local dy=(boat.py or 0)-world.player.py-16
        local err=math.max(math.abs(dx),math.abs(dy));report.maxPixelGapError=math.max(report.maxPixelGapError,err)
        assert(err<=8,('Boat/player movement drift: %s gap %.1f,%.1f'):format(world.map.id,dx,dy))
      end
      report.samples=report.samples+1
      local map=world.map.id
      if not seen[map]then
        seen[map]=true;report.maps[#report.maps+1]={id=map,frame=frame,song=Music.current(),boatId=boatId}
        shot('sailing-'..map);persist()
      end
    elseif seen.MAP_G00_N11 and game.stack:top()~=world then arrival=true;break end
  end
  assert(arrival and report.samples>500,'Native trip did not reach its landing dialogue')
  assert(seen.MAP_G00_N19 and seen.MAP_G00_N20 and seen.MAP_G00_N21 and seen.MAP_G00_N11)
  assert(Music.current()=='SONG_1AB'and not world.player.hidden)
  shot('dewford-landing-dialogue')
  for _=1,40 do
    if game.stack:top()==world and not world.runner:isRunning()then break end
    game.input:overlayPressed('a');U.wait(1);game.input:overlayReleased('a');U.wait(30)
  end
  assert(game.stack:top()==world and not world.runner:isRunning()and #world.scriptMoves==0)
  assert(world.map.id=='MAP_G00_N11'and world.player.cellX==11 and world.player.cellY==9)
  assert(game.save.gen3Vars[16526]==0 and not game.save.flags.FLAG_G3_4001)
  assert(boat.hidden or not world.npcPool[boatId]or not(function()
    for _,e in ipairs(world.entities)do if e==boat then return true end end
  end)(),'Departed-map boat still visible beside the destination boat')
  report.cases.nativeSailingCueAcrossFourMaps=true
  report.cases.pairedNativeSpeedsAndSingleActor=true
  report.cases.nativeLandingAndMusicRelease=true
  shot('dewford-after-landing')
  -- The next ordinary movement must leave the dock on land, not strand the
  -- player at the water/land elevation boundary.
  game.input:overlayPressed('left')
  for _=1,120 do U.wait(1);if world.player.cellX~=11 then break end end
  game.input:overlayReleased('left');U.wait(35)
  assert(world.player.cellX==10 and world.player.cellY==9 and not world.player.moving)
  report.cases.dockExit=true
  report.status='pass';persist();print('PASS_RS_BOAT_NATIVE',edition);love.event.quit(0)
end
