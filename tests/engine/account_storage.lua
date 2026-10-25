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
check(not P.check() and not Saves.save({version='red',player={name='Guest'}}) and writes==0,'guest saves are refused at the real persistence boundary before any writes')
check(not Saves.createSlot('red') and not Saves.writeSlot('red','slot1',{player={}}) and #Saves.listSlots('red')==0 and writes==0,'guest imports, slot creation and save browsing cannot bypass registration')
local B=require('src.storage.PokemonBank')
local stored,bankReason=B.keep({schema=1,source={version='red'},mon={species='BULBASAUR',level=5,moves={}},canonical={dex=1,moves={}}})
check(not stored and bankReason:find('confirm your email',1,true) and #B.list()==0 and writes==0,'direct Bank storage access cannot bypass the account gate or create guest copies')
signed=true;account='17'
check(not P.check() and not files[P.FILE],'sign-in never silently assigns pre-existing storage')
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
check(opened.kind=='play' and opened.version=='red' and not ui.played,'the account gate runs before any play animation or game handoff')
account='17';P.resume(ui,opened)
check(ui.played=='red','confirmed storage linking resumes the originally requested game')
local network=0;local wrongStore={accountId='29',list=function() network=network+1;return {} end,read=function() network=network+1 end,write=function() network=network+1 end}
check(not require('src.import.CloudSync').syncOne(wrongStore,'red','slot1') and network==0,'a cloud store opened for another account cannot read or upload local saves')
print('Account-owned storage: '..n..' checks passed')
