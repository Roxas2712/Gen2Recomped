package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
love.data={hash=function(_,b) local h=5381;for i=1,#b do h=(h*33+b:byte(i))%4294967296 end;return string.rep(('%08x'):format(h),8) end,encode=function(_,_,b) return b end}
local P=require('src.link.Protocol');local L=require('src.link.LinkBattle');local V=require('src.core.GameVersion')
for _,version in ipairs({'red','crystal','emerald'}) do
 V.set(version)
 local data=T.fixtures.fresh();local loaded=T.sdk.loadNone({data=data});T.eq(#loaded.errors,0)
 if version=='emerald' then for _,def in pairs(data.pokemon) do def.baseStats.spatk=def.baseStats.special;def.baseStats.spdef=def.baseStats.special;def.evYield={} end end
 require('src.battle.TypeChart').load(data);T.link.prepare(data)
 local ga=T.link.fakeGame(data,'FIXMON_A',{name='HOST',level=50});local gb=T.link.fakeGame(data,'FIXMON_B',{name='GUEST',level=50})
 local na,nb=require('src.link.Net').loopbackPair();local pa,pb=P.packParty(ga.save.party),P.packParty(gb.save.party)
 local ra,rb;local count=0
 local a=assert(L.newHost(ga,na,{myParty=pa,theirParty=pb,seed=327,strict=true,verdict='full',onFinished=function(r)ra=r;count=count+1 end}))
 local b=assert(L.newGuest(gb,nb,{myParty=pb,theirParty=pa,seed=327,strict=true,verdict='full',onFinished=function(r)rb=r end}))
 ga.stack:push(a);gb.stack:push(b)
 -- Synthetic final state: no ROM, gameplay session or user save is loaded.
 a.enemy.mon.hp=0;b.player.mon.hp=0;a.result='win';b.result='lose';a.turnCount=4;b.turnCount=4
 a:finish();b:finish()
 T.eq(ra.result,'win');T.eq(rb.result,'lose');T.eq(ra.digest,rb.digest,'both perspectives produce the same host-first final digest')
 T.eq(ra.turns,4);T.eq(#ra.digest,64);T.eq(count,1,'native completion emits its report once')
 local state=setmetatable({game=ga,net={send=function(_,msg)ra=msg end},arenaContext={seed=1234},forceLevel=50},{__index=require('src.link.LinkState')})
 state:startMode('battle',true);T.eq(ra.seed,1234,'Arena host uses the frozen server seed instead of choosing a new one')
end
T.finish('Arena native completion and frozen RNG')
