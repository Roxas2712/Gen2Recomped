-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Prepared evolution cases; actual input, host mutation/learning and renderer.
return function(game)
 local U,J=require('tests.drivers.util'),require('src.link.Json');local V=require('src.core.GameVersion')
 local edition=V.get();local out=assert(os.getenv('EDITION_QA_OUT'))
 assert(love.filesystem.getIdentity():match('^oasc%-edition%-qa%-'..edition..'%-'))
 for _,event in ipairs{'keypressed','keyreleased','textinput','gamepadpressed','gamepadreleased','joystickpressed',
  'joystickreleased','joystickaxis','joystickhat','touchpressed','touchreleased','touchmoved','mousepressed','mousereleased'}do love[event]=function()end end
 game.input:reset();U.freshSave(game)
 local P,E,S=require('src.pokemon.Pokemon'),require('src.pokemon.Evolution'),require('src.core.SaveSerializer')
 local Native=require('src.ui.Gen3NativeEvolution');local factory=require('src.ui.Gen3EvolutionState')
 local boot=game.data.field.boot;U.teleport(game,boot.startMap,boot.startX,boot.startY,boot.startFacing or'down')
 local world=game.overworld;local apply,learn=E.apply,E.learnEvolutionMoves;local applications,learnings=0,0
 E.apply=function(...)applications=applications+1;return apply(...)end
 E.learnEvolutionMoves=function(...)learnings=learnings+1;return learn(...)end
 local report={status='running',edition=edition,preparedFixture=true,ordinaryStory=false,cases={},captures={}}
 local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
 local function press(key,wait)game.input:overlayPressed(key);U.wait(1);game.input:overlayReleased(key);U.wait(wait or 10)end
 local function shot(name,screen)
  local before=S.encode(game.save);local rng=love.math.getRandomState()
  assert(require('src.render.GraphicsScope').call(screen.draw,screen));assert(S.encode(game.save)==before,'Evolution draw changed save')
  assert(love.math.getRandomState()==rng,'Evolution draw consumed host RNG')
  assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
 end
 for _,case in ipairs{
  {id='level',species='MAGIKARP',target='GYARADOS',level=20,via='LEVEL'},
  {id='cancel',species='MAGIKARP',target='GYARADOS',level=20,via='LEVEL',cancel=true},
  {id='stone',species='PIKACHU',target='RAICHU',level=20,via='ITEM',holdB=true},
  {id='held-trade',species='POLIWHIRL',target='POLITOED',level=25,via='TRADE',holdB=true,heldItem='KINGS_ROCK'},
 }do
  assert(game.stack:top()==world)
  local raw=P.new(game.data,case.species,case.level);raw.nickname='A%{B}';raw.hp=raw.stats.hp-3;raw.item=case.heldItem
  if case.id=='level'or case.id=='cancel'then raw.moves={{id='SPLASH',pp=40}}end
  game.save.party={raw};game.save.nationalDex=true;require('src.core.SaveData').validate(game.save,game.data)
  local before=S.encode(raw);local hpLost=raw.stats.hp-raw.hp;applications,learnings=0,0
  local calls=0;local screen=factory.new(game,raw,case.target,function()calls=calls+1 end,case.via,
   case.heldItem and{heldItem=case.heldItem}or nil)
  assert(getmetatable(screen)==Native,'Native evolution was not selected')
  game.stack:push(screen);local scene=screen.scene;local captured={};local bHeld=false;local sawCommit=false
  for _=1,18000 do
   if calls>0 then break end
   if game.stack:top()==screen then
    local state=scene._state
    if not captured.intro and state=='intro_msg'then captured.intro=true;shot(case.id..'-intro',screen)
    elseif state=='cycle'and not captured.cycle and scene._speed>=12 then
     captured.cycle=true;shot(case.id..'-silhouette',screen)
     if case.cancel or case.holdB then game.input:overlayPressed('b');bHeld=true end
    elseif state=='cancel'and not captured.cancel then
     assert(case.cancel and applications==0 and learnings==0 and S.encode(raw)==before,'Cancellation changed the party')
     captured.cancel=true;shot(case.id..'-cancel',screen)
    elseif state=='flash_reveal'and not captured.flash then
     assert(not case.cancel and applications==1 and learnings==0 and raw.species==case.target,'Native point of no return missed host mutation')
     assert(raw.nickname=='A%{B}'and raw.stats.hp-raw.hp==hpLost,'Evolution lost nickname or damage')
     captured.flash=true;sawCommit=true;shot(case.id..'-reveal',screen)
    elseif state=='congrats'and not captured.congrats then
     local page=screen.load('src.ui.game3.message').currentPage()
     assert(page:find('A%{B}',1,true),'Native message lost literal nickname characters')
     captured.congrats=true;shot(case.id..'-congratulations',screen)
    end
    if bHeld and state~='cycle'then game.input:overlayReleased('b');bHeld=false end
    if state=='congrats'or state=='cancel'then press('a',12)else U.wait(1)end
   else
    -- The authoritative host learns stable move IDs after the native view
    -- has popped. Its normal text/menu callbacks must run before onDone.
    press('a',20)
   end
  end
  if bHeld then game.input:overlayReleased('b')end
  assert(calls==1 and game.stack:top()==world,'Evolution callback did not return to its actual owner once')
  assert(captured.intro and captured.cycle)
  if case.cancel then
   assert(captured.cancel and not sawCommit and applications==0 and learnings==0 and raw.species==case.species)
  else
   assert(sawCommit and captured.congrats and applications==1 and learnings==1 and raw.species==case.target)
   if case.id=='level'then local bite=false;for _,move in ipairs(raw.moves)do if move.id=='BITE'then bite=true end end;assert(bite,'Native completion skipped host evolution move learning')end
   if case.heldItem then assert(raw.item==nil,'Held trade item survived authoritative evolution')end
  end
  screen:finish('evolved');assert(calls==1 and applications==(case.cancel and 0 or 1),'Late completion repeated mutation/callback')
  report.cases[case.id]={applications=applications,learningPasses=learnings,callbacks=calls,cancelled=case.cancel==true,
   target=raw.species,heldB=case.holdB==true,nicknamePreserved=true,drawSaveRngPreserved=true};persist()
 end
 E.apply,E.learnEvolutionMoves=apply,learn
 report.status='pass';persist();print('PASS_NATIVE_GBA_EVOLUTION '..edition);love.event.quit(0)
end
