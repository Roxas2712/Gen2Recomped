return function(game)
  local U=require('tests.drivers.util')
  local V=require('src.core.GameVersion')
  assert(V.get()=='ruby')
  assert(game.data.pokemon.TREECKO)
  assert(game.data.font and #game.data.font.pages.normal.widths==254)
  print('[driver] Ruby native dataset loaded')
  U.newGame(game)
  assert(game.overworld and game.stack:top()==game.overworld,'Ruby new game did not reach field')
  love.graphics.captureScreenshot('ruby-new-game.png');U.wait(3)
  -- Walk out through the cartridge's dynamic warp and let the normal
  -- Littleroot/Mom script take the player into the new house.
  U.hold(game,'right',48);U.wait(60)
  for i=1,4000 do
    if i%8==1 then U.tap(game,'a') else U.wait(1) end
    if game.overworld.map.id=='MAP_G01_N00' and game.stack:top()==game.overworld
       and not game.overworld.runner:isRunning() then break end
  end
  assert(game.overworld.map.id=='MAP_G01_N00','truck dynamic warp/Mom scene failed')
  assert(not game.overworld.runner:isRunning(),'opening scene stayed locked')
  local S=require('src.core.SaveData')
  assert(S.save(game.save,game.mods))
  assert(S.saveFileExists('ruby') and not S.saveFileExists('emerald'))
  local loaded=assert(S.load('ruby'))
  assert(loaded.version=='ruby' and loaded.player.name==game.save.player.name)
  love.graphics.captureScreenshot('ruby-opening-house.png');U.wait(12)
  print('[driver] PASS actual truck exit, Mom scene, own save/reload')
  local C=require('src.script.Gen3Commands')
  local Pokemon=require('src.pokemon.Pokemon')
  local mon=Pokemon.new(game.data,'MEWTWO',100)
  mon.moves={{id='PSYCHIC',pp=99,maxPp=99}}
  game.save.party={mon}
  U.teleport(game,'MAP_G11_N03',5,3,'up');U.wait(30)
  local battled,complete,shown=false,false,false
  for frame=1,14000 do
    if frame%12==1 then U.tap(game,'a') else U.wait(1) end
    local top=game.stack:top()
    local name=top and top.trainer and tostring(top.trainer.name):upper()
    if top and top.enemy and name and name:find('ROXANNE',1,true) then
      battled=true
      if top.phase=='menu' and not top.showEnemyTrainer and not shown then
        love.graphics.captureScreenshot('ruby-roxanne-battle.png');U.wait(12);shown=true
      end
    end
    if battled and game.save.flags[C.flagKey(0xA5)] and top==game.overworld and not game.overworld.runner:isRunning() then
      assert(game.save.flags[C.flagKey(0x807)],'Stone Badge missing')
      assert(game.save.inventory.TM39==1,'native TM39 reward missing')
      complete=true;break
    end
  end
  assert(complete,'Roxanne battle/reward did not finish')
  love.graphics.captureScreenshot('ruby-roxanne-reward.png');U.wait(12)
  love.filesystem.write('edition-result.json',require('src.link.Json').encode({status='pass',edition='ruby',newGame=true,allModsDisabled=true,fullStoryTested=false}))
  print('[driver] PASS Ruby native new game')
  love.event.quit(0)
end
