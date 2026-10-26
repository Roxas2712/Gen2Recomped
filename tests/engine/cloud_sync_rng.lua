package.path='./?.lua;'..package.path
local T=require('tests.harness')
love=require('tests.love_stub')
local S=require('src.core.SaveSerializer')
local files={}
package.loaded['src.core.SaveData']={persistenceFs=function()return {
 getInfo=function(p)return files[p]and{type='file'}end,
 read=function(p)return files[p]end,
}end}
local gameplayRolls,privateRolls=0,0
love.math.random=function()gameplayRolls=gameplayRolls+1;return 123 end
love.math.newRandomGenerator=function()return {random=function(_,a,b)
 privateRolls=privateRolls+1;return a+(1234+privateRolls)%(b-a+1)
end}end
local C=require('src.import.CloudSync')
local state=C.loadState('retro')
T.eq(gameplayRolls,0,'first cloud sync does not consume the suspended battle RNG')
T.eq(privateRolls,2,'new device identifier uses its own generator')
T.check(state.device:match('^[a-f0-9]+$')and #state.device==8,'device identifier keeps the existing cloud link format')
files['cloud_sync.lua']=S.encode({device='existing',links={}})
T.eq(C.loadState('retro').device,'existing','another provider reuses the persisted device identifier')
files['cloud_sync_retro.lua']=S.encode({device='linked',links={red={slot1={cloudId='kept'}}}})
local restored=C.loadState('retro')
T.eq(restored.device,'linked','existing service identity remains unchanged')
T.eq(restored.links.red.slot1.cloudId,'kept','existing cloud links remain unchanged')
T.eq(privateRolls,2,'loading persisted identifiers needs no new randomness')
T.eq(gameplayRolls,0,'all cloud identity paths leave gameplay rolls untouched')
T.finish('Cloud identity RNG isolation')
