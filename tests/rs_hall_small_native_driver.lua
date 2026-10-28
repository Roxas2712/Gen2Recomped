-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Prepared half-team/egg fixtures; no story, capture or complete-credit claim.
return function(game)
  local U,J=require('tests.drivers.util'),require('src.link.Json')
  local S=require('src.core.SaveSerializer');local V=require('src.core.GameVersion');local edition=V.get()
  local out=assert(os.getenv('EDITION_QA_OUT'));assert(edition=='ruby'or edition=='sapphire')
  for _,event in ipairs{'keypressed','keyreleased','textinput','gamepadpressed','gamepadreleased',
    'joystickpressed','joystickreleased','joystickaxis','joystickhat','touchpressed','touchreleased',
    'touchmoved','mousepressed','mousereleased'}do love[event]=function()end end
  game.input:reset()
  local report={edition=edition,status='running',preparedFixture=true,continuousStory=false,
    completeCreditsTested=false,cases={},captures={}}
  local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
  local function press(key)game.input:overlayPressed(key);U.wait(1);game.input:overlayReleased(key);U.wait(8)end
  local function shot(name)
    local before=S.encode(game.save);local rng=love.math.getRandomState();local top=game.stack:top()
    assert(require('src.render.GraphicsScope').call(top.draw,top))
    assert(before==S.encode(game.save)and rng==love.math.getRandomState(),'Small-team draw changed save/RNG')
    assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
  end
  for _,count in ipairs{1,3}do
    U.freshSave(game);game.save.player.gender=edition=='ruby'and'boy'or'girl'
    local P=require('src.pokemon.Pokemon');local party={}
    for i=1,count do party[i]=P.new(game.data,({'TORCHIC','MAGIKARP','UNOWN'})[i],20)end
    if count==3 then party[2].isEgg=true;party[2].egg=true;party[2].hatchCounter=40 end
    game.save.party=party;game.save.hallOfFame=1
    require('src.core.SaveData').validate(game.save,game.data)
    U.teleport(game,'MAP_G15_N00',8,20,'up');U.wait(30)
    local before=S.encode({party=party});local callbacks=0
    local hall=require('src.ui.Gen3HallOfFame').new(game,function()callbacks=callbacks+1 end)
    assert(getmetatable(hall)==require('src.ui.Gen3RsHallOfFame'))
    game.stack:push(hall);local observed={}
    for _=1,6000 do
      if hall.phase=='hold'and not observed[hall.index]then
        local sprite=hall.scene._sprites[hall.index]
        assert(sprite.dx==({120,56,184})[hall.index]and sprite.dy==64,'Small team used full-team coordinates')
        if count==3 and hall.index==2 then
          local native=hall.load('src.core.game3.pokemon');assert(native.isEgg(hall.scene.getCurrentMon()))
          local f=assert(love.filesystem.load(game.data.constants.gen3RsSummary.extras));setfenv(f,{})
          assert(native.monFrontPic(hall.scene.getCurrentMon()).image==require('src.render.Assets').image(f().egg),
            'Egg presentation exposed the unhatched species')
        end
        shot('native-rs-hall-small-'..count..'-member-'..hall.index);observed[hall.index]=true
      elseif hall.phase=='exitwait'then shot('native-rs-hall-small-'..count..'-player');break end
      U.wait(1)
    end
    for i=1,count do assert(observed[i],'Missing small-team member '..i)end
    assert(hall.phase=='exitwait');press('a')
    for _=1,1200 do if hall.closed then break end;U.wait(1)end
    local credits=game.stack:top();assert(getmetatable(credits)==require('src.ui.Gen3RsCredits'))
    assert(S.encode({party=party})==before,'Presentation changed original party values')
    assert(callbacks==0,'Story callback ran before the credits')
    for _=1,1200 do if credits.state.text and not credits.state.m.ppu.palette:fadeActive()then break end;U.wait(1)end
    shot('native-rs-hall-small-'..count..'-credits-start')
    report.cases[#report.cases+1]={partySize=count,egg=count==3,partyUnchanged=true};persist()
    -- Explicit prepared-fixture teardown, not an accepted complete credit roll.
    while game.stack:top()~=game.overworld do game.stack:pop()end
  end
  report.status='pass';report.drawPreservesSaveRng=true;persist()
  print('PASS_NATIVE_RS_HALL_SMALL_TEAMS');love.event.quit(0)
end
