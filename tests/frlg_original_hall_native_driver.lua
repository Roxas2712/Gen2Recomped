-- Prepared original-controller acceptance; not an ordinary story/ending save.
return function(game)
 local U=require('tests.drivers.util');local J=require('src.link.Json');local V=require('src.core.GameVersion')
 local edition=V.get();assert(edition=='firered'or edition=='leafgreen')
 local out=assert(os.getenv('EDITION_QA_OUT'));assert(love.filesystem.getIdentity():match('^oasc%-edition%-qa%-'..edition..'%-'))
 assert(require('src.import.RomImporter').readyReport(edition).ok)
 for _,event in ipairs{'keypressed','keyreleased','textinput','gamepadpressed','gamepadreleased','joystickpressed',
  'joystickreleased','joystickaxis','joystickhat','touchpressed','touchreleased','touchmoved','mousepressed','mousereleased'}do love[event]=function()end end
 while game.stack:top()do game.stack:pop()end
 game.input:reset();local backdrop={update=function()end,draw=function()end,isOpaque=true};game.stack:push(backdrop)
 local P=require('src.pokemon.Pokemon');local Save=require('src.core.SaveSerializer');local IO=require('src.core.SaveData')
 local Music=require('src.core.Music');local Sound=require('src.core.Sound');local play,cry=Sound.playId,Sound.playCry
 local applause,cries=0,0
 Sound.playId=function(data,id,...)local source=play(data,id,...);if id==98 and source then applause=applause+1 end;return source end
 Sound.playCry=function(data,id,...)local source=cry(data,id,...);if source then cries=cries+1 end;return source end
 local report={status='running',edition=edition,preparedFixture=true,continuousStory=false,nativeEndingSaveTested=false,captures={},cases={}}
 local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
 local function shot(name,h)
  local before=Save.encode(game.save);local rng=love.math.getRandomState()
  assert(require('src.render.GraphicsScope').call(h.draw,h));assert(Save.encode(game.save)==before and love.math.getRandomState()==rng,'Hall draw changed host save/RNG')
  assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
 end
 for _,gender in ipairs{'boy','girl'}do
  U.freshSave(game);game.save.player.name='OWNED';game.save.player.gender=gender;game.save.playTime=123*3600+45*60
  game.save.party={};game.save.options.gen3Frame=gender=='girl'and 10 or 1
  local ids={'NIDORINA','CHARIZARD','PIDGEOT','LAPRAS','MEWTWO','SNORLAX'};local count=gender=='girl'and 3 or 6
  for i=1,count do game.save.party[i]=P.new(game.data,ids[i],50)end
  game.save.party[1].gender=nil
  if gender=='girl'then game.save.party[2].isEgg=true end
  IO.validate(game.save,game.data)
  local done=0;local h=assert(require('src.ui.Gen3HallOfFame').new(game,function()done=done+1 end))
  assert(getmetatable(h)==require('src.ui.Gen3FrlgHallOfFame'),'Reconstructed Hall still selected')
  local native=h.scene;assert(h.load('src.core.game3.profile').family()=='frlg')
  local audio=h.load('src.core.game3.audio');local playCry=audio.playCry;local localCries=0
  audio.playCry=function(...)localCries=localCries+1;return playCry(...)end
  game.stack:push(h);local seen,confetti,champion={},false,false
  for _=1,6000 do
   if native.phase()=='hold'and not seen[native._currentIndex]then
    local i=native._currentIndex;seen[i]=true
    if gender=='girl'and i==2 then
     local font=h.load('src.ui.game3.frlg_font');local draw=font.draw;local words={}
     font.draw=function(s,...)words[#words+1]=tostring(s);return draw(s,...)end
     local ok,why=require('src.render.GraphicsScope').call(h.draw,h);font.draw=draw;assert(ok,why)
     assert(table.concat(words,'|')=='EGG','Egg leaked species, level, ID or gender')
     assert(h.eggImage and h.eggImage:getWidth()==64 and h.eggImage:getHeight()==64)
    end
    shot('original-'..gender..'-hall-mon-'..i,h)
   elseif native.phase()=='applause'and#native._confetti>5 and not confetti then confetti=true;shot('original-'..gender..'-hall-confetti',h)
   elseif native.phase()=='exitwait'then
    local font=h.load('src.ui.game3.frlg_font');local draw=font.draw;local words={}
    font.draw=function(s,...)words[#words+1]=tostring(s);return draw(s,...)end
    local ok,why=require('src.render.GraphicsScope').call(h.draw,h);font.draw=draw;assert(ok,why)
    assert(table.concat(words,'|'):find('123:45',1,true),'Native player clock missing')
    shot('original-'..gender..'-hall-player-clock',h);champion=true;break
   end
   U.wait(1)
  end
  assert(champion and confetti and done==0)
  for i=1,count do assert(seen[i],'Native controller omitted a party member')end
  assert(localCries==count-(gender=='girl'and 1 or 0),'Egg cry suppression or ordinary cries wrong')
  assert(Music.current()==Music.special(game.data,'hallOfFame'),'Native Hall music is wrong')
  game.input:overlayPressed('a');U.wait(1);game.input:overlayReleased('a');U.wait(200)
  local credits=game.stack:top();assert(credits~=h and credits~=backdrop and done==0)
  assert(Music.current()==Music.special(game.data,'credits'));shot('original-'..gender..'-hall-credits-handoff',credits)
  while game.stack:top()~=backdrop do game.stack:pop()end
  report.cases[gender]={party=count,frame=gender=='girl'and 10 or 1,clock='123:45',nativeCries=localCries,egg=gender=='girl',actualCreditsHandoff=true}
 end
 Sound.playId,Sound.playCry=play,cry
 assert(applause==2 and cries==8,'Actual native Hall audio sources missing')
 report.actualApplauseSources=applause;report.actualCrySources=cries;report.drawSaveRngPreserved=true;report.status='pass';persist()
 print('PASS_NATIVE_ORIGINAL_FRLG_HALL '..edition);love.event.quit(0)
end
