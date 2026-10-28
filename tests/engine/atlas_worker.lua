-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
local T=require('tests.harness')
love=require('tests.love_stub')
local Pixels=require('src.compat.gen1.AtlasPixels')
local Core=require('src.compat.gen1.AtlasPixelsCore')
local Fixture=require('tools.native-atlas.fixture')
local function equal(a,b,label)
  for _,over in ipairs({false,true})do
    T.eq(a:rgba(over),b:rgba(over),label..' RGBA')
    T.eq(a:blob(over),b:blob(over),label..' index stream')
  end
  for _,key in ipairs({'mids','midToSlot','indexed','under','over','paletteOverrides','paletteUsers',
      'slotPalettes','indexRevision','paletteRows','paletteKey','bgr','ticks','revision'})do
    T.same(a[key],b[key],label..' '..key)
  end
end
for _,edition in ipairs({'firered','leafgreen','emerald','ruby','sapphire'})do
  local f=Fixture.new(edition)
  f.pair.primary.animations={{tile=0,count=1,step=3,frames={f.pair.primary.tiles:sub(1,32),string.rep('\255',32)}}}
  f.pair.secondary.paletteCycles={{kind='rotate',first=f.layout.palettesInPrimary*16+1,count=3,step=2,direction=1}}
  local native=Pixels.new(f.pair,f.layout)
  local core=Core.run{pair=f.pair,layout=f.layout}
  local model=Pixels.fromCore(core,f.pair,f.layout)
  T.eq(core.rgbaUnder,native:rgba(false),'core under bytes '..edition)
  T.eq(core.rgbaOver,native:rgba(true),'core over bytes '..edition)
  T.eq(core.blobUnder,native:blob(false),'core under indices '..edition)
  T.eq(core.blobOver,native:blob(true),'core over indices '..edition)
  T.eq(model.decoder.primary,f.pair.primary,'original live primary owner')
  T.eq(model.decoder.secondary,f.pair.secondary,'original live secondary owner')
  T.eq(model.decoder:animations()[1].frames,f.pair.primary.animations[1].frames,'original animation frame-table owner')
  equal(model,native,'initial '..edition)
  for _,ticks in ipairs({1,3,8,13,0})do
    local u,o=model:update(ticks);local nu,no=native:update(ticks)
    T.same(u,nu,'under dirty slots');T.same(o,no,'over dirty slots')
    equal(model,native,'animation '..edition)
  end
  local words={};for i=1,16 do words[i]=i*31 end
  model:setPalette(0,words);native:setPalette(0,words)
  equal(model,native,'override '..edition)
  f.pair.primary.palettes[1][2]={201,43,71}
  model:update(16);native:update(16)
  equal(model,native,'live palette edit '..edition)
end
local time,queue,answers,nextId,cancelled,polls=0,{},{},0,0,0
love.timer={getTime=function()return time end}
local read=require('tools.native-atlas.cpu-gpu').install(love)
local Pool=require('src.core.BuildWorker')
local P=require('src.core.Performance')
P.atlasWorker,P.buildWorkers,P.tier=true,true,'high'
Pool.available=function()return P.buildWorkers end
Pool.count=function()return P.tier=='low'and 1 or 3 end
Pool.submit=function(kind,key,payload,done,failed)
  nextId=nextId+1;queue[nextId]={kind=kind,payload=payload,done=done,failed=failed};return nextId
end
Pool.cancel=function(id)cancelled=cancelled+1;queue[id]=nil;return true end
Pool.poll=function(limit)
  polls=polls+1;local n=0
  while #answers>0 and n<(limit or 4)do local fn=table.remove(answers,1);fn();n=n+1 end
end
local Native=require('src.core.game3.tileset_native')
local Stream=require('src.core.game3.asset_stream')
local Build=require('src.compat.gen1.AtlasBuild')
local Session=require('tools.native-atlas.session-fixture')
local function fresh()
  Native.release();local f=Session.new('emerald');return f
end
local function finish(id)
  local job=assert(queue[id]);queue[id]=nil
  local result=Core.run(job.payload)
  answers[#answers+1]=function()job.done(result)end
  return job
end
local f=fresh()
T.check(Native.prefetch(f.pair,1),'prefetch admitted')
local id=nextId;local queued=assert(queue[id])
T.eq(queued.kind,'gen3atlas','registered worker kind')
T.neq(queued.payload.pair.primary,f.game.data.map_tilesets.P,'worker bank is detached')
T.neq(queued.payload.pair.primary.palettes,f.game.data.map_tilesets.P.palettes,'mod palette data is copied')
T.eq(Native.resident(),0,'no public pending cache placeholder')
finish(id);Pool.poll(4)
local ts=Native.get(f.pair);local expected=Pixels.new(f.picture.pair,f.picture.layout)
expected:update(require('src.render.TileRenderer').animFrame())
T.eq(read(ts.image),expected:rgba(false),'actual native upload receives worker pixels')
T.eq(read(ts.overImage),expected:rgba(true),'actual native over upload receives worker pixels')
T.eq(Build._cacheInfo(Native._pairs).worker,1,'published worker provenance')
T.eq(next(Native._stream.pending),nil,'central callback completes native publication')
f=fresh();Native.prefetch(f.pair,1);id=nextId
local publicJob=assert(Native._stream.pending[f.pair])
T.check(coroutine.resume(publicJob.co),'a mod can advance the public pending coroutine')
finish(id);Pool.poll(4)
T.eq(Native._stream.pending[f.pair],publicJob,'completion preserves the already advanced native coroutine')
T.eq(publicJob._worker,nil,'discarded reply cannot keep the coroutine waiting')
T.check(Native.get(f.pair).image~=nil,'an externally advanced coroutine completes normally')
T.eq(Build._cacheInfo(Native._pairs).worker,0,'native coroutine progress is not mislabeled as a worker publication')
f=fresh();Native.prefetch(f.pair,1);id=nextId
publicJob=Native._stream.pending[f.pair]
local originalCo=publicJob.co;local resumed=0
publicJob.co=coroutine.create(function()
  while coroutine.status(originalCo)~='dead'do
    local ok,value=coroutine.resume(originalCo);assert(ok,value);resumed=resumed+1
    if coroutine.status(originalCo)=='dead'then return value end
    coroutine.yield(value)
  end
end)
finish(id);Pool.poll(4)
T.eq(resumed,0,'worker callback leaves a replacement coroutine under its existing owner')
T.check(Native.get(f.pair).image~=nil and resumed>0,'replacement coroutine remains the native completion path')
T.eq(Build._cacheInfo(Native._pairs).worker,0,'replacement coroutine result retains native provenance')
f=fresh();Native.prefetch(f.pair,1);id=nextId;local late=queue[id]
local before=polls;ts=Native.get(f.pair)
T.check(ts and ts.image,'required get keeps synchronous completion')
T.eq(polls,before,'required get cannot deliver unrelated pool callbacks')
T.check(cancelled>0,'required get cancels its pending job')
local held=ts;late.done(Core.run(late.payload))
T.eq(Native.get(f.pair),held,'retired late result cannot replace a required atlas')
f=fresh();Native.prefetch(f.pair);id=nextId
f.game.data.map_tilesets.P.palettes[1][2][1]=222
finish(id);Pool.poll(4)
ts=Native.get(f.pair);expected=Pixels.new(f.picture.pair,f.picture.layout)
expected:update(require('src.render.TileRenderer').animFrame())
T.eq(ts.imageData:getString(),expected:rgba(false),'live source edit discards stale worker pixels')
T.eq(Build._cacheInfo(Native._pairs).worker,0,'edited source falls back to live native construction')
f=fresh();Native.prefetch(f.pair);id=nextId;time=time+6
Stream.update(.002)
T.eq(queue[id],nil,'context-loss timeout cancels unanswered CPU work')
T.check(Native.get(f.pair).image~=nil,'timeout retains synchronous admission')
f=fresh();Native.prefetch(f.pair);id=nextId;late=queue[id]
Native.release();late.done(Core.run(late.payload))
T.eq(Native.resident(),0,'release prevents late publication')
f=fresh();local nativeNew=Pixels.new;local calls=0;before=nextId
Pixels.new=function(...)calls=calls+1;return nativeNew(...)end
Native.prefetch(f.pair);ts=Native.get(f.pair)
T.eq(nextId,before,'constructor override keeps the native path')
T.eq(calls,1,'constructor override is invoked exactly once')
Pixels.new=nativeNew
f=fresh();before=nextId
setmetatable(f.game.data.map_tilesets.P.palettes[1],{__index=function()error('unused getter')end})
Native.prefetch(f.pair);T.eq(nextId,before,'custom source accessors retain main-thread ownership')
T.check(Native.get(f.pair).image~=nil,'custom palettes still build natively')
f=fresh();before=nextId
T.check(Native.get(f.pair).image~=nil,'immediately required atlas remains synchronously available')
T.eq(nextId,before,'immediately required get never serializes and submits a job it must cancel')
f=fresh();before=nextId;P.buildWorkers=false
Native.prefetch(f.pair);T.eq(nextId,before,'global worker OFF preserves coroutine admission')
T.check(Native.get(f.pair).image~=nil,'worker OFF atlas remains usable')
P.buildWorkers=true
f=fresh();local submit=Pool.submit
Pool.submit=function()return nil,'owned start failure'end
Native.prefetch(f.pair)
T.check(Native.get(f.pair).image~=nil,'pool startup failure retains the coroutine path')
Pool.submit=submit
f=fresh();Native.prefetch(f.pair);id=nextId;queue[id].failed('owned failure');queue[id]=nil
T.check(Native.get(f.pair).image~=nil,'CPU worker error retains native construction')
f=fresh();Native.prefetch(f.pair);id=nextId
local primary=f.game.data.map_tilesets.P
finish(id);primary.palettes[1][2][1]=17
Pool.poll(4)
T.eq(Build._cacheInfo(Native._pairs).worker,0,'source edit after CPU completion retires the reply before upload')
T.check(Native.get(f.pair).image~=nil,'late source edit keeps fallback available')
Native.release();P.tier='low'
local fixture=Fixture.new('emerald');local handles={};before=nextId
for i=1,3 do handles[i]=Build.prepare(fixture.pair,fixture.layout,function()end,function()end)end
T.eq(nextId-before,2,'LOW admits at most two prepared atlases for one worker')
T.eq(handles[3],nil,'bounded LOW admission leaves excess work on the coroutine path')
for _,handle in ipairs(handles)do Build.cancel(handle)end
P.tier='high'
local fixture=Fixture.new('emerald');local submitNow=Pool.submit;local immediate=0
Pool.submit=function(_,_,payload,done)
  nextId=nextId+1;done(Core.run(payload));return nextId
end
local instant=Build.prepare(fixture.pair,fixture.layout,function()immediate=immediate+1 end,function()error('unexpected error')end)
T.eq(immediate,1,'an immediate provider reply is delivered exactly once')
T.eq(instant,nil,'completed provider reply cannot leave a pending handle')
Pool.submit=submitNow
local moduleName='src.compat.gen1.AtlasPixels'
local buildName='src.compat.gen1.AtlasBuild'
local savedPixels,savedBuild=package.loaded[moduleName],package.loaded[buildName]
package.loaded[moduleName]={new=savedPixels.new}
package.loaded[buildName]=nil
local customBuild=require(buildName)
T.eq(customBuild.available(),false,'a replacement source module needs no private worker guard')
T.eq(customBuild.prepare(fixture.pair,fixture.layout,function()end,function()end),nil,'replacement source module retains native admission')
package.loaded[moduleName],package.loaded[buildName]=savedPixels,savedBuild
P.buildWorkers=true;P.atlasWorker=false
f=fresh();before=nextId;Native.prefetch(f.pair)
T.eq(nextId,before,'atlas worker switch independently preserves fallback')
T.check(Native.get(f.pair).image~=nil,'atlas OFF result remains usable')
Native.release()
T.finish('Gen3 atlas core bytes, live animations and worker ownership')
