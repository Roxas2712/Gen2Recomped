-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local V,F,H=require('src.core.GameVersion'),require('src.link.Fingerprint'),require('src.link.Handshake')
local Copy=require('src.mods.Merge').deepCopy
local mods={{id='portable_records',version='1.0.0',affectsLink=true}}
for _,edition in ipairs({'red','gold','firered','ruby','emerald','platinum','black'})do
 V.set(edition);local data=T.fixtures.fresh()
 local vanilla=F.compute(data,{})
 local content=F.records(data,'pokemon')
 T.eq(F.modCallbackRevision({}),nil,'vanilla has no callback ABI gate')
 T.eq(F.modCallbackRevision({{id='translation',version='1',affectsLink=false}}),nil,'non-link mods retain their existing contract')
 T.eq(F.modCallbackRevision(mods),1,'link-affecting mods carry the callback ABI')
 local game={data=data,save={player={name='RECORDS'}},mods={status=function()return{loaded={{id='portable_records',version='1.0.0'}}}end}}
 local current=H.hello(game,'battle')
 T.eq(current.modCallbackRevision,1,'actual hello explicitly announces its callback ABI')
 local na,nb=require('src.link.Net').loopbackPair()
 local producer=setmetatable({game=game,net=na},{__index=require('src.link.LinkState')})
 producer:sendHello('battle')
 local received=nb:poll()[1]
 T.eq(received.modCallbackRevision,1,'real hello producer and JSON transport retain the callback ABI')
 T.eq(H.checkCompat(current,received),'full','transported modern hello admits matching peers')
 -- The prior wire surface was exactly the vanilla prefix plus id@version.
 local old=Copy(current);old.modCallbackRevision=nil
 old.fingerprint=F.digest(F.surface(data,{})..F.modKey(mods))
 T.neq(current.fingerprint,old.fingerprint,'same mod/content versions cannot hide old callback semantics')
 T.eq(H.checkCompat(current,Copy(current)),'full','new peers agree on their callback semantics')
 T.eq(H.checkCompat(current,old),'subset','old callback semantics cannot start lockstep')
 T.eq(H.checkCompat(old,current),'subset','the callback ABI refusal is symmetric')
 local concealed=Copy(old);concealed.fingerprint=current.fingerprint
 T.eq(H.checkCompat(current,concealed),'subset','equal authored digests cannot erase the callback ABI')
 T.check(table.concat(H.describe(current,concealed,'subset','battle'),' '):find('callbacks',1,true)~=nil,
  'the actual incompatibility notice names callback engine versions')
 for _,host in ipairs({true,false})do
  local state=setmetatable({game=game,myHello=current,peerHello=old},{__index=require('src.link.LinkState')})
  state:decideCompat('battle',host)
  T.eq(state.stage,'notice','actual link controller stops the incompatible battle')
  T.eq(state.noticeExits,true,'mismatch exits before battle setup')
 end
 T.eq(F.compute(data,{{id='cosmetic',version='1',affectsLink=false}}),vanilla,'UI-only mods retain cached vanilla fingerprints')
 T.same(F.records(data,'pokemon'),content,'Pokemon trade records do not acquire a callback ABI')
end
for _,edition in ipairs({'ruby','emerald'})do
 V.set(edition)
 local J=require('src.link.Json')
 local files={['mods/portable_records/manifest.json']=J.encode({id='portable_records',name='Portable records',version='1.0.0',
  api=3,games={'gen3'},entry='main.lua',affects_link=true}),
  ['mods/portable_records/main.lua']='return function(mod)mod.exports.api=mod end'}
 local loaded=T.sdk.loadMods({'mods/portable_records'},{data=T.fixtures.fresh(),generation=3,fs=T.sdk.memfs(files)})
 T.eq(#loaded.errors,0,'the real test mod declares link-affecting callbacks before loading')
 local f={loaded=loaded,close=loaded.release};local data=loaded.data
 require('src.battle.TypeChart').load(data);T.link.prepare(data)
 local calls,ids=0,{}
 f.loaded.loader.exports.portable_records.api.hooks:wrap('battle.damage',function(nextDamage,ctx)
  T.check(ctx.user.id==0 or ctx.user.id==1,'real linked actions expose local battler IDs')
  T.eq(ctx.user.stats,ctx.user.mon.stats,'linked records share their public stats')
  ids[ctx.user.id]=true;calls=calls+1
  ctx.user.stats.attack=ctx.user.stats.attack+1
  return nextDamage(ctx)
 end)
 local a=T.link.fakeGame(data,'FIXMON_A',{name='HOST',level=20})
 local b=T.link.fakeGame(data,'FIXMON_B',{name='GUEST',level=20})
 a.mods,b.mods=f.loaded.loader,f.loaded.loader
 local removeDigest=f.loaded.loader.exports.portable_records.api.hooks:wrap('link.fingerprint',function(_,data,metadata)
  metadata[1].affectsLink=false
  return'authored_digest'
 end)
 F.forget(data)
 local custom=H.hello(a,'battle');local oldCustom=Copy(custom);oldCustom.modCallbackRevision=nil
 T.eq(custom.modCallbackRevision,1,'loaded manifest enables the actual callback gate')
 T.eq(custom.mods[1].affectsLink,false,'the authored hook really mutates its metadata argument')
 T.eq(custom.fingerprint,'authored_digest','the public mod really overrides the full fingerprint')
 T.eq(H.checkCompat(custom,oldCustom),'subset','explicit callback ABI also protects real custom fingerprint hooks')
 removeDigest();F.forget(data)
 local result=T.link.lockstep(a,b,{seed=327,maxFrames=60000})
 T.check(calls>0 and ids[0]and ids[1],'both native actor roles execute the public callback')
 T.eq(result.completed,true,'actual linked battle completes with flat stat writes')
 T.eq(result.agreed,true,'linked state hashes agree after public callback writes')
 for turn,hash in pairs(result.battleA.localHashes)do
  if result.battleB.localHashes[turn]then
   T.eq(hash,result.battleB.localHashes[turn],'paired turn digest agrees')
   T.same(result.battleA.localParts[turn],result.battleB.localParts[turn],'all state components agree')
  end
 end
 f.close()
end
T.finish('API3 callback ABI and actual native linked battler records')
