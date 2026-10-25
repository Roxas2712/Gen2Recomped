package.path='./?.lua;'..package.path
love=require('tests.love_stub')
local n=0;local function check(v,m) assert(v,m);n=n+1 end
local S=require('src.core.SaveSerializer')
local options={mods={one=false,extra=true,localmod=true},modInstallSources={one={repo='author/one',version='1.0.0',tag='v1.0.0',sha256=string.rep('a',64)}},secret='PRIVATE'}
local disk={}
package.loaded['src.core.SaveData']={loadOptions=function() return options end,saveOptions=function(v) options=v;return true end,persistenceFs=function() return {read=function(p) return disk[p] end,write=function(p,b) disk[p]=b;return true end,getInfo=function(p) return disk[p] and {} end,remove=function(p) disk[p]=nil end} end}
love.data={hash=function(_,s) local h=5381;for i=1,#s do h=(h*33+s:byte(i))%4294967296 end;return string.rep(string.format('%08x',h),8) end,encode=function(_,_,s) return s end}
local P=require('src.mods.ModProfiles');local R=require('src.storage.SaveResume');local V=require('src.core.Version');local G=require('src.mods.ModGens')
local loaded={{id='one',version='1.0.0',api=3,github='author/one'},{id='localmod',version='development',api=3}}
local contract=assert(R.capture('red',loaded,options))
check(#contract.mods==2 and contract.mods[1].id=='localmod','the save binds every loaded package, including unversioned local mods')
check(contract.mods[2].sha256==string.rep('a',64) and contract.mods[2].tag=='v1.0.0','the save carries its actual package provenance')
check(not S.encode(contract):find('PRIVATE',1,true) and not S.encode(contract):find('options',1,true),'save requirements exclude private launcher settings')
local save={version='red',player={name='Fixture'},meta={resume=contract}}
local installed={{id='one',version='1.0.0',github='author/one'},{id='extra',version='2.0.0'},{id='localmod',version='development'}}
local report=R.assess(save,'red',installed,options)
check(report.needsReview and report.plan and #report.plan.downloads==0,'activation differences need review without downloading matching packages')
check(report.plan.flags.localmod and #report.plan.disable==1 and report.plan.disable[1]=='extra','required local packages are retained while unrelated extras are switched off')
disk[P.STATE]='KEEP GLOBAL CONFLICT BASE'
check(P.accept(report.plan),'a reviewed save-specific mod set can be applied')
check(G.active(options.mods.one,1)==true and G.active(options.mods.one,2)==false,'enabling a disabled package only enables this save generation')
check(G.active(options.mods.extra,1)==false and G.active(options.mods.extra,2)==true,'extra packages stay active for other generations')
check(G.active(options.mods.localmod,1)==true and disk[P.STATE]=='KEEP GLOBAL CONFLICT BASE','local requirements survive and the global cloud conflict base is preserved')
check(not R.assess(save,'red',installed,options).needsReview,'the restored stack passes the pre-launch check')
local missing=R.assess(save,'red',{{id='localmod',version='development'}},options)
check(missing.plan and missing.plan.downloads[1].version=='1.0.0' and missing.plan.downloads[1].sha256==string.rep('a',64),'new devices request the save-pinned version and fingerprint')
check(not R.assess(save,'red',{},options).plan,'missing unpublished local packages cannot be silently dropped')
options.modInstallSources.one.sha256=string.rep('b',64)
check(#R.assess(save,'red',installed,options).plan.downloads==1,'equal version numbers cannot hide a different package fingerprint')
options.modInstallSources.one.sha256=string.rep('a',64)
local wrong=S.decode(S.encode(contract));wrong.version='blue'
check(R.assess({version='red',meta={resume=wrong}},'red',installed,options).blocked,'a requirement document for another game cannot authorize a launch')
wrong=S.decode(S.encode(contract));wrong.saveFormat=V.saveFormat+1
check(R.assess({meta={resume=wrong}},'red',installed,options).blocked,'a newer save format requires an engine update')
wrong=S.decode(S.encode(contract));wrong.engine='99.0.0'
local changed=R.assess({meta={resume=wrong}},'red',installed,options)
check(changed.engineMismatch and changed.needsReview,'an engine version difference is disclosed before continuing')
wrong=S.decode(S.encode(contract));wrong.mods[2].repo='../private'
check(not R.decode(wrong),'save package paths cannot escape the repository grammar')
wrong=S.decode(S.encode(contract));wrong.password='PRIVATE';wrong.mods[1].path='/private/source'
check(not S.encode(assert(R.decode(wrong))):find('PRIVATE',1,true) and not S.encode(assert(R.decode(wrong))):find('/private',1,true),'unrecognized save requirement fields are discarded')
check(not R.capture('red',{{id='..',version='1.0.0',api=3}},{}),'unstable package identities cannot be stamped as a reproducible save')
local legacy=R.assess({meta={mods={{id='localmod',version='development',api=3}},engine=V.engine}},'red',{{id='localmod',version='development'}},options)
check(legacy.legacy and not legacy.needsReview,'matching older save metadata remains playable without a mandatory conversion')
check(R.assess({meta={mods='bad'}},'red',{},options).blocked,'invalid legacy metadata cannot be treated as vanilla')
options.mods={};local new=P.plan({engine=V.engine,mods={}}, {}, {generation=2,required={'new'}})
check(P.accept(new) and G.active(options.mods.new,2)==true and G.active(options.mods.new,1)==false,'a newly installed package activates only for the restored game generation')
local forced={id='one',version='1.0.0',github='author/one',supportedGens={2}}
check(not R.assess({meta={resume=assert(R.capture('red',{loaded[1]},options))}},'red',{forced},options).plan,'save restore cannot silently force a package into an unsupported generation')
local missingAssets={id='one',version='1.0.0',github='author/one',missingImports={{id='base'}}}
local portableSave={meta={resume=assert(R.capture('red',{loaded[1]},options))}}
check(not R.assess(portableSave,'red',{missingAssets},options).plan,'required private asset imports are never treated as downloadable mod packages')
missingAssets.missingImports=nil;missingAssets.game_version='>=99.0.0'
check(not R.assess(portableSave,'red',{missingAssets},options).plan,'an incompatible installed package cannot be silently enabled for resume')
print('Save resume requirements: '..n..' checks passed')
