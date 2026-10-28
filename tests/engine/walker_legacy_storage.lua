-- Legacy guest migration uses real ProfileFs and verified atomic writes.
-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
love=require('tests.love_stub')
local S=require('src.core.SaveSerializer');local files={}
local raw={read=function(p)return files[p]end,write=function(p,b)files[p]=b;return true end,
 getInfo=function(p)return files[p]and{size=#files[p],type='file'}end,
 remove=function(p)files[p]=nil;return true end,createDirectory=function()return true end}
local F=require('src.storage.ProfileFs');local disk=F.wrap(raw,nil)
package.loaded['src.core.SaveData']={persistenceFs=function()return disk end}
local W=require('src.pokewalker.Walker');local Old=require('src.pokewalker.WalkerStorage')
local st=W.newState();st.watts=88;st.walking={name='LEGACY',raw={species=25},source={version='red',slot='1'}}
local legacy=S.encode(st);files[W.FILE]=legacy;files[W.FILE..'.bak']=legacy
local n=0;local function check(v,m)assert(v,m);n=n+1 end
check(W.exists(),'unbound legacy walker is discoverable before the guest profile is opened')
check(W.load().watts==88 and W.load().walking.name=='LEGACY','old guest walk remains visible after account isolation')
check(files['profiles/guest/pokewalker.lua']==legacy,'verified progress moved to the private guest profile')
check(files['profiles/guest/walker/legacy-unbound/pokewalker.lua']==legacy,'original bytes remain recoverable')
check(not files[W.FILE]and files[Old.MARKER],'shared active path is retired only after private publication')
files[W.FILE]=legacy -- Simulate power loss before the final legacy remove.
files['storage_account.lua']=S.encode({schema=1,accountId='17'})
disk=F.wrap(raw,'17');W.reload()
check(W.load().watts==0 and not W.load().walking,'new linked account cannot replay the migrated guest walk from a leftover original')
local own=W.load();own.watts=123;assert(W.save(own));W.reload()
check(W.load().watts==123,'new account progress is accepted independently of the legacy marker')
disk=F.wrap(raw,nil);W.reload()
check(W.load().watts==88,'guest migration remains intact after signing in to another profile')
print('Pokéwalker legacy storage: '..n..' checks passed')
