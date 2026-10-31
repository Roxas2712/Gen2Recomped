package.path='./?.lua;'..package.path
love=require('tests.love_stub')
local noop=function()end
local options={cloudAutoSync=false,gameCacheDownload=false}
local warning,cacheOptions,bankPull,cartChoice,walkerPull,walkerWarning
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
package.loaded['src.pokewalker.WalkerCloud']={sync=function(_,pull)
 walkerPull=pull;if walkerWarning then return nil,walkerWarning end;return 'empty'
end}
local R={ready={red=false},_settings=function()return options end,_sbCloudRows=noop,_settingsAction=noop,
 _setSettingValue=noop,play=noop,update=noop,_refreshSlots=noop,_recheckReady=noop,
 _sbCloudTarget=function()return{kind='retro',accountId='17'}end}
require('src.import.LauncherStorage').install(R)
local Sync=require('src.storage.SyncStatus')
local resumed
package.loaded['src.storage.AccountStorage'].resume=function(_,after)resumed=after.version end
R._storageResumeAfter={kind='play',version='red'}
R:_storageSync(nil,nil,nil,'restore');R:update(0)
assert(resumed=='red'and not R._storageResumeAfter,'post-login play waits for a completed restore')
assert(cacheOptions.gameCacheDownload==true and cacheOptions.gameCacheUpload==false,
 'an explicit restore downloads games despite disabled automatic downloads and never enables upload')
assert(bankPull==true and cartChoice=='download','restore includes the account Bank and designs without publishing local changes')
assert(Sync.get().state=='available','a complete account restore is available')
assert(walkerPull==true,'explicit account restore includes its read-only Walker restore')
warning='A private game import needs updating'
resumed=nil;R._storageResumeAfter={kind='play',version='red'}
R:_storageSync(nil,nil,nil,'restore');R:update(0)
assert(not resumed and not R._storageResumeAfter,'a failed or partial restore never silently starts stale progress')
assert(Sync.get().state=='partial' and Sync.get().detail:find(warning,1,true),
 'the real launcher callback must retain a private cache failure after the normal save restore succeeds')
assert(R.settingsNotice:find(warning,1,true),'the detailed failure remains visible for recovery')
R:_storageSync('red','slot1');R:update(0)
assert(Sync.get('red','slot1').state=='available','single-slot sync avoids unrelated cache transfer failures')
warning=nil;walkerWarning='A pending Pokémon transfer needs recovery'
R:_storageSync(nil,nil,nil,'restore');R:update(0)
assert(Sync.get().state=='partial'and Sync.get().detail:find(walkerWarning,1,true),'normal-save acknowledgement retains the separate Walker recovery failure')
assert(R.settingsNotice:find(walkerWarning,1,true),'Walker recovery detail remains visible')
walkerWarning=nil
local Task=require('src.cloud.Task')
warning=nil
Task.new=function(fn)return{poll=function()fn();return{kind='error',error='Request timed out'}end}end
R:_storageSync(nil,nil,nil,'restore');R:update(0)
assert(Sync.get().state=='partial' and R.settingsNotice:find('timed out',1,true),'a late worker timeout preserves an acknowledged normal-save phase')
assert(not R.settingsNotice:find('paused',1,true),'the retry notice names the real error')
R._storageTask={cancel=function()end};R._storageProgress=nil;R:play()
assert(not R._storageTask and Sync.get().state=='cancelled','starting a game cannot leave an orphaned uploading badge')
R._storageTask={cancel=function()end};R._storageProgress={sync='uploaded'};R:play()
assert(Sync.get().state=='partial','starting a game preserves an already completed normal upload')
print('Launcher account restore: 12 checks passed')
