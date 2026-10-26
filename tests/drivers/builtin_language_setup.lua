-- Real first-run -> US import -> optional language source -> native game.
local function wait(n)for _=1,n do coroutine.yield()end end
return function(ui)
 local N=require('src.translation.NativeLanguages');local W=require('src.import.NativeLanguageSetup')
 local First=require('src.import.FirstRun');local T=require('src.translation.Service')
 local version=assert(os.getenv('NATIVE_SETUP_GAME'))
 local Save=require('src.core.SaveData')
 ui._launcherSequence=nil;if ui._introSound then ui._introSound:stop()end
 ui._setupPending=nil;First.open(ui)
 -- Every offered script must be readable before downloading any font/model.
 for _,id in ipairs({'en','de','ja','ko','zh','zh-Hant'})do
  First.action(ui,'language:'..id);wait(2)
  local font=assert(ui.hintFont)
  for _,name in pairs(N.NAMES)do assert(font:hasGlyphs(name),'Missing language-name glyph: '..id..' / '..name)end
  for _,text in pairs(require('src.translation.NativeLanguageCatalog')[id] or{})do assert(font:hasGlyphs(text),'Missing setup glyphs: '..id..' / '..text)end
  love.graphics.captureScreenshot('setup-language-'..id..'.png');wait(2)
 end
 First.action(ui,'language:de');assert(First.finish(ui));wait(2)
 assert(Save.loadOptions().nativeLanguageDefault=='de','First-run choice did not become the offer preference')
 assert(not love.filesystem.getInfo('mods/german_rom_source/manifest.json'),'A separately installed mod is present in the clean profile')
 assert(love.filesystem.getInfo(N.BUNDLE..'/manifest.json'),'Built-in profile payload absent')
 ui:startPath(assert(os.getenv('NATIVE_SETUP_BASE')))
 for _=1,36000 do if ui.workState~='working'and ui.workState~='idle' and not ui.probeTask then break end;wait(1)end
 assert(ui.ready[version] and ui.workState=='complete',ui.detail or 'US import failed')
 for _=1,300 do if ui._nativeLanguage then break end;wait(1)end
 local f=assert(ui._nativeLanguage,'Successful US import did not offer the selected language')
 assert(f.version==version and f.language=='de' and f.state.nextEntry.id==version..'_de','Wrong game or prerequisite in the offer')
 if N.requirement(version).generation==3 then assert(f.state.baseReady,'US GBA import did not retain its own exact base')end
 wait(3);love.graphics.captureScreenshot('native-language-offer.png');wait(2)
 ui._languageImportEntry=f.state.nextEntry;ui._languageImportManifest=f.state.manifest
 ui:_installModImport(N.ID,nil,'invalid source')
 assert(not ui.modNotice.ok and ui._nativeLanguage and not Save.loadOptions().nativeLanguages,'Wrong source was accepted or changed the selected language')
 ui:_installModImport(N.ID,assert(os.getenv('NATIVE_SETUP_SOURCE')))
 assert(ui.modNotice.ok and ui._nativeLanguage.state.ready,ui.modNotice.text)
 W.action(ui,'use');assert(not ui._nativeLanguage and Save.loadOptions().nativeLanguages[version]=='de','Ready source selection was not retained')
 ui._settingsCache=nil;wait(2)
 ui:play(version)
 local game
 for _=1,1800 do game=package.loaded['src.core.Game'];if game and game.mods and game.mods.exports.german_rom_source then break end;wait(1)end
 assert(game and game.mods,ui._lastModPreflight and ui._lastModPreflight.log or 'Play did not reach the game')
 local exports=assert(game.mods.exports.german_rom_source)
 assert(exports.sessionBoot and exports.localizationBackend=='native-rom-language-v1','The built-in pack did not own this session')
 assert(not exports.startup.open,'Standalone mod setup intercepted the integrated flow')
 print('BUILTIN_LANGUAGE_SETUP_OK',version)
 return assert(loadfile('native-game-driver.lua'))()(game)
end
