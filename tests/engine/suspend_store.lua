package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local S=require('src.core.SaveSerializer')
love.data={hash=function(_,b)return b end,encode=function(_,_,b)return require('src.link.Fingerprint').digest(b):rep(4)end}
package.loaded['src.cloud.Task']={yield=function()end}
local account='1'
package.loaded['src.storage.AccountStorage']={storeCheck=function(store)return store.accountId==account or nil,'Wrong account'end}
local M=require('src.storage.SuspendStore')
local function fs()return T.sdk.memfs({})end
local a,b=fs(),fs();local objects={};local lost=false
local store={kind='retro',accountId='1',read=function(p)return objects[p]end,write=function(p,v)
 objects[p]=v
 if lost and p:match('states/heads/')then lost=false;return nil,'Reply was lost'end
 return true
end}
local id='suspend-test';local p='states/local/red/'..id..'.lua'
local function capsule(n)return S.encodeExact({schema=1,edition='red',anchor={identity={playthroughId=id}},frame=1/60,turn=n})end
a.write(p,capsule(1))
T.eq(M.sync(store,'red',id,false,a),'uploaded','first device publishes all immutable blocks before its head')
T.eq(M.sync(store,'red',id,false,b),'downloaded','second device restores the suspend without the first device paths')
T.eq(b.read(p),a.read(p),'transfer retains exact serialized frame precision')
a.write(p,capsule(2));lost=true
T.eq(M.sync(store,'red',id,false,a),nil,'lost head response is reported without deleting the local copy')
T.eq(M.sync(store,'red',id,false,a),'unchanged','retry recognizes an already committed head')
b.write(p,capsule(3));local prior=b.read(p)
T.eq(M.sync(store,'red',id,false,b),nil,'concurrent changes on two devices require a choice')
T.eq(b.read(p),prior,'conflicting local state remains byte-identical')
local clean=fs();local blob
for key in pairs(objects)do if key:match('states/blobs/')then blob=key;break end end
local original=objects[blob];objects[blob]='tampered'
-- Corrupt every block so iteration order cannot choose an unused old one.
local originals={};for key,value in pairs(objects)do if key:match('states/blobs/')then originals[key]=value;objects[key]='tampered'end end
T.eq(M.sync(store,'red',id,false,clean),nil,'corrupt cloud blocks fail before installing a local suspend')
T.eq(clean.read(p),nil,'partial transfer never becomes a resumable local state')
for key,value in pairs(originals)do objects[key]=value end;objects[blob]=original
account='2';T.eq(M.sync(store,'red',id,false,clean),nil,'another account cannot transfer the private suspend')
T.eq(clean.read(p),nil,'account mismatch leaves destination untouched')
T.finish('Portable suspend cloud store')
