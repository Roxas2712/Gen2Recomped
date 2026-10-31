-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Prepared route fixture; the rescue and starter still use native scripts.
-- This is not an ordinary campaign or an admissible story SAVE origin.
return function(game)
 local U=require('tests.drivers.util');local J=require('src.link.Json')
 local S=require('src.core.SaveSerializer');local V=require('src.core.GameVersion')
 local out=assert(os.getenv('EDITION_QA_OUT'));assert(V.get()=='emerald')
 assert(love.filesystem.getIdentity():match('^oasc%-edition%-qa%-emerald%-'))
 assert(require('src.import.RomImporter').readyReport('emerald').ok)
 game.input:reset();U.freshSave(game)
 assert(#game.save.party==0,'Rescue must receive its starter from the script')
 U.teleport(game,'MAP_G00_N16',7,15,'up');U.wait(30)
 local report={status='running',edition='emerald',preparedFixture=true,continuousStory=false,captures={}}
 local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
 local function shot(name)
  local before,rng=S.encode(game.save),love.math.getRandomState();local top=game.stack:top()
  assert(require('src.render.GraphicsScope').call(top.draw,top))
  assert(before==S.encode(game.save)and rng==love.math.getRandomState(),'Rescue draw changed gameplay state')
  assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
 end
 local sawChoice,sawConfirm,sawBattle=false,false,false
 for frame=1,12000 do
  local top=game.stack:top()
  if getmetatable(top)==require('src.ui.Gen3StarterSelect')then
   assert(#game.save.party==0,'Starter appeared before native confirmation')
   if not sawChoice then sawChoice=true;shot('native-emerald-rescue-starter-pick')end
   if top.stage=='confirm'and top.picGrow>=14 and not sawConfirm then sawConfirm=true;shot('native-emerald-rescue-starter-confirm')end
  elseif top and top.enemy and top.enemy.mon then
   assert(top.enemy.mon.species=='ZIGZAGOON'and top.enemy.mon.level==2,'Emerald rescue must use its own level-two Zigzagoon')
   if not sawBattle then
    assert(#game.save.party==1 and game.save.party[1].level==5,'Original rescue starter must be level five')
    sawBattle=true;report.opponent={species=top.enemy.mon.species,level=top.enemy.mon.level}
    report.starter={species=game.save.party[1].species,level=game.save.party[1].level}
    shot('native-emerald-rescue-zigzagoon-battle')
   end
  end
  if sawBattle and top==game.overworld and game.overworld.map.id=='MAP_G01_N04'and not game.overworld.runner:isRunning()then break end
  if frame%8==1 then U.tap(game,'a')else U.wait(1)end
 end
 assert(sawChoice and sawConfirm and sawBattle,'Native rescue did not show every starter/battle stage')
 assert(game.stack:top()==game.overworld and game.overworld.map.id=='MAP_G01_N04'and not game.overworld.runner:isRunning(),'Original rescue did not reach Birch lab')
 local C=require('src.script.Gen3Commands');local choice=C.getVar(game.save,game.data.constants.gen3Starters.var)
 assert(game.save.party[1].species==game.data.constants.gen3Starters.species[choice+1],'Native starter choice was not preserved')
 shot('native-emerald-rescue-birch-lab')
 report.status='pass';report.nativeRescueScript=true;report.drawPreservesSaveRng=true;persist()
 print('PASS_NATIVE_EMERALD_FIRST_RESCUE');love.event.quit(0)
end
