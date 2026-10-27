-- Native Emerald boot controller, audio and host callback regression.
-- Opening fixtures do not claim a complete ordinary story.
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
 local report={edition='emerald',status='running',nativeController=true,nativeFullStoryAccepted=false,
  continuousStory=false,captures={},audio={},cases={}}
 local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
 local function shot(name)
  local saved,rng=S.encode(game.save),love.math.getRandomState()
  assert(require('src.render.GraphicsScope').call(function()game.stack:top():draw()end))
  assert(saved==S.encode(game.save)and rng==love.math.getRandomState(),'Emerald draw changed save/RNG')
  assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
 end
 local function press(key,n)game.input:overlayPressed(key);U.wait(1);game.input:overlayReleased(key);U.wait(n or 30)end
 local Boot=require('src.ui.Gen3RsBoot')
 local function isBoot(kind)
  local top=game.stack:top();return getmetatable(top)==Boot and top.kind==kind
 end
 local function titleReady()
  for _=1,1500 do
   assert(isBoot('title'),'Title was replaced during its native entrance')
   if game.stack:top().scene.phase=='phase3'then return end
   U.wait(1)
  end
  error('Native title entrance did not finish')
 end
 local spec=assert(game.data.constants.gen3EmeraldPresentation)
 report.ready=require('src.import.RomImporter').readyReport('emerald');persist();assert(report.ready.ok)
 assert(isBoot('intro'),'Emerald did not enter its original movie controller')
 local Sound=require('src.core.Sound');local cries={};local oldCry=Sound.playCry
 Sound.playCry=function(data,id,opts)
  cries[id]=(cries[id]or 0)+1
  local source=oldCry(data,id,opts);assert(source,'Native legendary cry is missing');return source
 end
 shot('native-copyright');local seen={}
 for _=1,12000 do
  if isBoot('title')then break end
  assert(isBoot('intro'),'Unexpected Emerald movie screen')
  local scene=game.stack:top().scene
  for _,frame in ipairs({300,600,1000,1300,1700,2100,2500,2900,3300})do
   if scene.frames and scene.frames>=frame and not seen[frame]then
    seen[frame]=true;shot('native-movie-frame-'..frame)
   end
  end
  U.wait(1)
 end
 Sound.playCry=oldCry
 assert(isBoot('title'),'Emerald native movie did not finish')
 assert(cries[spec.speciesIds.SPECIES_GROUDON]==1 and cries[spec.speciesIds.SPECIES_KYOGRE]==1,
  'Original movie did not play both legendary cries exactly once')
 report.cries=cries;report.cases.originalMovieReachesTitle=true;report.introSamples=seen
 titleReady();shot('native-rayquaza-title')
 for name,id in pairs({intro=Music.special(game.data,'intro'),title=Music.special(game.data,'title'),
  introBattle=Music.special(game.data,'introBattle'),wild=game.data.audio.battle.wild,trainer=game.data.audio.battle.trainer, victory=game.data.audio.battle.trainerWin})do
  local def=assert(game.data.audio.songs[id],'Missing Emerald cue '..name)
  local synth=require('src.core.M4ASynth').newEngine(game.data,def,{allowLoops=false});local nonzero=false
  for _=1,88200 do local l,r=synth:sampleStereo();if l~=0 or r~=0 then nonzero=true;break end end
  assert(nonzero,'Silent Emerald cue '..name);report.audio[name]={id=id,nonzeroPcm=true}
 end
 report.cases.audioHasSignal=true
 press('start',120);local Menu=require('src.ui.Gen3MainMenu');local menu=game.stack:top()
 assert(getmetatable(menu)==Menu);shot('new-game-menu')
 press('b',30);titleReady();shot('native-title-menu-return')
 local title=game.stack:top().scene
 assert(type(title.songFrames)=='number'and title.songFrames>0,'Native title song has no attract end')
 report.titleSongFrames=title.songFrames
 for _=1,16000 do if isBoot('intro')then break end;U.wait(1)end
 assert(isBoot('intro')and not game.stack:top().scene.coldBoot,'Title did not return to warm copyright')
 shot('native-attract-copyright')
 for _=1,1000 do
  if isBoot('title')then break end
  press('a',2)
 end
 assert(isBoot('title'),'Original movie interruption did not reach title')
 titleReady();press('start',120);menu=game.stack:top();assert(getmetatable(menu)==Menu)
 report.cases.menuCancelAndAttractAndSkip=true
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
 for _=1,10000 do if isBoot('title')then break end;U.wait(1)end
 assert(isBoot('title'));titleReady();press('start',120);menu=game.stack:top();assert(getmetatable(menu)==Menu)
 local found=false;for i,row in ipairs(menu.items)do if row.key=='continue'then menu.index=i;found=true end end
 assert(found);shot('continue-menu');press('a',60)
 if game.stack:top()==menu and menu.info then shot('continue-info');press('a',120)end
 assert(game.overworld and game.stack:top()==game.overworld,'Emerald CONTINUE did not restore field')
 assert(game.save.player.name==saved.player.name and game.overworld.map.id==saved.player.map)
 assert(game.overworld.player.cellX==saved.player.x and game.overworld.player.cellY==saved.player.y)
 assert(love.filesystem.read(IO.saveFilename('emerald'))==bytes,'Emerald CONTINUE rewrote save bytes')
 report.cases.saveAndContinue=true;shot('continued-field');report.status='pass';persist()
 print('PASS_EMERALD_NATIVE_BOOT');love.event.quit(0)
end
