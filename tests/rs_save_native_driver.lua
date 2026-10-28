-- Prepared save dialogs write only this job's isolated active save slot.
return function(game)
  local U=require('tests.drivers.util');local J=require('src.link.Json')
  local Save=require('src.core.SaveSerializer');local IO=require('src.core.SaveData')
  local Start=require('src.ui.Gen3StartMenu');local Native=require('src.ui.Gen3RsSaveMenu')
  local Stats=require('src.pokemon.Gen3GameStats');local edition=require('src.core.GameVersion').get()
  local out=assert(os.getenv('EDITION_QA_OUT'))
  assert(love.filesystem.getIdentity():match('^oasc%-edition%-qa%-'..edition..'%-'))
  assert(Native.available(game)and require('src.import.RomImporter').readyReport(edition).ok)
  for _,event in ipairs({'keypressed','keyreleased','textinput','gamepadpressed','gamepadreleased',
    'joystickpressed','joystickreleased','joystickaxis','joystickhat','touchpressed','touchreleased',
    'touchmoved','mousepressed','mousereleased'})do love[event]=function()end end
  game.input:reset();U.freshSave(game);U.teleport(game,'MAP_G00_N11',11,9,'right');U.wait(90)
  local world=game.stack:top();assert(IO.saveFileExists(edition)==false)
  local C=require('compat.gen1-rs.Constants').new(require('compat.gen1-rs.Loader').new(edition))
  local function flag(id,on)game.save.flags[('FLAG_G3_%04X'):format(id)]=on or nil end
  local dexFlag=C:flag('FLAG_SYS_POKEDEX_GET');local national=C:flag('FLAG_SYS_NATIONAL_DEX')
  local natVar=C:var('VAR_NATIONAL_DEX');flag(dexFlag,true)
  for id=C:flag('FLAG_BADGE01_GET'),C:flag('FLAG_BADGE01_GET')+7 do flag(id,true)end
  game.save.pokedex.owned={TREECKO=true,PIKACHU=true,MEWTWO=true}
  game.save.playTime={hours=123,minutes=45,seconds=0};game.save.player.name='AURORA'
  local report={edition=edition,status='running',preparedSaveFixture=true,continuousStory=false,
    captures={},cases={},drawSaveAndRngPreserved=true,normalPlayTimeExcluded=true,writes=0,saveSounds=0}
  local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
  local function shot(name)
    local bytes=Save.encode(game.save);local rng=love.math.getRandomState()
    assert(require('src.render.GraphicsScope').call(function()game.stack:top():draw()end))
    assert(bytes==Save.encode(game.save)and rng==love.math.getRandomState(),'Save dialog draw changed save/RNG')
    assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
  end
  local function press(key)
    game.input:overlayPressed(key);U.wait(1);game.input:overlayReleased(key);U.wait(3)
  end
  local function liveBytes()
    local copy={};for k,v in pairs(game.save)do if k~='playTime'then copy[k]=v end end
    return Save.encode(copy)
  end
  local function disk()return love.filesystem.read(IO.saveFilename(edition))end
  local screen,owner
  local function open()
    assert(game.stack:top()==world)
    owner=Start.new(game)
    for i,row in ipairs(owner.rows)do if row.key=='save'then owner.index=i end end
    game.stack:push(owner);press('a');screen=game.stack:top()
    assert(getmetatable(screen)==Native and screen.phase=='confirm'and owner.rsSaveModal)
    assert(screen.scene.layout(screen.session)=='rs'and screen.scene.locationName(screen.session)=='DEWFORD TOWN')
    return screen
  end
  local function cancelToWorld(key)
    press(key);assert(game.stack:top()==owner and not owner.rsSaveModal)
    press('b');assert(game.stack:top()==world)
  end
  for _,gender in ipairs({'boy','girl'})do
    game.save.player.gender=gender;game.save.options.gen3Frame=gender=='girl'and 20 or 1
    local before=liveBytes();open()
    assert(screen.scene.hasDex(screen.session)and screen.scene.countBadges(screen.session)==8)
    assert(screen.scene.countDex(screen.session)==2,'Regional save summary counted non-Hoenn MEWTWO')
    assert(screen.session.playTime.hours==123 and screen.session.playTime.minutes==45)
    shot('save-'..gender..'-original-stats-and-frame')
    if gender=='boy'then cancelToWorld('b')else press('down');cancelToWorld('a')end
    assert(before==liveBytes()and not disk())
  end
  flag(dexFlag,false);open();assert(not screen.scene.hasDex(screen.session))
  shot('save-native-stats-without-pokedex');cancelToWorld('b');flag(dexFlag,true)
  game.save.nationalDex=true;flag(national,true);game.save.gen3Vars=game.save.gen3Vars or{}
  game.save.gen3Vars[natVar]=0x302
  open();assert(screen.scene.countDex(screen.session)==3,'Native National gate did not include MEWTWO')
  shot('save-native-national-summary');cancelToWorld('b')
  game.save.nationalDex=nil;flag(national,false);game.save.gen3Vars[natVar]=nil
  report.cases.bothGenderOriginalStatsAndFrame=true;report.cases.optionalDexPanel=true
  report.cases.regionalAndNationalSummary=true;report.cases.noAndBCancelPreserveBytes=true
  local actualWrite=game.writeSave;local mode='actual'
  game.writeSave=function(g)
    assert(screen.savingDrawn and screen.scene._phase=='saving','IO preceded actual saving renderer')
    report.writes=report.writes+1
    if mode=='false'then return false end
    if mode=='error'then error('own native QA write refusal')end
    return actualWrite(g)
  end
  local Sound=require('src.core.Sound');local play=Sound.playId
  local saveSe=assert(game.data.constants.gen3RsPresentation.songIds.SE_SAVE)
  Sound.playId=function(data,id,...)
    if id==saveSe then report.saveSounds=report.saveSounds+1 end
    return play(data,id,...)
  end
  local function captureSaving(name)
    -- Hold this prepared view for its final-renderer capture. The engine
    -- consumes capturePath before draw; arming it inside draw is too late.
    local update=screen.update;local armed=false;local path=out..'/'..name..'.png'
    function screen:update(dt)
      if self.scene._phase=='saving_msg'then
        local f=io.open(path,'rb')
        if f then f:close();self.update=update
        else
          if not armed then
            armed=true;game.capturePath=path
            report.captures[#report.captures+1]=name;persist()
          end
          return
        end
      end
      return update(self,dt)
    end
    report.preparedSavingCaptureWait=true
  end
  local function waitPhase(want)
    for _=1,90 do if screen.scene._phase==want then return end;U.wait(1)end
    error('Native save phase did not reach '..want)
  end
  local counter=Stats.get(game.save,0)
  open();captureSaving('save-first-original-saving-message');press('a')
  assert(screen.scene._phase~='overwrite');waitPhase('saved')
  assert(report.writes==1 and report.saveSounds==1 and screen.wrote)
  shot('save-first-original-saved-message');U.wait(90)
  assert(game.stack:top()==world and not owner.rsSaveModal and IO.saveFileExists(edition))
  local original=disk();assert(original and Save.decode(original).gen3Stats[0]==counter+1)
  report.cases.firstSaveSkipsOverwrite=true;report.cases.savedAutoClosesAtOriginalDelay=true
  local before=liveBytes()
  open();press('a');assert(screen.phase=='overwrite'and screen.index==1)
  shot('save-native-existing-slot-overwrite');cancelToWorld('b')
  assert(disk()==original and liveBytes()==before)
  open();press('a');press('down');shot('save-native-overwrite-no');cancelToWorld('a')
  assert(disk()==original and liveBytes()==before and report.writes==1)
  report.cases.existingSaveRequiresOverwrite=true;report.cases.overwriteNoAndBPreserveBytes=true
  for _,failure in ipairs({'false','error'})do
    mode=failure;local unchanged=liveBytes();open();press('a');press('a');waitPhase('save_failed')
    assert(not screen.wrote and disk()==original and unchanged==liveBytes()and report.saveSounds==1)
    local font=screen.load('src.ui.game3.frlg_font')
    local message=font.wrap(screen.load('src.core.game3.rom_text').plain('gText_SaveError'),208)
    local _,newlines=message:gsub('\n','')
    assert(newlines<2,'The original failure message must fit the actual two-line dialog')
    shot('save-native-'..failure..'-write-error');cancelToWorld('a')
  end
  report.cases.falseWriteNeverReportsSaved=true;report.cases.thrownWriteNeverReportsSaved=true
  mode='actual';open();press('a');captureSaving('save-overwrite-original-saving-message');press('a');waitPhase('saved')
  assert(report.writes==4 and report.saveSounds==2 and screen.wrote)
  shot('save-overwrite-original-saved-message');U.wait(90)
  assert(game.stack:top()==world and Save.decode(disk()).gen3Stats[0]==counter+2)
  assert(Save.decode(disk()).player.name=='AURORA')
  for _,name in ipairs({'save-first-original-saving-message','save-overwrite-original-saving-message'})do
    local f=assert(io.open(out..'/'..name..'.png','rb'));f:close()
  end
  report.cases.savingRenderedBeforeExactlyOneWrite=true;report.cases.successfulOverwriteUsesActiveHostSlot=true
  game.writeSave=actualWrite;Sound.playId=play
  report.status='pass';persist();love.event.quit(0)
end
