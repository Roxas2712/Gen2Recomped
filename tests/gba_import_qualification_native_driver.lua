-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Independent import/title acceptance before new UI tests consume the cache.
return function(game)
 local U,J=require('tests.drivers.util'),require('src.link.Json')
 local version=require('src.core.GameVersion').get();local out=assert(os.getenv('EDITION_QA_OUT'))
 assert(love.filesystem.getIdentity():match('^oasc%-edition%-qa%-'..version..'%-'))
 for _,event in ipairs{'keypressed','keyreleased','textinput','gamepadpressed','gamepadreleased','joystickpressed',
  'joystickreleased','joystickaxis','joystickhat','touchpressed','touchreleased','touchmoved','mousepressed','mousereleased'}do love[event]=function()end end
 game.input:reset()
 local ready=require('src.import.RomImporter').readyReport(version)
 assert(ready.ok,'Full selected-cartridge import is not ready: '..tostring(ready.why))
 assert(require('src.import.Gen3HallPcAssets').valid(game.data.constants.gen3HallPc,version))
 local itemCount=0
 for _,def in pairs(game.data.items)do
  assert(type(def.registrability)=='number'and def.registrability>=0 and def.registrability<=255,
    'Own item-table import is missing the registrability byte')
  itemCount=itemCount+1
 end
 assert(itemCount>0)
 local frlg=version=='firered'or version=='leafgreen'
 if frlg then
  assert(game.data.constants.gen3FRLGTitle.cry==(version=='firered'and'CHARIZARD'or'VENUSAUR'))
 else
  assert(game.data.constants[version=='emerald'and'gen3EmeraldPresentation'or'gen3RsPresentation'].version==version)
 end
 game:returnToTitle();U.wait(600)
 local title=game.stack:top()
 if frlg then assert(getmetatable(title)==require('src.ui.Gen3TitleFRLG')and title.native and title.phase=='run')
 else assert(getmetatable(title)==require('src.ui.Gen3RsBoot')and title.kind=='title'and title.version==version)end
 local Save=require('src.core.SaveSerializer');local before=Save.encode(game.save);local rng=love.math.getRandomState()
 assert(require('src.render.GraphicsScope').call(title.draw,title))
 assert(Save.encode(game.save)==before and rng==love.math.getRandomState(),'Title draw changed save/RNG')
 local name='qualified-import-own-native-title';assert(U.shot(game,out..'/'..name..'.png'))
 local report={status='pass',edition=version,preparedFixture=true,continuousStory=false,
  importQualification=true,completeReadyReport=true,ownNativeTitle=true,drawPreservesSaveRng=true,
  ownItemRegistrabilityCount=itemCount,captures={name}}
 local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()
 print('PASS_NATIVE_GBA_IMPORT_QUALIFICATION');love.event.quit(0)
end
