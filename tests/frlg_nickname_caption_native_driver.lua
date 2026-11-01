-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Prepared own-ROM final-renderer fixtures, never ordinary story credit.
return function(game)
 local U=require('tests.drivers.util');local J=require('src.link.Json')
 local Save=require('src.core.SaveSerializer');local Naming=require('src.ui.NamingScreen')
 local Strings=require('src.core.Strings');local Font=require('src.render.Font')
 local edition=require('src.core.GameVersion').get();assert(edition=='firered'or edition=='leafgreen')
 local out=assert(os.getenv('EDITION_QA_OUT'))
 assert(love.filesystem.getIdentity():match('^oasc%-edition%-qa%-'..edition..'%-'))
 for _,event in ipairs{'keypressed','keyreleased','textinput','gamepadpressed','gamepadreleased','joystickpressed',
  'joystickreleased','joystickaxis','joystickhat','touchpressed','touchreleased','touchmoved','mousepressed','mousereleased'}do love[event]=function()end end
 game.input:reset();U.freshSave(game)
 local player=game.save.player;U.teleport(game,player.map,player.x,player.y,player.facing);U.wait(60)
 local mon=require('src.pokemon.Pokemon').new(game.data,'BULBASAUR',5);game.save.party={mon}
 local report={edition=edition,status='running',preparedCaptionFixture=true,continuousStory=false,cases={},captures={}}
 local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
 local function press(key)game.input:overlayPressed(key);U.wait(1);game.input:overlayReleased(key);U.wait(30)end
 local function stable()
  local value=assert(Save.decode(Save.encode(game.save)));value.playTime=nil;return Save.encode(value)
 end
 for _,case in ipairs{
  {id='native-species-nickname',kind='mon',title=Strings('NICKNAME?'),
   expected=game.data.pokemon.BULBASAUR.name..Strings("'s nickname?")},
  {id='mod-caption-retained',kind='mon',title='MOD TITLE',expected='MOD TITLE'},
  {id='player-caption-retained',kind='player',title='YOUR NAME?',expected='YOUR NAME?'},
  {id='rival-caption-retained',kind='rival',title="RIVAL's NAME?",expected="RIVAL's NAME?"},
 }do
  local owner=game.stack:top();local callbacks=0;local before=stable()
  local screen=Naming.new(game,{title=case.title,kind=case.kind,mon=case.kind=='mon'and mon or nil,
   maxLen=case.kind=='mon'and 10 or 7,onDone=function()
    callbacks=callbacks+1;assert(game.stack:top()==owner,'Naming caption changed callback ownership')
   end})
  game.stack:push(screen);U.wait(4)
  local save=Save.encode(game.save);local rng=love.math.getRandomState();local seen={};local draw=Font.draw
  Font.draw=function(text,x,y,...)
   if x==72 and y==33 then seen[#seen+1]=text end
   return draw(text,x,y,...)
  end
  local ok,why=require('src.render.GraphicsScope').call(screen.draw,screen);Font.draw=draw;assert(ok,why)
  assert(#seen==1 and seen[1]==case.expected,'Wrong actually rendered native naming caption: '..tostring(seen[1]))
  assert(Save.encode(game.save)==save and love.math.getRandomState()==rng,'Caption drawing changed save/RNG')
  assert(U.shot(game,out..'/'..case.id..'.png'));report.captures[#report.captures+1]=case.id
  press('start');press('a')
  assert(callbacks==1 and game.stack:top()==owner,'Naming confirmation did not return exactly once')
  assert(stable()==before,'Caption display or confirmation changed another save field')
  report.cases[case.id]={passed=true,renderedCaption=seen[1]};persist()
 end
 report.drawSaveAndRngPreserved=true;report.completeSaveComparedExceptPlayTime=true
 report.status='pass';persist();print('PASS_FRLG_NATIVE_NAMING_CAPTIONS',edition);love.event.quit(0)
end
