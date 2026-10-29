package.path='./?.lua;./?/init.lua;'..package.path
love=require('tests.love_stub')
local T=require('tests.harness');local F=require('tools.map-runtime.fixture')
local M=require('src.compat.gen1.MapRuntime');local Views=require('src.compat.gen1.MapViews')
local construct=Views.new;local reads=0
Views.new=function(...)
 local v=construct(...);local map=v.map
 v.map=function(...)reads=reads+1;return map(...)end
 return v
end
for _,edition in ipairs{'firered','leafgreen','emerald','ruby','sapphire'}do
 local f=F.new(edition);local runtime=M.new(f.getGame,function()return edition end)
 local def=assert(runtime:current());local baseline=def.midLayout
 local native=f.map:blockAt(0,0);local observed
 local a,b,c=runtime:withLayoutSnapshot(function(x)
  T.eq(x,17,'callback arguments retained');T.eq(runtime:isOwned(def),true,'original definition remains native-owned')
  local before=reads
  local first=def.midLayout
  for i=1,1000 do T.eq(def.midLayout,first,'one synchronous observation remains stable')end
  T.eq(reads-before,1,'only first read validates the native projection')
  T.eq(rawget(def,'midLayout'),nil,'native definition receives no raw layout field')
  local changed=native==1 and 2 or 1
  f.map:setGen3Cells({{x=0,y=0,mid=changed,coll=0,elev=3}})
  T.eq(f.map:blockAt(0,0),changed,'native simulation sees writes immediately')
  T.eq(def.midLayout,first,'explicit presentation scope keeps its admitted observation')
  runtime:withLayoutSnapshot(function()
   observed=def.midLayout
   T.check(observed~=first,'nested scope observes current native revision')
   T.eq(observed:midAt(0,0),changed)
  end)
  T.eq(def.midLayout,first,'nested exit restores outer observation')
  return 'value',nil,19
 end,17)
 T.eq(a,'value');T.eq(b,nil);T.eq(c,19,'trailing result after nil retained')
 T.eq(def.midLayout,observed,'scope exit returns to live native projection')
 local marker={};local ok,err=pcall(function()runtime:withLayoutSnapshot(function()local _=def.midLayout;error(marker)end)end)
 T.eq(ok,false);T.eq(err,marker,'exception identity retained')
 local before=reads;local _=def.midLayout;T.eq(reads-before,1,'exception unwinds observation scope')
 runtime:withLayoutSnapshot(function()
  local first=def.midLayout
  runtime:withLayoutSnapshot(function()runtime:invalidate(f.mapId)end)
  T.check(def.midLayout~=first,'nested invalidation cannot resurrect stale outer observation')
 end)
 runtime:withLayoutSnapshot(function()
  local first=def.midLayout;runtime:invalidate()
  T.eq(runtime:isOwned(def),false,'full invalidation retires original definition')
  T.eq(def.midLayout,nil,'retired definition cannot borrow held snapshot')
  local fresh=assert(runtime:current());T.check(fresh~=def,'replacement epoch creates a new owned definition')
 end)
 runtime:release();f.views:release()
end
Views.new=construct
T.finish('synchronous native layout read scopes preserve ownership, revisions and unwind')
