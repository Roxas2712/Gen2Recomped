package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.harness')
local M=require('src.features.Gen1Save5')
local S=require('src.core.SaveSerializer')
local reference=assert(loadfile('tests/fixtures/gen1_interfaces/vendor/src/core/SaveSerializer.lua'))()
local data={maps={PALLET_TOWN={width=10,height=9}},pokemon={MEW={}},moves={POUND={pp=35}}}
for _,version in ipairs{'red','blue','yellow'}do
 local save={version=version,meta={format=4,mods={{id='extra',version='1'}},playthroughId='opaque'},
   player={name='ROXAS',id=2712,map='PALLET_TOWN',x=2,y=3,facing='down'},party={{species='MEW',level=12,hp=20,
   otId=2712,traded=true,moves={{id='POUND',pp=12}},extra={provider={precise=1.2345678901234567}}}},
   boxes={{{species='MEW',level=9,hp=0,moves={{id='POUND',pp=0}}}}},
   flags={EVENT_EXAMPLE=false},modData={provider={state={1,2,3}}},futureField={false,true,42},money=3000}
 local original=S.encodeExact(save)
 local bytes,report=M.export(save,data)
 T.check(bytes~=nil,'export native save to Save-5')
 T.eq(report.nativeWrites,0,'export never writes profiles')
 T.eq(S.encodeExact(save),original,'export does not stamp or mutate original')
 local upstream=assert(reference.decode(bytes))
 T.eq(upstream.meta.format,5,'actual pinned upstream parser reads Save-5')
 local imported,details=M.import(bytes,data)
 T.check(imported~=nil,'Save-5 returns a reviewed native copy')
 T.eq(details.unknownFieldsPreserved,true,'unknown data preserved explicitly')
 T.same(imported,save,'full save state round trips without dropping extension fields')
 T.eq(imported.party[1].otId,2712,'format-5 import does not repeat historical OT repair')
 T.eq(imported.party[1].extra.provider.precise,save.party[1].extra.provider.precise,'precise doubles survive')
 imported.futureField[1]='changed'
 T.eq(save.futureField[1],false,'imported copies have independent ownership')
 upstream.meta.format=6
 T.eq(M.import(reference.encode(upstream),data),nil,'future formats are not relabelled as compatible')
 upstream.meta.format=5;upstream.version='crystal'
 T.eq(M.import(reference.encode(upstream),data),nil,'GSC format namespace cannot masquerade as Gen1 Save-5')
end
T.eq(M.import('return (function() _G.saveExecuted=true return {} end)()'),nil,'save bytes cannot execute Lua')
T.eq(_G.saveExecuted,nil,'malicious save side effects never run')
T.eq(M.import(string.rep('x',M.MAX_BYTES+1)),nil,'oversize save rejected before parsing')
T.finish('Explicit Gen1 Save-5 interchange with actual source parser')
