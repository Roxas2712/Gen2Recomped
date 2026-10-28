-- Prepared FR/LG ceremony acceptance; never an ordinary story completion.
return function(game)
 local U=require('tests.drivers.util');local J=require('src.link.Json')
 local V=require('src.core.GameVersion');local edition=V.get();assert(edition=='firered'or edition=='leafgreen')
 local out=assert(os.getenv('EDITION_QA_OUT'));assert(love.filesystem.getIdentity():match('^oasc%-edition%-qa%-'..edition..'%-'))
 assert(require('src.import.RomImporter').readyReport(edition).ok)
 for _,event in ipairs{'keypressed','keyreleased','textinput','gamepadpressed','gamepadreleased',
  'joystickpressed','joystickreleased','joystickaxis','joystickhat','touchpressed','touchreleased',
  'touchmoved','mousepressed','mousereleased'}do love[event]=function()end end
 while game.stack:top()do game.stack:pop()end
 game.input:reset();local backdrop={update=function()end,draw=function()end,isOpaque=true};game.stack:push(backdrop)
 local P=require('src.pokemon.Pokemon');local Save=require('src.core.SaveSerializer')
 local IO=require('src.core.SaveData');local Font=require('src.render.Font');local Music=require('src.core.Music')
 local Sound=require('src.core.Sound');local play=Sound.playId;local applause=0
 local applauseId=assert(require('src.core.game3.se_ids').resolve('SE_APPLAUSE'))
 assert(applauseId==98 and game.data.audio.songs.SONG_062,'Missing FR/LG native applause sequence')
 Sound.playId=function(data,id,...)
  local source=play(data,id,...)
  if id==applauseId then assert(source,'Hall applause has no actual audio source');applause=applause+1 end
  return source
 end
 local report={status='running',edition=edition,preparedFixture=true,continuousStory=false,captures={},cases={}}
 local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
 local function shot(name,owner)
  local before=Save.encode(game.save);local rng=love.math.getRandomState()
  assert(require('src.render.GraphicsScope').call(owner.draw,owner))
  assert(Save.encode(game.save)==before and love.math.getRandomState()==rng,'Ceremony draw changed save/RNG')
  assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
 end
 for _,gender in ipairs{'boy','girl'}do
  U.freshSave(game);game.save.player.name='OWNED';game.save.player.gender=gender
  game.save.playTime=123*3600+45*60;game.save.party={}
  local species={'NIDORINA','CHARIZARD','PIDGEOT','LAPRAS','MEWTWO','SNORLAX'}
  local count=gender=='girl'and 3 or 6
  for i=1,count do game.save.party[i]=P.new(game.data,species[i],50)end
  game.save.party[1].gender=nil
  IO.validate(game.save,game.data)
  local callback=0;local h=assert(require('src.ui.Gen3HallOfFame').new(game,function()callback=callback+1 end))
  assert(getmetatable(h)==require('src.ui.Gen3HallOfFameFRLG'))
  local cue=assert(Music.special(game.data,'hallOfFame'))
  assert(cue:match('^SONG_%x+$')and not game.data.audio.songs.Music_HallOfFame,'Fixture must expose the original legacy-label trigger')
  game.stack:push(h);U.wait(1);assert(Music.current()==cue,'Ceremony did not start its own cartridge Hall music')
  local seen={};local confetti,champion=false,false
  for _=1,6000 do
   if h.phase=='hold'and not seen[h.index]then
    seen[h.index]=true
    if h.index==1 then
     local draw=Font.draw;local words={}
     Font.draw=function(s,...)words[#words+1]=tostring(s);return draw(s,...)end
     local ok,why=require('src.render.GraphicsScope').call(h.draw,h);Font.draw=draw;assert(ok,why)
     assert(table.concat(words,'|'):find('♀',1,true),'Native PID/species gender was omitted')
    end
    shot('native-'..gender..'-hall-mon-'..h.index,h)
   elseif h.phase=='welcome'and #h.confetti>5 and not confetti then
    confetti=true;shot('native-'..gender..'-hall-confetti',h)
   elseif h.phase=='champion'then
    local draw=Font.draw;local words={}
    Font.draw=function(s,...)words[#words+1]=tostring(s);return draw(s,...)end
    local ok,why=require('src.render.GraphicsScope').call(h.draw,h);Font.draw=draw;assert(ok,why)
    assert(table.concat(words,'|'):find('123:45',1,true),'Player panel lost its real play time')
    shot('native-'..gender..'-hall-player-clock',h);champion=true;break
   end
   U.wait(1)
  end
  assert(champion and confetti and callback==0)
  for i=1,count do assert(seen[i],'Party member missing from ceremony')end
  assert(Music.current()==cue,'Hall music stopped before the player panel')
  game.input:overlayPressed('a');U.wait(1);game.input:overlayReleased('a');U.wait(90)
  local credits=game.stack:top();assert(credits~=h and credits~=backdrop and callback==0,'Credits handoff fired completion too early')
  local creditsCue=assert(Music.special(game.data,'credits'))
  assert(creditsCue:match('^SONG_%x+$')and Music.current()==creditsCue,'Credits retained the Hall song instead of their own cartridge cue')
  shot('native-'..gender..'-hall-credits-handoff',credits)
  while game.stack:top()~=backdrop do game.stack:pop()end
  report.cases[gender]={party=count,nativeHallMusic=cue,nativeCreditsMusic=creditsCue,actualCreditsHandoff=true,clock='123:45',derivedFemaleGlyph=true}
 end
 Sound.playId=play;assert(applause==2,'Each actual ceremony must play its applause once')
 report.applauseSources=applause;report.drawSaveRngPreserved=true;report.status='pass';persist()
 print('PASS_NATIVE_FRLG_HALL_MUSIC_CLOCK_GENDER '..edition);love.event.quit(0)
end
