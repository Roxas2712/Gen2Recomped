package.path='./?.lua;'..package.path
love=require('tests.love_stub')
local n=0;local function check(v,m) assert(v,m);n=n+1 end
local files,writes={},0
local fs={read=function(p) return files[p] end,write=function(p,b) writes=writes+1;files[p]=b;return true end,
 remove=function(p) files[p]=nil;return true end,createDirectory=function() return true end,
 getInfo=function(p) return files[p] and {type='file',size=#files[p]} end,getDirectoryItems=function() return {} end}
love.filesystem=fs
local signed,account=false,nil
package.loaded['src.cloud.RetroCloud']={signedIn=function() return signed end,accountId=function() return account end}
local Saves=require('src.core.SaveData');Saves.persistenceFs=function() return fs end
local P=require('src.storage.AccountStorage');P.enable()
check(not P.check() and P.saveCheck() and Saves.save({version='red',player={name='Guest'}}),'guest game progress is saved locally without granting Bank or cloud access')
local guestSlot=assert(Saves.createSlot('red'))
check(Saves.writeSlot('red',guestSlot,{player={name='Local'}}) and #Saves.listSlots('red')>0,'guest imports, slots and local save browsing work without registration')
local guestWrites=writes
local B=require('src.storage.PokemonBank')
local stored,bankReason=B.keep({schema=1,source={version='red'},mon={species='BULBASAUR',level=5,moves={}},canonical={dex=1,moves={}}})
check(not stored and bankReason:find('confirm your email',1,true) and #B.list()==0 and writes==guestWrites,'direct Bank storage access cannot bypass the account gate or create guest copies')
signed=true;account='17'
check(not P.check() and not files[P.FILE],'sign-in never silently assigns pre-existing storage')
check(P.saveCheck(),'a signed-in account may continue local play before choosing cloud ownership')
local localSave={meta={playthroughId='local-adventure'}}
check(P.stamp(localSave)and localSave.meta.localOnly and not localSave.meta.retroAccountId and not files[P.FILE],'local progress does not silently become cloud-owned after sign-in')
local started,openedBefore={},0
local localLauncher={ready={},_openAccount=function()openedBefore=openedBefore+1 end,play=function(_,version)started[#started+1]=version end}
P.install(localLauncher)
for _,version in ipairs(require('src.core.GameVersion').ORDER)do localLauncher.ready[version]=true;localLauncher:play(version)end
check(#started==#require('src.core.GameVersion').ORDER and openedBefore==0,'every ready edition, including Crystal, starts without opening the profile for an unlinked signed-in account')
localLauncher.ready.crystal=false;localLauncher:play('crystal')
check(#started==#require('src.core.GameVersion').ORDER and openedBefore==0,'an unimported game cannot trigger an account prompt before the ready check')
files['saves/red/slot1.lua']='original save';files['bank/entries/original.lua']='original Bank copy'
check(P.bind() and P.check() and files['saves/red/slot1.lua']=='original save' and files['bank/entries/original.lua']=='original Bank copy','explicit storage linking preserves existing saves and Bank bytes')
local save={meta={playthroughId='unchanged'},player={name='Owner'}}
check(P.stamp(save) and save.meta.retroAccountId=='17' and save.meta.playthroughId=='unchanged','new save metadata carries the stable account ID alongside its playthrough ID')
signed=false
check(P.check(),'a previously confirmed local account can continue offline after its online session expires')
account='29';signed=true;local binding=files[P.FILE];local before=writes
check(not P.check() and not P.bind() and not Saves.writeSlot('red','slot1',save) and files[P.FILE]==binding and writes==before,'switching accounts cannot reassign storage or overwrite another account’s saves')
account='17';files[P.FILE]='damaged account binding';before=writes
check(not P.check() and not P.bind() and writes==before and files[P.FILE]=='damaged account binding','an unreadable account binding is preserved rather than automatically claimed again')
files[P.FILE]=binding
local opened;local ui={_openAccount=function(self,after) opened=after;self._accountOverlay={} end,play=function(self,v) self.played=v end}
P.install(ui);account=nil;ui:play('red')
check(opened.kind=='play' and opened.version=='red' and opened.storagePrompt and not ui.played,'the first guest play offers cloud saves once before a handoff')
ui._settings=function() return {launcherSaveStorageChoice='local'} end
ui:play('blue');check(ui.played=='blue','declining cloud keeps subsequent play local and never reopens account login')
account='17';P.resume(ui,opened)
check(ui.played=='red','confirmed storage linking resumes the originally requested game')
local network=0;local wrongStore={accountId='29',list=function() network=network+1;return {} end,read=function() network=network+1 end,write=function() network=network+1 end}
check(not require('src.import.CloudSync').syncOne(wrongStore,'red','slot1') and network==0,'a cloud store opened for another account cannot read or upload local saves')
print('Account-owned storage: '..n..' checks passed')
