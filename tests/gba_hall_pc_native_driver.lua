-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Prepared histories; real script binding, native renderer, input and disk IO.
return function(game)
 local U,J=require('tests.drivers.util'),require('src.link.Json');local V=require('src.core.GameVersion')
 local version=V.get();local out=assert(os.getenv('EDITION_QA_OUT'))
 assert(love.filesystem.getIdentity():match('^oasc%-edition%-qa%-'..version..'%-'))
 for _,event in ipairs{'keypressed','keyreleased','textinput','gamepadpressed','gamepadreleased','joystickpressed',
  'joystickreleased','joystickaxis','joystickhat','touchpressed','touchreleased','touchmoved','mousepressed','mousereleased'}do love[event]=function()end end
 game.input:reset();U.freshSave(game)
 local S,IO=require('src.core.SaveSerializer'),require('src.core.SaveData');local H=require('src.core.Gen3HallHistory')
 local P=require('src.pokemon.Pokemon');game.save.party={P.new(game.data,'MAGIKARP',5)}
 local frlg=version=='firered'or version=='leafgreen'
 U.teleport(game,frlg and'MAP_G04_N00'or'MAP_G01_N01',4,2,'down');U.wait(60)
 local function team(ids,nickname)
  local session={party={},hallOfFameTeams={{}}}
  for i,id in ipairs(ids)do
   local egg=id=='EGG';if egg then id='BULBASAUR'end
   session.party[i]={_hostMon={species=id,isEgg=egg or nil}}
   session.hallOfFameTeams[1][i]={species=egg and 412 or assert(game.data.pokemon[id]).index,
    nickname=egg and'EGG'or nickname,level=45+i,trainerId=0x1234,otSecretId=0x5678,personality=0x12345678+i}
  end
  return H.recordScene({game=game,session=session})
 end
 game.save.gen3HallOfFameTeams=nil;game.save.hallOfFame=2
 team({'BULBASAUR','PIKACHU','TREECKO'},'FIRST')
 team({'SCEPTILE','MEWTWO','PIKACHU','TREECKO','BULBASAUR','EGG'},'A%BC')
 assert(game:writeSave()==true)
 local durable=assert(IO.load(version))
 assert(S.encode(durable.gen3HallOfFameTeams)==S.encode(game.save.gen3HallOfFameTeams),'Stable history did not survive actual host save/load')
 local report={status='running',edition=version,preparedFixture=true,continuousStory=false,captures={},cases={},clockSeconds=0}
 local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
 local function press(key)game.input:overlayPressed(key);U.wait(1);game.input:overlayReleased(key);U.wait(8)end
 local function shot(name)
  local before=S.encode(game.save);local rng=love.math.getRandomState();local top=game.stack:top()
  assert(require('src.render.GraphicsScope').call(top.draw,top))
  assert(before==S.encode(game.save)and rng==love.math.getRandomState(),'Hall PC draw changed save/RNG')
  assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
 end
 local function unchanged(before)
  local previous=assert(S.decode(before));local current=assert(S.decode(S.encode(game.save)))
  local dt=IO.playSeconds(current)-IO.playSeconds(previous)
  assert(dt>=0 and dt<120,'Unexpected host play-clock change during PC input')
  report.clockSeconds=report.clockSeconds+dt
  -- Account only for the host's independently advancing scalar play clock.
  previous.playTime,current.playTime=0,0
  assert(S.encode(previous)==S.encode(current),'Hall PC input changed a persistent field other than playTime')
 end
 local world=game.stack:top();local callbacks,yields,writes=0,0,0
 local actualWrite=game.writeSave;game.writeSave=function(...)writes=writes+1;return actualWrite(...)end
 local function open()
  local ctx={game=game,save=game.save,runner={resume=function()callbacks=callbacks+1 end,yield=function()yields=yields+1 end}}
  require('src.script.Gen3Commands').SPECIALS[frlg and 0x1000+263 or 266](ctx)
  local screen=game.stack:top();assert(screen.screenId=='Gen3HallPc'and screen~=world)
  U.wait(20);return screen,screen.scene
 end
 local before=S.encode(game.save);local screen,scene=open()
 assert(scene._team==2 and scene._number==2 and scene._mon==1 and#scene._teams[2]==6)
 shot('native-hall-pc-newest-six-member-team')
 for _=1,5 do press('down')end
 assert(scene._mon==6);shot('native-hall-pc-historic-egg')
 press('down');assert(scene._mon==6);press('up');assert(scene._mon==5)
 press('a');assert(scene._team==1 and scene._number==1 and scene._mon==1 and#scene._teams[1]==3)
 shot('native-hall-pc-previous-three-member-team')
 press('b');assert(game.stack:top()==world and callbacks==1 and yields==1);screen:finish();assert(callbacks==1)
 unchanged(before)
 before=S.encode(game.save);screen,scene=open();press('a');press('a')
 assert(game.stack:top()==world and callbacks==2);unchanged(before)
 game.save.gen3HallOfFameTeams=nil;game.save.hallOfFame=7
 game.save.options.gen3Frame=frlg and 10 or 20
 before=S.encode(game.save);screen,scene=open();assert(scene._corrupted)
 shot('native-hall-pc-legacy-count-only-error')
 press('a');assert(game.stack:top()==world and callbacks==3);unchanged(before)
 assert(writes==0,'PC viewer invoked a save or induction writer');game.writeSave=actualWrite
 report.cases={stableHistoryDiskRoundTrip=true,realScriptHandoff=true,latestAndPreviousTeams=true,
  historicalEgg=true,selectionBounds=true,oldestAExit=true,bCancel=true,legacyCountOnly=true,
  callbackOnce=true,noViewerWrites=true,allInputFieldsPreservedExceptAccountedClock=true}
 report.drawPreservesSaveRng=true;report.status='pass';persist();print('PASS_NATIVE_GBA_HALL_PC');love.event.quit(0)
end
