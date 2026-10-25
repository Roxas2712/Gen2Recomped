package.path='./?.lua;'..package.path
love=require('tests.love_stub')
local n=0
local function check(v,m) assert(v,m);n=n+1 end
local bytes={}
local options={mods={one={on=true,gens={true,false,true,false,true}}},modInstallSources={one={repo='fork/original',version='1.0.0',tag='v1.0.0'}},apiToken='PRIVATE TOKEN',launcherCartDesigns={one={art='PRIVATE IMAGE'}}}
local disk={read=function(p) return bytes[p] end,write=function(p,b) bytes[p]=b;return true end,getInfo=function(p) return bytes[p] and {size=#bytes[p]} end,remove=function(p) bytes[p]=nil;return true end}
package.loaded['src.core.SaveData']={persistenceFs=function() return disk end,loadOptions=function() return options end,saveOptions=function(v) options=v;return true end}
love.data={hash=function(_,s) local h=5381;for i=1,#s do h=(h*33+s:byte(i))%4294967296 end;return string.rep(string.format('%08x',h),8) end,encode=function(_,_,s) return s end}
local P=require('src.mods.ModProfiles');local S=require('src.core.SaveSerializer')
local mods={{id='one',github='upstream/original',version='1.0.0',enabled=true}}
local profile=P.capture(mods,options)
check(profile.mods[1].repo=='fork/original' and profile.mods[1].tag=='v1.0.0','installation provenance keeps a fork bound to its actual source')
local encoded=S.encode(profile)
check(not encoded:find('PRIVATE',1,true) and not encoded:find('apiToken',1,true),'cloud profile excludes credentials, artwork and arbitrary settings')
local clean=assert(P.decode(encoded))
check(clean.mods[1].gens[2]==false and clean.mods[1].on==true,'generation choices and master activation round trip')
local malicious=S.decode(encoded);malicious.mods[1].id='..'
check(not P.decode(S.encode(malicious)),'path-like package IDs are refused')
malicious=S.decode(encoded);malicious.mods[1].repo='../private'
check(not P.decode(S.encode(malicious)),'repository traversal is refused')
check(not P.decode('return os.execute("bad")'),'network profile bytes can never execute')
local plan=P.plan(clean,{})
check(#plan.downloads==1 and plan.downloads[1].version=='1.0.0','new device requests the pinned package version')
check(#P.plan(clean,{{id='one',github='fork/original',version='1.0.0'}}).downloads==0,'matching packages are not downloaded again')
check(#P.plan(clean,{{id='one',github='wrong/repo',version='1.0.0'}}).downloads==0,'actual installation receipt wins over an inherited manifest repository')
local receipt=options.modInstallSources.one;options.modInstallSources.one=nil
check(#P.plan(clean,{{id='one',github='wrong/repo',version='1.0.0'}}).downloads==1,'same version from a different actual repository needs replacement')
options.modInstallSources.one=receipt
local unversioned=P.capture({{id='local',github='author/local',version='development'}},options)
check(#unversioned.mods==0,'unreproducible free-form local versions do not poison the portable profile')
malicious=S.decode(encoded);malicious.mods[1].gens.secret='PRIVATE'
check(not S.encode(assert(P.decode(S.encode(malicious)))):find('PRIVATE',1,true),'generation tables are rebuilt without extra remote keys')
local remote
local store={read=function() return remote end,write=function(_,value) remote=value;return true end}
check(P.sync(store,mods,options).kind=='published','first device creates the private cloud profile')
check(P.sync(store,mods,options).kind=='current','an unchanged profile stays stable')
options.mods.one.on=false
check(P.sync(store,mods,options).kind=='published','a local-only activation change updates the existing cloud profile')
local other=assert(P.decode(remote));other.mods[1].version='2.0.0';remote=S.encode(other)
local result=P.sync(store,mods,options)
check(result.kind=='apply' and result.downloads[1].version=='2.0.0','a remote-only change becomes a reviewable plan')
options.mods.one.gens[1]=false
check(P.sync(store,mods,options).kind=='conflict','two changed devices do not overwrite each other silently')
check(not P.unchanged(result,mods,options),'a plan cannot silently apply over a new local change')
store.profileScope='another-account'
check(P.sync(store,mods,options).kind=='apply','switching accounts does not reuse the previous account conflict base')
options.mods.extra=true
result.disable={'defaultEnabled'}
check(P.accept(result),'a completed package plan can commit its activation state')
check(options.mods.one.on==false and options.mods.extra==false and options.apiToken=='PRIVATE TOKEN','profile activation disables extras without touching local secrets')
check(options.mods.defaultEnabled==false,'extra packages with no saved toggle are also switched off')
print('Mod profiles: '..n..' checks passed')
