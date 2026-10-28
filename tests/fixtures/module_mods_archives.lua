-- Real LÖVE archive mounting/filesystem, restricted to the named QA profile.
-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
return function(config)
 local fs=love.filesystem
 assert(fs.getSaveDirectory():find('oasc-module-mods-qa-',1,true),'isolated QA profile required')
 local Mods=require('src.mods.LauncherMods');local n=0
 local function check(value,message)assert(value,message);n=n+1 end
 local function install(path,game)
  return Mods.installFromRelease('qa-module-package',{version='1.0.0',zip={url='https://example.invalid/qa.zip'}},path,game)
 end
 check(install(config.good,'crystal'),'the real scoped release installer accepts the matching ZIP')
 local folder=assert(Mods.folderFor('qa-module-package'))
 local original=assert(fs.read(folder..'/manifest.json'))
 for _,name in ipairs{'wrong_game','wrong_generation','wrong_engine','wrong_api'}do
  local ok=install(config[name],'crystal')
  check(not ok,'the ZIP itself must reject '..name)
  check(fs.read(folder..'/manifest.json')==original,'a rejected ZIP preserves the previous installed manifest')
 end
 check(not install(config.good,'pinballrs'),'RPG archives cannot be installed for a native cartridge')
 check(fs.read(folder..'/manifest.json')==original,'an invalid target preserves the existing package')
 check(Mods.installZip(config.manual),'manual ZIP import retains its existing account-free global behavior')
 check(Mods.folderFor('qa-manual-package')~=nil,'the manually imported package exists only in the QA profile')
 return n
end
