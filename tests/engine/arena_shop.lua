package.path='./?.lua;./?/init.lua;'..package.path
love=require('tests.love_stub')
local files={};local fs={read=function(p)return files[p]end,write=function(p,b)files[p]=b;return true end,remove=function(p)files[p]=nil;return true end,createDirectory=function()return true end,getInfo=function(p)return files[p] and {size=#files[p]}end}
package.loaded['src.core.SaveData']={persistenceFs=function()return fs end}
package.loaded['src.storage.AccountStorage']={check=function()return true end}
love.timer={getTime=function()return 1 end};love.math={random=function()return .5 end}
love.data={hash=function()return string.rep('a',64)end,encode=function(_,_,b)return b end}
local account='17';package.loaded['src.cloud.RetroCloud']={accountId=function()return account end,signedIn=function()return true end}
local sent,response,code
package.loaded['src.cloud.NativeAccount']={request=function(_,_,p)sent=p;return response,'Unavailable',code end}
local Shop=require('src.cloud.ArenaShop')
assert(not Shop.purchase('LEFTOVERS','crystal') and files[Shop.ORDER],'an uncertain purchase keeps its durable order')
local order=sent.order
assert(Shop.pending().order==order,'the order survives reopening the client service')
response={account_id='17',order=order,coins=500}
assert(Shop.purchase('LEFTOVERS','crystal') and sent.order==order and not files[Shop.ORDER],'a retry keeps the same order and clears it only on success')
response=nil;code=422
assert(not Shop.purchase('LIGHTBALL','crystal') and not files[Shop.ORDER],'a definitive insufficient-funds rejection does not block a cheaper future order')
response={account_id='18'};code=nil
assert(not Shop.request('GET'),'another account wallet is rejected')
print('Arena shop: 5 checks passed')
