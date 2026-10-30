-- Real profile/save APIs; no network, ROMs or user data.
package.path='./?.lua;'..package.path
love=require('tests.love_stub')
local n=0;local function check(v,m)assert(v,m);n=n+1 end
local files={};local fs={}
function fs.read(p)return files[p]end
function fs.write(p,b)files[p]=b;return true end
function fs.remove(p)files[p]=nil;return true end
function fs.createDirectory()return true end
function fs.getInfo(p)
 if files[p]then return{type='file',size=#files[p]}end
 for key in pairs(files)do if key:sub(1,#p+1)==p..'/'then return{type='directory'}end end
end
function fs.getDirectoryItems(p)local out={};for key in pairs(files)do local name=key:sub(#p+2);if key:sub(1,#p+1)==p..'/'and not name:find('/')then out[#out+1]=name end end;return out end
love.filesystem=fs
local id
package.loaded['src.cloud.RetroCloud']={signedIn=function()return id~=nil end,accountId=function()return id end}
local P=require('src.storage.AccountStorage');P.enable()
local Saves=require('src.core.SaveData');local Setup=require('src.storage.CloudSetup')
local S=require('src.core.SaveSerializer')
local ui={ready={},_settings=function()return Saves.loadOptions()end}
check(Setup.defaultEnabled({cloudAutoSync=false}),'the old disabled-by-default setup offers account sync on login')
check(not Setup.defaultEnabled({cloudSetupVersion=1,cloudAutoSync=false}),'an explicit opt-out from the new setup is respected')
local guest=assert(Saves.createSlot('red'));assert(Saves.writeSlot('red',guest,{version='red',player={name='Guest'},party={}}))
Saves.persistenceFs().write('mod_storage/shared/example/value.lua','guest mod choice')
local original=files['profiles/guest/saves/red/'..guest..'.lua']
id='17'
local ready,sources=Setup.prepare(ui,{cloudSync=true,restore=true})
check(ready=='review'and sources[1]=='guest'and not P.owner(),'existing guest progress requires one ownership choice')
check(Setup.prepare(ui,{cloudSync=true,restore=true},'guest')and P.check(),'the ownership choice completes the account connection')
check(Saves.peekSlot('red',guest).player.name=='Guest'and files['profiles/guest/saves/red/'..guest..'.lua']==original,'adoption preserves save bytes at their original path')
check(Saves.persistenceFs().read('mod_storage/shared/example/value.lua')=='guest mod choice','adopted mod settings stay in the same profile')
check(Saves.loadOptions().cloudAutoSync and ui._cloudRestoreOnce,'one setup enables automatic normal saves and restore')
check(not Saves.loadOptions().gameCacheUpload,'setup does not opt into ROM/import upload')
id=nil;check(not Saves.peekSlot('red',guest),'signing out creates a fresh guest view, hiding adopted account progress')
id='29';check(not Saves.peekSlot('red',guest),'another account cannot access adopted guest progress')
check(Setup.prepare(ui,{cloudSync=true})and P.check(),'a clean device profile needs no additional ownership prompt')
check(Saves.persistenceFs()._accountPrefix~='profiles/guest/'and not Saves.peekSlot('red',guest),'another account gets a separate private profile')
id='17';check(P.check()and Saves.peekSlot('red',guest).player.name=='Guest','returning to the owner restores the adopted profile')
check(Setup.prepare(ui,{cloudSync=false})and not Saves.loadOptions().cloudAutoSync and not ui._cloudRestoreOnce,'opt-out persists local saves and disables automatic restore')
local C=require('src.import.CloudSync')
local remote=S.encode({version='blue',player={name='Cloud fixture'},party={},playTime=360})
local writes=0;local store={kind='fixture',profileScope='fixture',list=function(path)return path=='saves/blue'and{'remote.lua'}or{}end,
 read=function(path)if path=='saves/blue/remote.lua'then return remote end end,write=function()writes=writes+1;return true end}
assert(C.restoreVersions(store,{'blue'}))
local rows=Saves.listSlots('blue');local restored=assert(rows[1]).id
check(Saves.activeSlot('blue')==restored,'a fresh device selects its restored progress instead of starting a new game')
local st=C.loadState(C.stateKey(store));local link=st.links.blue[restored]
check(link.localHash==C.hash(Saves.readSlotBytes('blue',restored)),'a restore checkpoints the locally stamped bytes as well as the remote bytes')
check(C.syncOne(store,'blue',restored,true,nil,true)=='same'and writes==0,'local account stamping cannot turn a restored save into a new upload or false conflict')
local pool={['saves/yellow/older.lua']=S.encode({version='yellow',player={name='Older'},party={}}),
 ['saves/yellow/newer.lua']=S.encode({version='yellow',player={name='Latest'},party={}}),
 ['saves/yellow/older.info.lua']=S.encode({updated=100}),['saves/yellow/newer.info.lua']=S.encode({updated=200})}
local more={kind='fixture',profileScope='more',list=function()return{'older.lua','newer.lua'}end,read=function(p)return pool[p]end,write=function()error('restore must not upload')end}
assert(C.restoreVersions(more,{'yellow'}))
local active=Saves.activeSlot('yellow')
check(Saves.peekSlot('yellow',active).player.name=='Latest','fresh-device Continue selects the most recently uploaded save')
for _,row in ipairs(Saves.listSlots('yellow'))do if Saves.peekSlot('yellow',row.id).player.name=='Older'then assert(Saves.setActiveSlot('yellow',row.id))end end
assert(C.restoreVersions(more,{'yellow'}))
check(Saves.peekSlot('yellow',Saves.activeSlot('yellow')).player.name=='Older','later restores preserve the player’s deliberate active-slot choice')
local opts=Saves.loadOptions();opts.cloudAutoSync=true;assert(Saves.saveOptions(opts))
local O=require('src.storage.CloudOutbox')
assert(Saves.save({version='ruby',player={name='First save'},party={},meta={playthroughId='first-cloud-adventure'}}))
local first=Saves.activeSlot('ruby');local journal=S.decode(Saves.persistenceFs().read(O.FILE))
check(first and journal.pending['ruby/'..first],'a first-ever adventure queues its first save without waiting for an app restart')
check(Saves.peekSlot('ruby',first).meta.playthroughId=='first-cloud-adventure','giving the first save a slot preserves its playthrough identity')
local writeSlot=Saves.writeSlot;Saves.writeSlot=function()return false,'Fixture disk full'end
local downloaded,problem=C.pullNew(store,{device='fixture',links={}},'blue');Saves.writeSlot=writeSlot
check(not downloaded and problem=='Fixture disk full','failed local restore writes cannot be reported as a successful cloud restore')
print('Simple cloud setup: '..n..' checks passed')
