package.path='./?.lua;'..package.path
love=require('tests.love_stub')
local noop=function()end
local options={cloudAutoSync=false,gameCacheDownload=false}
local warning,cacheOptions,bankPull,cartChoice
package.loaded['src.core.SaveData']={}
package.loaded['src.core.GameVersion']={ORDER={'red'}}
package.loaded['src.cloud.RetroCloud']={signedIn=function()return true end,accountId=function()return '17'end}
package.loaded['src.storage.AccountStorage']={requireUI=function()return true end}
package.loaded['src.cloud.Task']={new=function(fn)return{poll=function()local a,b=fn();return{kind='done',first=a,second=b}end}end}
package.loaded['src.storage.GameCache']={refresh=noop,sync=function(_,o)
 cacheOptions=o;if warning then return nil,warning end
 return{uploaded=0,downloaded=1,versions={'red'}}
end}
package.loaded['src.import.LauncherBackdrop']={stop=noop}
package.loaded['src.import.CloudSync']={syncOne=function()return 'uploaded'end,restoreVersions=function()return{downloaded=1,failed=0}end,
 syncVersions=function()return{uploaded=1,failed=0}end,describe=function()return 'one save'end}
package.loaded['src.storage.PokemonBank']={sync=function(_,pull)bankPull=pull;return 1 end}
package.loaded['src.storage.CartridgeCloud']={sync=function(_,choice)cartChoice=choice;return 'restored'end}
local R={ready={red=false},_settings=function()return options end,_sbCloudRows=noop,_settingsAction=noop,
 _setSettingValue=noop,play=noop,update=noop,_refreshSlots=noop,_recheckReady=noop,
 _sbCloudTarget=function()return{kind='retro',accountId='17'}end}
require('src.import.LauncherStorage').install(R)
local Sync=require('src.storage.SyncStatus')
R:_storageSync(nil,nil,nil,'restore');R:update(0)
assert(cacheOptions.gameCacheDownload==true and cacheOptions.gameCacheUpload==false,
 'an explicit restore downloads games despite disabled automatic downloads and never enables upload')
assert(bankPull==true and cartChoice=='download','restore includes the account Bank and designs without publishing local changes')
assert(Sync.get().state=='available','a complete account restore is available')
warning='A private game import needs updating'
R:_storageSync(nil,nil,nil,'restore');R:update(0)
assert(Sync.get().state=='error' and Sync.get().detail:find(warning,1,true),
 'the real launcher callback must retain a private cache failure after the normal save restore succeeds')
assert(R.settingsNotice:find(warning,1,true),'the detailed failure remains visible for recovery')
R:_storageSync('red','slot1');R:update(0)
assert(Sync.get().state=='error' and Sync.get().detail:find(warning,1,true),
 'syncing one save also retains an earlier game-cache failure')
print('Launcher account restore: 6 checks passed')
