-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Prepared team; actual Hall-room script, atomic IO failures and real CONTINUE.
return function(game)
 local U,J=require('tests.drivers.util'),require('src.link.Json');local V=require('src.core.GameVersion')
 local edition=V.get();assert(edition=='firered'or edition=='leafgreen')
 local out=assert(os.getenv('EDITION_QA_OUT'));assert(love.filesystem.getIdentity():match('^oasc%-edition%-qa%-'..edition..'%-'))
 for _,event in ipairs{'keypressed','keyreleased','textinput','gamepadpressed','gamepadreleased','joystickpressed',
  'joystickreleased','joystickaxis','joystickhat','touchpressed','touchreleased','touchmoved','mousepressed','mousereleased'}do love[event]=function()end end
 game.input:reset();U.freshSave(game)
 local P=require('src.pokemon.Pokemon');local IO=require('src.core.SaveData');local Save=require('src.core.SaveSerializer')
 game.save.player.gender=edition=='firered'and'girl'or'boy';game.save.party={}
 for _,id in ipairs{'CHARIZARD','NIDORINA','PIDGEOT','LAPRAS','MEWTWO','SNORLAX'}do game.save.party[#game.save.party+1]=P.new(game.data,id,50)end
 IO.validate(game.save,game.data)
 for _,mon in ipairs(game.save.party)do require('src.battle.BattleState').stampOT(game.save,mon)end
 local boot=assert(game.data.field.boot)
 U.teleport(game,assert(boot.startMap),assert(boot.startX),assert(boot.startY),boot.startFacing or'down')
 local function disk()return love.filesystem.read(IO.saveFilename(edition))end
 assert(game:writeSave()==true);local original=assert(disk());local actualWrite=game.writeSave
 local mode,attempts='false',0;local Sound=require('src.core.Sound');local play,cry=Sound.playId,Sound.playCry
 local saveSounds,applause=0,0;local credits;local creditCries={}
 local se=assert(game.data.constants.gen3FrlgHall.songIds.SE_SAVE)
 Sound.playId=function(data,id,...)
  if id==se then saveSounds=saveSounds+1 end
  local source=play(data,id,...)
  if id==se then assert(source,'Successful native save has no audio source')end
  if id==98 and source then applause=applause+1 end;return source
 end
 Sound.playCry=function(data,id,...)
  local source=cry(data,id,...)
  if source and credits and not credits.finished then creditCries[id]=(creditCries[id]or 0)+1 end
  return source
 end
 game.writeSave=function(g)
  local h=g.stack:top();assert(h.savingDrawn and h.saveEnding,'League IO preceded its actual saving frame')
  attempts=attempts+1;if mode=='false'then return false elseif mode=='error'then error('Prepared League IO failure')end
  return actualWrite(g)
 end
 local report={status='running',edition=edition,preparedFixture=true,continuousStory=false,
  originalHallController=true,originalCreditsController=false,captures={}}
 local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
 local function shot(name)
  local before=Save.encode(game.save);local rng=love.math.getRandomState();local top=game.stack:top()
  assert(require('src.render.GraphicsScope').call(top.draw,top));assert(Save.encode(game.save)==before and love.math.getRandomState()==rng,'Ending draw changed host save/RNG')
  assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
 end
 local function press(key)game.input:overlayPressed(key);U.wait(1);game.input:overlayReleased(key);U.wait(8)end
 -- The real ON_FRAME script walks up to Oak and executes retail special 272.
 U.teleport(game,'MAP_G01_N80',5,12,'up')
 local Hall=require('src.ui.Gen3FrlgHallOfFame')
 for _=1,1800 do
  if getmetatable(game.stack:top())==Hall then break end
  press('a')
 end
 local h=game.stack:top();assert(getmetatable(h)==Hall,'Actual Hall-room script did not reach original ceremony')
 local ow=game.overworld;assert(ow.map.id=='MAP_G01_N80'and ow.runner:isRunning())
 local row=ow.runner.ctx.script[ow.runner.ctx.pc]
 assert(row[1]=='g3_special'and row[2]==0x1000+272,'Fixture bypassed cartridge EnterHallOfFame')
 local owner,co=ow.runner.ctx,ow.runner.co
 local update=h.update;local savingPath=out..'/frlg-league-saving-message.png';local armed=false
 h.update=function(self,dt)
  if self.scene.phase()=='trysave'then
   local f=io.open(savingPath,'rb')
   if f then f:close();self.update=update
   else
    if not armed then armed=true;game.capturePath=savingPath;report.captures[#report.captures+1]='frlg-league-saving-message';persist()end
    return
   end
  end
  return update(self,dt)
 end
 local failures,mons,confetti={},{},false
 for _=1,8000 do
  assert(game.stack:top()==h,'Unsaved League ceremony escaped')
  if h.saveFailure and h.failureDrawn and not failures[mode]then
   assert(disk()==original and saveSounds==0,'Failed League write altered disk or played save sound')
   assert(h.scene.phase()=='savewait','Failed save advanced ceremony')
   shot('frlg-league-write-'..mode..'-failure');failures[mode]=true;mode=mode=='false'and'error'or'actual';press('a')
  elseif h.phase=='hold'and not mons[h.index]then mons[h.index]=true;shot('frlg-league-mon-'..h.index)
  elseif h.phase=='applause'and not confetti and#h.scene._confetti>=20 then confetti=true;shot('frlg-league-team-confetti')
  elseif h.phase=='exitwait'then shot('frlg-league-player-panel');break end
  U.wait(1)
 end
 assert(h.phase=='exitwait'and confetti and armed and failures['false']and failures.error and attempts==3 and saveSounds==1 and h.saved)
 for i=1,6 do assert(mons[i],'Missing champion party member')end
 local durable=assert(Save.decode(assert(disk())))
 assert(durable.player.map=='MAP_G01_N80'and durable.specialSaveWarpFlags%2==1 and durable.continueGameWarp.map=='MAP_G03_N00')
 assert(durable.hallOfFame==1 and durable.gen3Stats[10]==1 and durable.flags.FLAG_G3_082C)
 for _,mon in ipairs(durable.party)do assert(mon.ribbons.champion)end
 press('a');for _=1,1200 do if game.stack:top()~=h then break end;U.wait(1)end
 credits=game.stack:top();assert(getmetatable(credits)==require('src.ui.Gen3CreditsFRLG'))
 assert(require('src.core.Music').current()==require('src.core.Music').special(game.data,'credits'))
 local commands,maps,monScenes={},{},{};local copyright,theEnd=false,false
 for _=1,50000 do
  assert(game.stack:top()==credits,'Credits ended before their final wait')
  if credits.cmd then commands[credits.idx-1]=true end
  if credits.phase=='hold'and not maps[credits.cmd.param]then maps[credits.cmd.param]=true;shot('frlg-credits-map-'..credits.cmd.param)
  elseif credits.phase=='mon'and credits.mon.t>=104 and not monScenes[credits.cmd.param]then
   monScenes[credits.cmd.param]=true;shot('frlg-credits-mon-'..credits.cmd.param)
  elseif credits.phase=='end'and credits.fade==1 then
   if credits.cmd.param==0 and not copyright then copyright=true;shot('frlg-credits-copyright')
   elseif credits.cmd.param==1 and not theEnd then theEnd=true;shot('frlg-credits-the-end')end
  elseif credits.phase=='wait'then break end
  U.wait(1)
 end
 assert(credits.phase=='wait'and copyright and theEnd,'Full imported credits script missed THE END')
 for i=1,#credits.rec.script do assert(commands[i],'Missing credit command '..i)end
 for i=0,3 do assert(monScenes[i],'Missing original credit Pokémon scene '..i)end
 for _,id in ipairs{'CHARIZARD','VENUSAUR','BLASTOISE','PIKACHU'}do assert(creditCries[id]==1,'Credit scene cry missing: '..id)end
 local commandCount=#credits.rec.script;press('a');for _=1,1200 do if credits.finished then break end;U.wait(1)end
 assert(credits.finished and game.stack:top().screenId=='TitleState','Ending did not reset to native title')
 assert(not ow.runner:isRunning()and owner.scriptCancelled and ow.runner.co~=co,'Retired Hall script continued behind title')
 local title=game.stack:top();for _=1,2400 do if title.phase=='run'then break end;U.wait(1)end
 assert(title.phase=='run');shot('frlg-league-return-title');press('start')
 for _=1,1200 do if getmetatable(game.stack:top())==require('src.ui.Gen3MainMenu')then break end;U.wait(1)end
 local menu=game.stack:top();assert(getmetatable(menu)==require('src.ui.Gen3MainMenu')and menu.items[menu.index].key=='continue')
 U.wait(60);shot('frlg-league-continue-menu');local previous=game.save;press('a')
 for _=1,1200 do if game.save~=previous and game.stack:top()==game.overworld then break end;U.wait(1)end
 assert(game.save~=previous and game.stack:top()==game.overworld,'Real CONTINUE did not adopt the durable snapshot')
 local home=assert(require('src.core.Gen3FrlgEndingSave').home(game.data,game.save));local player=game.save.player
 assert(player.map==home.map and player.x==home.x and player.y==home.y and player.facing=='down','CONTINUE missed outdoor Pallet')
 assert(game.save.lastHeal.map=='MAP_G04_N00'and game.save.lastHeal.x==8 and game.save.lastHeal.y==5,'Whiteout destination became the outdoor Fly point')
 assert(game.save.specialSaveWarpFlags%2==0 and game.save.hallOfFame==1 and game.save.gen3Stats[10]==1)
 assert(Save.encode(game.save.party)==Save.encode(durable.party),'CONTINUE changed champion party')
 assert(Save.decode(disk()).specialSaveWarpFlags%2==1,'CONTINUE rewrote durable snapshot')
 shot('frlg-league-continue-pallet');game.writeSave=actualWrite;Sound.playId,Sound.playCry=play,cry
 report.automaticLeagueSave=true;report.failedWritesPreserveDisk=true;report.writeAttempts=attempts;report.saveSounds=saveSounds
 report.applauseSources=applause;report.actualCartridgeSpecial=272;report.fullImportedCreditsCommands=commandCount
 report.nativeTitleAndActualContinue=true;report.outdoorPalletAndIndoorWhiteout=true;report.drawSaveRngPreserved=true
 report.status='pass';persist();print('PASS_NATIVE_FRLG_LEAGUE_SAVE '..edition);love.event.quit(0)
end
