-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Prepared naming fixtures only; never ordinary campaign/save evidence.
return function(game)
 local U=require('tests.drivers.util');local J=require('src.link.Json')
 local Save=require('src.core.SaveSerializer');local Naming=require('src.ui.NamingScreen')
 local edition=require('src.core.GameVersion').get();local out=assert(os.getenv('EDITION_QA_OUT'))
 assert(love.filesystem.getIdentity():match('^oasc%-edition%-qa%-'..edition..'%-'))
 for _,event in ipairs{'keypressed','keyreleased','textinput','gamepadpressed','gamepadreleased','joystickpressed',
  'joystickreleased','joystickaxis','joystickhat','touchpressed','touchreleased','touchmoved','mousepressed','mousereleased'}do love[event]=function()end end
 game.input:reset();U.freshSave(game)
 local mon=require('src.pokemon.Pokemon').new(game.data,'BULBASAUR',5)
 game.save.party={mon}
 local report={edition=edition,status='running',preparedFixture=true,continuousStory=false,cases={},captures={}}
 local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
 local function press(key,n)game.input:overlayPressed(key);U.wait(1);game.input:overlayReleased(key);U.wait(n or 8)end
 local function stable()
  local value=assert(Save.decode(Save.encode(game.save)))
  -- Game:update advances this documented seconds counter during input.
  value.playTime=nil;return Save.encode(value)
 end
 local function shot(screen,name)
  local before=Save.encode(game.save);local rng=love.math.getRandomState()
  assert(require('src.render.GraphicsScope').call(screen.draw,screen))
  assert(before==Save.encode(game.save)and rng==love.math.getRandomState(),'Naming draw changed authoritative save/RNG')
  assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
 end
 local function typeGlyph(screen,wanted)
  for _=1,4 do
   local state=screen.state or screen
   local page=state.pages and state.pages[state.page]
   local grid=page and(page.cells or page.rows)or screen:grid()
   local tx,ty
   for y,row in ipairs(grid)do for x,key in ipairs(row)do if key==wanted then tx,ty=x,y;break end end;if tx then break end end
   if tx then
    for _=1,20 do
     if state.row==ty then break end
     press(state.row<ty and'down'or'up')
    end
    for _=1,20 do
     if state.col==tx then break end
     press(state.col<tx and'right'or'left')
    end
    assert(state.row==ty and state.col==tx,'Actual keyboard cursor did not reach owned glyph')
    press('a');return
   end
   press('select',45)
  end
  error('Owned naming keyboard lacks required glyph '..wanted)
 end
 for _,case in ipairs{
  {id='empty-fresh',kind='empty'},
  {id='empty-keeps-existing',kind='empty',old='OWN NAME'},
  {id='spaces-fresh',kind='spaces'},
  {id='spaces-keep-existing',kind='spaces',old='OWN NAME'},
  {id='typed-name',kind='typed'},
  {id='typed-replaces-existing',kind='typed',old='OWN NAME'},
 }do
  mon.nickname=case.old
  local before=stable();local owner=game.stack:top();local callbacks=0
  local screen=Naming.new(game,{title='NICKNAME?',kind='mon',mon=mon,default=mon.nickname,maxLen=10,onDone=function(name)
   callbacks=callbacks+1;assert(game.stack:top()==owner,'Naming callback ran before restoring its caller')
   if name and#name>0 then mon.nickname=name end
  end})
  game.stack:push(screen);U.wait(4)
  for _=1,10 do press('b')end
  if case.kind=='spaces'then typeGlyph(screen,' ');press('a')
  elseif case.kind=='typed'then typeGlyph(screen,'A')end
  assert(stable()==before,'Editing a naming buffer changed the complete save')
  shot(screen,'native-nickname-'..case.id)
  press('start');press('a',40)
  assert(callbacks==1 and game.stack:top()==owner,'Native confirmation did not dismiss and release its caller once')
  local expected=case.kind=='typed'and'A'or case.old
  assert(mon.nickname==expected,'Blank nickname replaced an existing/default name')
  local after=assert(Save.decode(Save.encode(game.save)));after.playTime=nil;after.party[1].nickname=case.old
  assert(Save.encode(after)==before,'Nickname completion changed another save field')
  report.cases[case.id]=true;persist()
 end
 report.drawSaveAndRngPreserved=true;report.completeSaveComparedExceptPlayTime=true
 report.status='pass';persist();print('PASS_NATIVE_GBA_NICKNAME',edition);love.event.quit(0)
end
