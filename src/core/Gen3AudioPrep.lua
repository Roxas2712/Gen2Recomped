-- Bounded preparation of actual M4A effect PCM; never plays a Source.
-- Contributions by Roxas2712. Existing licences apply by provenance.
local P={version=1,maxBytes=16*1024*1024,maxEntries=48,maxPending=64,
 stats={completed=0,hits=0,cold=0,steps=0,maxSlice=0,cancelled=0,errors=0}}
local ready,pending,queue,planned={},{},{},{};local bytes,count,stamp=0,0,0
local audio,identity,suspended;local synth
-- Float64 retains the exact native samples, without two growing Lua arrays
-- becoming garbage after each effect. A single active job borrows chunks;
-- synchronous cache misses can borrow another lease without overwriting it.
local ffiOk,ffi=pcall(require,'ffi')
local chunkFrames,maxChunks=512,256 -- at most 2 MiB retained scratch
local freeChunks={}
local function releaseScratch(lease)
 if not lease or not lease.blocks then return end
 for _,block in ipairs(lease.blocks)do if #freeChunks<maxChunks then freeChunks[#freeChunks+1]=block end end
 lease.blocks=nil
end
local function chunk(lease,index)
 local row=lease.blocks[index]
 if not row then
  row=table.remove(freeChunks)or(ffiOk and ffi.new('double[1024]')or {})
  lease.blocks[index]=row
 end
 return row
end
local clock=function()return love and love.timer and love.timer.getTime()or os.clock()end
local function dataset(data)
 local a=data and data.audio;local g=a and a.gen3
 return a,g and table.concat({tostring(g),tostring(g.file),tostring(g.base),tostring(a.programPrefix)},':')
end
function P.reset()
 P.stats.cancelled=P.stats.cancelled+#queue
 for _,job in ipairs(queue)do releaseScratch(job.scratch)end
 freeChunks={}
 ready,pending,queue,planned={},{},{},{};bytes,count,stamp=0,0,0;audio,identity=nil,nil
end
local function bind(data)
 local a,id=dataset(data);if not id then if audio then P.reset()end;return false end
 if audio~=a or identity~=id then P.reset();audio,identity=a,id end
 return true
end
local function put(def,sd)
 if not sd then return end
 local size=sd:getSampleCount()*sd:getChannelCount()*2
 if size>P.maxBytes then return end
 while count>=P.maxEntries or bytes+size>P.maxBytes do
  local oldest,row;for k,v in pairs(ready)do if not row or v.stamp<row.stamp then oldest,row=k,v end end
  if not row then break end;ready[oldest]=nil;count=count-1;bytes=bytes-row.bytes
 end
 stamp=stamp+1;ready[def]={sd=sd,bytes=size,stamp=stamp};bytes=bytes+size;count=count+1
end
-- Same sequencer and tail threshold as native renderEffect, with checkpoints
-- in BOTH synthesis and SoundData upload. No RNG, clocks or VM are advanced.
function P.render(data,def,options,cancelled)
 if cancelled and cancelled()then return nil end
 options=options or {};local ok,engine=pcall(synth.newEngine,data,def,{allowLoops=false})
 if not(ok and engine)then return nil end
 local cap=math.floor(44100*math.min(8,options.seconds or 8))
 local lease=options.scratch or {};lease.blocks=lease.blocks or {}
 local n,audible=0,0;local checkpoint=options.checkpoint
 while n<cap do
  if cancelled and n%1024==0 and cancelled()then releaseScratch(lease);return nil end
  local l,r=engine:sampleStereo();n=n+1
  local offset=(n-1)%chunkFrames;local block=chunk(lease,math.floor((n-1)/chunkFrames)+1)
  block[offset*2],block[offset*2+1]=l,r
  if math.abs(l)>.002 or math.abs(r)>.002 then audible=n end
  if engine:finished()then break end
  if checkpoint and n%128==0 then checkpoint()end
 end
 local length=math.min(n,audible+math.floor(44100*.05));if length<64 then releaseScratch(lease);return nil end
 local sd=love.sound.newSoundData(length,44100,16,2)
 for i=1,length do
  if cancelled and (i-1)%1024==0 and cancelled()then
   if sd.release then sd:release()end
   releaseScratch(lease);return nil
  end
  local block=lease.blocks[math.floor((i-1)/chunkFrames)+1];local offset=((i-1)%chunkFrames)*2
  sd:setSample(i-1,1,block[offset]);sd:setSample(i-1,2,block[offset+1])
  if checkpoint and i%128==0 then checkpoint()end
 end
 releaseScratch(lease)
 return sd
end
function P.enqueue(data,def)
 if suspended or not def or not bind(data)or ready[def]or pending[def]or #queue>=P.maxPending then return false end
 local job={data=data,def=def,scratch={blocks={}}};pending[def]=job;queue[#queue+1]=job
 job.co=coroutine.create(function()job.sd=P.render(data,def,{checkpoint=coroutine.yield,scratch=job.scratch})end)
 return true
end
function P.step(budget)
 if suspended then return end
 local start=clock();local deadline=start+(budget or .002)
 while #queue>0 do
  local job=queue[1];local a,id=dataset(job.data)
  if audio~=a or identity~=id then P.reset();return end
  local ok=coroutine.resume(job.co)
  if not ok or coroutine.status(job.co)=='dead'then
   releaseScratch(job.scratch)
   table.remove(queue,1);pending[job.def]=nil
   if ok then put(job.def,job.sd);P.stats.completed=P.stats.completed+1 else P.stats.errors=P.stats.errors+1 end
  end
  if clock()>=deadline then break end
 end
 local elapsed=clock()-start;P.stats.steps=P.stats.steps+1;P.stats.maxSlice=math.max(P.stats.maxSlice,elapsed)
end
function P.status()return {bytes=bytes,entries=count,pending=#queue,suspended=not not suspended,scratchBytes=#freeChunks*chunkFrames*2*8}end
function P.suspend()suspended=true;P.reset()end
function P.resume()suspended=false;P.reset()end
function P.plan(data,parties)
 if suspended or not bind(data)then return end
 local sfx=audio.sfx or {};local songs=audio.songs or {};local seen={}
 local function name(key)
  local def=sfx[key];local song=type(def)=='table'and def.m4a~=nil and songs[('SONG_%03X'):format(def.m4a)]
  if song and not planned[song]then
   if ready[song]or pending[song]or P.enqueue(data,song)then planned[song]=true end
  end
 end
 local function anim(a)
  if type(a)~='table'or seen[a]then return end;seen[a]=true
  if a.sound then name(a.sound)end
  for _,v in ipairs(a.variants or {})do anim(v.anim)end
 end
 for _,party in ipairs(parties or {})do for slot,mon in ipairs(party)do if slot<=6 and type(mon)=='table'and not(mon.egg or mon.isEgg)then
  for _,move in ipairs(mon.moves or {})do
   local id=type(move)=='table'and(move.id or move.moveId or move.move)or move
   local def=data.moves and data.moves[id];if def then anim(def.anim)end
  end
 end end end
end
function P.install(M4A)
 if M4A.effectPrep then return M4A.effectPrep end
 synth=M4A;local invalidate=M4A.invalidate
 M4A.invalidate=function(...)P.reset();return invalidate(...)end
 M4A.renderEffect=function(data,def,options,cancelled)
  -- Cancellable jobs own their output; abandoning one must not release a
  -- shared warm-cache buffer or publish a partial render.
  if cancelled then return P.render(data,def,options,cancelled)end
  -- Non-default renders retain their own options and never alias a warm entry.
  if options and next(options)~=nil then return P.render(data,def,options)end
  if not bind(data)then return P.render(data,def,options)end
  local hit=ready[def]
  if hit then stamp=stamp+1;hit.stamp=stamp;P.stats.hits=P.stats.hits+1;return hit.sd end
  -- A real call that beats preparation still plays synchronously on schedule.
  -- Never finish an entire queued coroutine in an idle slice or delay the VM.
  pending[def]=nil;for i=#queue,1,-1 do if queue[i].def==def then releaseScratch(queue[i].scratch);table.remove(queue,i)end end
  P.stats.cold=P.stats.cold+1;local sd=P.render(data,def,options);put(def,sd);return sd
 end
 M4A.effectPrep=P;return P
end
return P
