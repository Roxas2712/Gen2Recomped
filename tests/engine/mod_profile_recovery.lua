package.path='./?.lua;'..package.path
love=require('tests.love_stub')
local S=require('src.core.SaveSerializer');local function clone(v) return S.decode(S.encode(v)) end
local n=0;local function check(v,m) assert(v,m);n=n+1 end
local fs=love.filesystem
local options={mods={one=true},modInstallSources={one={repo='author/one',version='1.0.0'}}}
local cache={prefix='red/',root=function() end,write=function(p,b) return fs.write(p,b) end,remove=function(p) return fs.remove(p) end,removeDir=function(p) return fs.remove(p) end}
package.loaded['src.import.CacheFs']=cache
package.loaded['src.core.SaveData']={loadOptions=function() return clone(options) end,saveOptions=function(v) options=clone(v);return true end,persistenceFs=function() return fs end}
local P=require('src.mods.LauncherMods')
P.folderFor=function(id) local p='mods/'..id;return fs.getInfo(p) and p or nil end
P.checkoutAt=function() end
fs.write('mods/one/manifest.json','{"id":"one","version":"1.0.0"}')
fs.write('mods/one/assets/original.txt','ORIGINAL BYTES')
local oldBase=S.encode({scope='account',base='old-base'})
fs.write('mod_profile_sync.lua',oldBase)
local snapshot=assert(P.backupProfile({'one','new'}))
check(cache.prefix=='red/' and fs.getInfo('mod_profile_recovery.lua'),'backup restores the borrowed cache prefix and persists a recovery marker')
check(fs.read(snapshot.root..'/one/assets/original.txt')=='ORIGINAL BYTES','the full old package tree is preserved before replacement')
fs.write('mods/one/manifest.json','{"id":"one","version":"2.0.0"}')
fs.write('mods/one/new.txt','NEW EXTRA')
fs.write('mods/new/manifest.json','NEW PACKAGE')
fs.write('mod_profile_sync.lua',S.encode({base='new-base'}));options.mods.one=false;options.mods.new=true
check(P.restoreProfile(snapshot),'an interrupted stack can recover the previous complete profile')
check(fs.read('mods/one/manifest.json'):find('1.0.0',1,true) and not fs.getInfo('mods/one/new.txt'),'recovery restores the exact old version and removes new-only files')
check(not fs.getInfo('mods/new') and options.mods.one and not options.mods.new,'newly added packages and their enable flags roll back together')
check(fs.read('mod_profile_sync.lua')==oldBase,'recovery restores the previous conflict base rather than publishing a half-applied stack later')
check(not fs.getInfo('mod_profile_recovery.lua') and not fs.getInfo(snapshot.root),'successful recovery clears its marker and backup only after verification')
local missing=assert(P.backupProfile({'one'}));fs.remove(missing.root..'/one/manifest.json')
fs.write('mods/one/survivor.txt','KEEP')
check(not P.restoreProfile(missing) and fs.read('mods/one/survivor.txt')=='KEEP','an unavailable backup is refused before deleting the current package')
check(not P.restoreProfile({root='../../outside',entries={}}),'a recovery record cannot escape the dedicated backup directory')
P.checkoutAt=function() return '/source/checkout' end
check(not P.backupProfile({'one'}) and fs.read('mods/one/survivor.txt')=='KEEP','source checkouts are never replaced by cloud profiles')
print('Mod profile recovery: '..n..' checks passed')
