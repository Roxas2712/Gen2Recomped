-- Baseline of the existing Emerald implementation; native-reference parity
-- and continuous story acceptance require separate evidence.
return function(game)
 local U=require('tests.drivers.util');local V=require('src.core.GameVersion')
 local S=require('src.core.SaveSerializer');local IO=require('src.core.SaveData')
 local J=require('src.link.Json');local Music=require('src.core.Music')
 local out=assert(os.getenv('EDITION_QA_OUT'))
 assert(V.get()=='emerald'and love.filesystem.getIdentity():match('^oasc%-edition%-qa%-emerald%-'))
 for _,event in ipairs({'keypressed','keyreleased','textinput','gamepadpressed','gamepadreleased',
  'joystickpressed','joystickreleased','joystickaxis','joystickhat','touchpressed','touchreleased',
  'touchmoved','mousepressed','mousereleased'})do love[event]=function()end end
 game.input:reset()
 local report={edition='emerald',status='running',baselineOnly=true,nativeReferenceParityAccepted=false,
  continuousStory=false,captures={},audio={},cases={}}
 local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
 local function shot(name)
  local saved,rng=S.encode(game.save),love.math.getRandomState()
  assert(require('src.render.GraphicsScope').call(function()game.stack:top():draw()end))
  assert(saved==S.encode(game.save)and rng==love.math.getRandomState(),'Emerald draw changed save/RNG')
  assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
 end
 local function press(key,n)game.input:overlayPressed(key);U.wait(1);game.input:overlayReleased(key);U.wait(n or 30)end
 local Title=require('src.ui.Gen3Title');local Intro=require('src.ui.Gen3Intro')
 report.ready=require('src.import.RomImporter').readyReport('emerald');persist();assert(report.ready.ok)
 assert(getmetatable(game.stack:top())==Intro,'Emerald did not enter its own movie')
 shot('initial-movie');local seen={}
 for _=1,10000 do
  local screen=game.stack:top();if getmetatable(screen)==Title then break end
  assert(getmetatable(screen)==Intro,'Unexpected Emerald movie screen')
  for _,frame in ipairs({140,620,1150,2200,2800})do
   if screen.frame>=frame and not seen[frame]then seen[frame]=true;shot('movie-frame-'..frame)end
  end
  U.wait(1)
 end
 assert(getmetatable(game.stack:top())==Title,'Emerald movie did not finish')
 report.cases.movieReachesTitle=true;report.introSamples=seen;shot('rayquaza-title')
 for name,id in pairs({intro=Music.special(game.data,'intro'),title=Music.special(game.data,'title'),
  wild=game.data.audio.battle.wild,trainer=game.data.audio.battle.trainer, victory=game.data.audio.battle.trainerWin})do
  local def=assert(game.data.audio.songs[id],'Missing Emerald cue '..name)
  local synth=require('src.core.M4ASynth').newEngine(game.data,def,{allowLoops=false});local nonzero=false
  for _=1,88200 do local l,r=synth:sampleStereo();if l~=0 or r~=0 then nonzero=true;break end end
  assert(nonzero,'Silent Emerald cue '..name);report.audio[name]={id=id,nonzeroPcm=true}
 end
 report.cases.audioHasSignal=true
 press('start',120);local Menu=require('src.ui.Gen3MainMenu');local menu=game.stack:top()
 assert(getmetatable(menu)==Menu);shot('new-game-menu')
 for i,row in ipairs(menu.items)do if row.key=='newGame'then menu.index=i end end
 press('a',30)
 for _=1,2500 do
  if game.overworld and game.stack:top()==game.overworld then break end
  press('a',2)
 end
 local world=game.overworld;assert(world and game.stack:top()==world,'Emerald professor/naming did not reach field')
 report.cases.newGameReachesField=true;shot('new-game-field')
 local x,y=world.player.cellX,world.player.cellY;local moved=false
 for _,key in ipairs({'down','left','right','up'})do
  game.input:overlayPressed(key);U.wait(30);game.input:overlayReleased(key);U.wait(20)
  if x~=world.player.cellX or y~=world.player.cellY then moved=true;break end
 end
 assert(moved,'Emerald initial field movement is blocked');report.cases.movement=true;shot('field-moved')
 assert(IO.save(game.save,game.mods));local bytes=assert(love.filesystem.read(IO.saveFilename('emerald')))
 local saved=assert(IO.load('emerald'));assert(saved.version=='emerald')
 for _,other in ipairs({'ruby','sapphire','firered','leafgreen'})do assert(not IO.saveFileExists(other),'Emerald wrote another edition slot')end
 game:returnToTitle()
 for _=1,10000 do if getmetatable(game.stack:top())==Title then break end;U.wait(1)end
 assert(getmetatable(game.stack:top())==Title);press('start',120);menu=game.stack:top();assert(getmetatable(menu)==Menu)
 local found=false;for i,row in ipairs(menu.items)do if row.key=='continue'then menu.index=i;found=true end end
 assert(found);shot('continue-menu');press('a',60)
 if game.stack:top()==menu and menu.info then shot('continue-info');press('a',120)end
 assert(game.overworld and game.stack:top()==game.overworld,'Emerald CONTINUE did not restore field')
 assert(game.save.player.name==saved.player.name and game.overworld.map.id==saved.player.map)
 assert(game.overworld.player.cellX==saved.player.x and game.overworld.player.cellY==saved.player.y)
 assert(love.filesystem.read(IO.saveFilename('emerald'))==bytes,'Emerald CONTINUE rewrote save bytes')
 report.cases.saveAndContinue=true;shot('continued-field');report.status='pass';persist()
 print('PASS_EMERALD_BASELINE_ONLY');love.event.quit(0)
end
