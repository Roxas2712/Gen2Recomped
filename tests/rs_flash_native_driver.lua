-- Prepared field-lighting fixture; no continuous story claim.
return function(game)
  local U=require('tests.drivers.util');local J=require('src.link.Json')
  local F=require('src.world.Gen3Flash');local Serialize=require('src.core.SaveSerializer')
  local edition=require('src.core.GameVersion').get();local out=assert(os.getenv('EDITION_QA_OUT'))
  assert(edition=='ruby'or edition=='sapphire')
  assert(love.filesystem.getIdentity():match('^oasc%-edition%-qa%-'..edition..'%-'))
  for _,event in ipairs({'keypressed','keyreleased','textinput','gamepadpressed','gamepadreleased',
    'joystickpressed','joystickreleased','touchpressed','touchreleased','mousepressed','mousereleased'})do love[event]=function()end end
  local report={edition=edition,status='running',preparedFlashFixture=true,continuousStory=false,
    cases={},captures={},drawSaveAndRngPreserved=true}
  local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
  local function shot(name)
    local before=Serialize.encode(game.save);local rng=love.math.getRandomState()
    local ok,why=require('src.render.GraphicsScope').call(game.overworld.draw,game.overworld);assert(ok,why)
    assert(before==Serialize.encode(game.save)and rng==love.math.getRandomState(),'Flash draw changed save/RNG')
    assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
  end
  persist();assert(require('src.import.RomImporter').readyReport(edition).ok)
  local r=assert(F.record(game.data));assert(r.rsVersion==edition and r.rsFormat==1)
  local file=assert(io.open(assert(os.getenv('POKEPORT_IMPORT_ROM')),'rb'));local rom=file:read('*a');file:close()
  local function u16(at)local lo,hi=rom:byte(at+1,at+2);return lo+hi*256 end
  local rad=edition=='ruby'and 0x39ACDC or 0x39AB24
  local mx=edition=='ruby'and 0x39ACE8 or 0x39AB30
  assert(u16(mx)==4 and u16(mx+2)==0 and #r.radii==5)
  for level=0,4 do assert(r.radii[level+1]==u16(rad+level*2))end
  assert(u16(rad+10)==0 and r.maxLevel==4 and r.dark==4 and r.lit==1)
  assert(r.flag=='FLAG_G3_0828'and r.flagNumber==0x828)
  assert(rom:sub(0x53C98+1,0x53C98+76):find(string.char(0x28,8,0,0),1,true))
  report.cases.independentRomRadiiAndFlag=true
  U.freshSave(game)
  local trainers={179,425,426}
  local function fought(id,on)game.save.flags[('FLAG_G3_%04X'):format(0x500+id)]=on or nil end
  local function gym(n)
    fought(266,false);for i,id in ipairs(trainers)do fought(id,i<=n)end
    U.teleport(game,'MAP_G03_N03',5,26,'up');U.wait(120)
    assert(not game.overworld.runner:isRunning())
    assert(game.overworld.player.cellX==5 and game.overworld.player.cellY==26 and not game.overworld.player.hidden)
  end
  for n=0,3 do
    gym(n);assert(F.level(game)==4-n and F.circle(game,240,160).radius==r.radii[5-n])
    shot('rs-dewford-'..n..'-trainers')
  end
  report.cases.originalGymTrainerStages=true
  fought(266,true);U.teleport(game,'MAP_G03_N03',5,26,'up');U.wait(120)
  assert(F.level(game)==0 and not F.circle(game,240,160));shot('rs-dewford-leader-defeated')
  report.cases.gymLeaderLightsOn=true
  local function cave(id)
    local w=assert(game.data.maps[id].warps[1])
    U.teleport(game,id,w.x,w.y,'down');U.wait(120)
    -- Stand off the ladder/foreground tile for visual inspection.
    local world=game.overworld;local x,y
    for _,d in ipairs({{0,1},{0,-1},{1,0},{-1,0}})do
      local tx,ty=w.x+d[1],w.y+d[2]
      if world.map:inBounds(tx,ty)and world.map:isWalkableCell(tx,ty)and not world.map:warpAtCell(tx,ty)then
        x,y=tx,ty;break
      end
    end
    assert(x and y);U.teleport(game,id,x,y,'down');U.wait(120)
  end
  F.setLit(game,false);cave('MAP_G24_N08')
  assert(F.level(game)==4 and F.circle(game,240,160).radius==24);shot('rs-granite-dark')
  F.setLit(game,true);cave('MAP_G24_N09')
  assert(F.level(game)==1 and F.circle(game,240,160).radius==72 and game.save.flags.FLAG_G3_0828)
  shot('rs-granite-flash-lit');report.cases.darkAndLitCaveDefaults=true
  U.teleport(game,'MAP_G03_N00',3,5,'down');U.wait(120)
  assert(F.level(game)==0 and F.lit(game))
  cave('MAP_G24_N08');assert(F.level(game)==1);shot('rs-granite-light-retained')
  report.cases.lightRetainedThroughIndoorRoom=true
  U.teleport(game,'MAP_G00_N11',11,10,'down');U.wait(120)
  assert(not F.lit(game)and not game.save.flags.FLAG_G3_0828 and not game.save.flashLit)
  cave('MAP_G24_N08');assert(F.level(game)==4);shot('rs-granite-dark-after-outdoors')
  report.cases.outdoorWarpResetsNativeFlag=true
  -- Native UpdateFlashLevelEffect alternates scanline writes and radius steps.
  F.setLevel(game,4);F.animateTo(game,3)
  for i=1,33 do
    assert(F.tick(game));assert(game.save.gen3FlashRadius==24+math.min(16,math.floor((i-1)/2)))
  end
  assert(not F.tick(game)and not game.save.gen3FlashRadius)
  report.cases.nativeAlternatingAnimationFrames=true
  local world=game.overworld;local done=0;local doneFrame
  F.setLevel(game,4);local began=U.frame()
  world.runner:run({{'g3_animate_flash',3},{'g3_set_flash_level',3}},
    {onDone=function()done=done+1;doneFrame=U.frame()end})
  assert(done==0 and world.runner:isRunning())
  for _=1,50 do if done>0 then break end;U.wait(1)end
  assert(done==1 and F.level(game)==3 and not game.save.gen3FlashRadius)
  report.nativeScriptAnimationFrames=doneFrame-began
  assert(report.nativeScriptAnimationFrames>=34 and report.nativeScriptAnimationFrames<=35)
  report.cases.nativeScriptWaitsForLighting=true
  F.setLevel(game,4)
  world.runner:run({{'g3_animate_flash',0},{'g3_set_flash_level',0}},
    {onDone=function()done=done+1 end})
  U.wait(16);assert(done==1 and F.circle(game,240,160).radius<200)
  shot('rs-flash-opening-to-full')
  for _=1,400 do if done==2 then break end;U.wait(1)end
  assert(done==2 and F.level(game)==0 and not F.circle(game,240,160))
  shot('rs-flash-full-light');report.cases.openingToZeroRemainsAnimated=true
  F.setLevel(game,99);assert(F.level(game)==0)
  F.setLevel(game,-1);assert(F.level(game)==0)
  report.cases.originalLevelClamp=true
  report.status='pass';persist();print('PASS_RS_FLASH_NATIVE',edition);love.event.quit(0)
end
