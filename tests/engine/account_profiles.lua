package.path='./?.lua;'..package.path
love=require('tests.love_stub')
local n=0;local function check(v,m) assert(v,m);n=n+1 end
local files={};local function names(dir) local out={};for p in pairs(files) do local k=p:match('^'..dir..'/([^/]+)$');if k then out[#out+1]=k end end;return out end
local fs={read=function(p) return files[p] end,write=function(p,b) files[p]=b;return true end,
 remove=function(p) files[p]=nil;return true end,createDirectory=function() return true end,
 getInfo=function(p) return files[p] and {type='file',size=#files[p]} end,getDirectoryItems=names}
love.filesystem=fs
local account='17';local signed=true
package.loaded['src.cloud.RetroCloud']={signedIn=function() return signed end,accountId=function() return account end}
local S=require('src.core.SaveSerializer');local Saves=require('src.core.SaveData');local P=require('src.storage.AccountStorage');P.enable()
files['bank/legacy.lua']='legacy Bank';files['recompiler_device.lua']='installation ID';files['mods/example/main.lua']='shared package'
check(P.bind() and P.check(),'the first confirmed account explicitly links the legacy profile')
local a=Saves.persistenceFs();a.write('options.lua',S.encode({musicVol=2}));a.write('mod_storage/shared/example/value.lua','account A')
local slot=assert(Saves.createSlot('red'));assert(Saves.writeSlot('red',slot,{version='red',player={name='Alice'},party={}}))
check(Saves.peekSlot('red',slot).player.name=='Alice','account A writes and reads its normal save through the real slot API')
account='29'
check(not P.check() and not Saves.peekSlot('red',slot),'another registered account cannot see the first account’s saves before linking its profile')
check(P.bind() and P.check() and files['bank/legacy.lua']=='legacy Bank','account B gets its own profile without migrating or reassigning legacy records')
local b=Saves.persistenceFs()
check(not b.read('bank/legacy.lua') and not b.read('mod_storage/shared/example/value.lua') and b.read('recompiler_device.lua')=='installation ID' and b.read('mods/example/main.lua')=='shared package','Bank and mod data are private while packages and the installation ID remain shared')
local slotB=assert(Saves.createSlot('red'));assert(Saves.writeSlot('red',slotB,{version='red',player={name='Bob'},party={}}))
b.write('options.lua',S.encode({musicVol=6}));b.write('cloud_google.lua','B Google token');b.write('storage_account.lua.tmp','B temp')
check(files['profiles/29/storage_account.lua.tmp']=='B temp' and not files['storage_account.lua.tmp'],'temporary records remain inside the same account profile')
check(Saves.peekSlot('red',slotB).player.name=='Bob' and slotB==slot,'different accounts may use identical slot IDs without collisions')
local task=coroutine.create(function() return P.check(),Saves.persistenceFs().read('options.lua') end)
P.attachTask(task);account='17'
local ok,allowed,opts=coroutine.resume(task)
check(ok and not allowed and S.decode(opts).musicVol==6,'a pending task stays pinned to its original profile and refuses account-changing operations')
check(P.check() and Saves.peekSlot('red',slot).player.name=='Alice' and Saves.loadOptions().musicVol==2,'switching back restores the original save registry, data and options')
local ui={_bankOverlay={accountId='17',right={dirty=true}},ready={}}
account='29';P.profileChanged(ui)
check(not ui._bankOverlay and ui._profileBankDrafts['17'].right.dirty,'account switching retains another profile’s staged Bank draft without displaying it')
local binding=files[P.FILE];files[P.FILE]='damaged legacy binding'
check(P.check() and Saves.peekSlot('red',slotB).player.name=='Bob','a damaged legacy binding does not block an independently linked named profile')
account='17';check(not P.check() and files[P.FILE]=='damaged legacy binding','the affected legacy account still requires explicit recovery without automatic reassignment')
files[P.FILE]=nil;account='29'
check(P.check() and Saves.peekSlot('red',slotB).player.name=='Bob','named profiles retain routing if the legacy binding is missing')
account=nil
check(not Saves.persistenceFs().read('bank/legacy.lua') and not Saves.persistenceFs().read('cloud_google.lua'),'guest routing cannot expose legacy or named-profile data during recovery')
files[P.FILE]=binding
account='17'
local W=require('src.pokewalker.Walker');local wa=W.load();wa.watts=123;assert(W.save(wa))
check(files['pokewalker.lua']and not files['profiles/29/pokewalker.lua'],'legacy linked owner keeps their existing walker path')
account='29';local wb=W.load()
check(wb~=wa and wb.watts==0,'walker live cache changes with the account')
wb.watts=456;assert(W.save(wb))
check(not W.save(wa)and W.load().watts==456,'stale account A walker cannot overwrite account B')
local bbackup=Saves.persistenceFs();bbackup.write('pokewalker_backups/red/test.lua','B backup')
check(files['profiles/29/pokewalker_backups/red/test.lua']=='B backup','walker transfer backups are account-private')
account='17';check(W.load().watts==123,'switching back restores account A walker')
local replacement=W.newState();replacement.watts=321;assert(W.adopt(replacement))
check(not W.check(wa)and W.load().watts==321,'cloud adoption invalidates stale screen and minigame references')
account=nil;local guest=W.load();check(guest.watts==0 and not W.check(replacement),'guest cannot see or save account progress')
guest.watts=9;assert(W.save(guest))
check(files['profiles/guest/pokewalker.lua']and S.decode(files['pokewalker.lua']).watts==321,'offline guest progress has its own file')
account='29';local taskState=W.load()
local co=coroutine.create(function()return W.save(taskState)end);P.attachTask(co);account='17'
local resumed,written=coroutine.resume(co)
check(resumed and not written and W.load().watts==321,'background storage scope refuses a changed active account')
print('Account profiles: '..n..' checks passed')
