-- One worker owns both guest contexts and all native calls.
require('love.thread');require('love.timer');require('love.image');require('love.sound')
local Json=require('src.link.Json');local job=Json.decode(...)
local ABI=require('src.pinball.ABI');local ffi=ABI.ffi
local channels={}
for _,k in ipairs{'commands','frames','audio','events'}do channels[k]=love.thread.getChannel(job.channel..'.'..k)end
local function emit(event)channels.events:push(Json.encode(event))end
local lib,handles
local function failure()return ffi.string(lib.ascendant_pinball_error())end
local function release(message)if message then for _,data in ipairs(message.images)do data:release()end end end
local function close()
 if handles then
  for _,m in ipairs(handles)do if lib.ascendant_pinball_close(m)==0 then emit{event='notice',message=failure()}end end
  handles=nil
 end
end
local ok,why=pcall(function()
 lib=ABI.load(job.session.bridge);handles={}
 for i=1,job.seats or 1 do
  local path=job.duel and '' or job.session.player..'/solo-'..(job.session.locale or 'en')..'-'..i..'.sav'
  local m=lib.ascendant_pinball_open(job.session.rom,job.session.bios,path)
  assert(m~=nil,failure());handles[i]=m
  if job.full_table then assert(lib.ascendant_pinball_view(m,1)~=0,failure())end
 end
 emit{event='ready'}
 local input={0,0};local paused=false;local phase=job.duel and 'preparing' or 'playing'
 local prepared,elapsed,done,best={},{},{},{}
 local nextFrame=love.timer.getTime();local n=0
 local width,height,count,rate=ffi.new('uint32_t[1]'),ffi.new('uint32_t[1]'),ffi.new('size_t[1]'),ffi.new('uint32_t[1]')
 while true do
  local raw=channels.commands:pop()
  while raw do
   local msg=Json.decode(raw)
   if msg.action=='quit' then close();emit{event='closed'};return end
   if msg.action=='input' then input=msg.buttons end
   if msg.action=='start' and phase=='waiting'then phase='playing';nextFrame=love.timer.getTime()end
   if msg.action=='pause' then paused=msg.value;input={0,0};nextFrame=love.timer.getTime()end
   if msg.action=='view'then
    for _,m in ipairs(handles)do assert(lib.ascendant_pinball_view(m,msg.full_table and 1 or 0)~=0,failure())end
   end
   if msg.action=='state' then
    if job.duel then emit{event='notice',message='Schnellstände sind im Punkteduell gesperrt.'}
    else
     local success=lib.ascendant_pinball_state(handles[1],job.session.player..'/quick.state',msg.load and 1 or 0)
     emit{event='notice',message=success~=0 and (msg.load and 'Schnellstand geladen.' or 'Schnellstand gespeichert.')or failure()}
    end
   end
   raw=channels.commands:pop()
  end
  local now=love.timer.getTime()
  if paused or phase=='waiting' or phase=='finished' then love.timer.sleep(.01)
  elseif now<nextFrame then love.timer.sleep(math.min(.005,nextFrame-now))
  else
   local begin=love.timer.getTime();n=n+1
   local message={images={},stats={},frame=n}
   for i,m in ipairs(handles)do
    local function read(address,bytes)return tonumber(lib.ascendant_pinball_read(m,address,bytes or 1))end
    local buttons=input[i] or 0
    if phase=='preparing'then
     buttons=0
     if n%45<3 then
      local main=read(0x0200B0C2)
      if main==0 or main==1 then buttons=1
      elseif main==10 then
       local selected=read(0x02002840,2)
       local step=read(0x02002842,2)
       if step==0 and selected~=(job.field or 0)then buttons=(job.field or 0)==1 and 16 or 32 else buttons=1 end
      end
     end
    end
    if job.session.language_index and read(0x0200B0C2)==12 then
     buttons=0
     if read(0x0200B0C3)>0 and n%12<3 then
      local cursor=read(0x0202C724)
      if cursor==job.session.language_index then buttons=1 else buttons=128 end
     end
    end
    if not prepared[i] or phase=='playing' and not done[i]then
     assert(lib.ascendant_pinball_step(m,buttons)~=0,failure())
     if job.duel and phase=='playing'then elapsed[i]=(elapsed[i]or 0)+1 end
    end
    local ptr=lib.ascendant_pinball_picture(m,width,height)
    local data=love.image.newImageData(tonumber(width[0]),tonumber(height[0]),'rgba8')
    ffi.copy(data:getFFIPointer(),ptr,tonumber(width[0])*tonumber(height[0])*4);message.images[i]=data
    local game=read(job.session.game_pointer_address or 0x020314E0,4);local valid=game>=0x02000000 and game<0x02040000
    message.stats[i]={main=read(0x0200B0C2),sub=read(0x0200B0C3),field=read(0x0200B0C4),
     score=valid and read(game+0x44,4)+100000000*read(game+0x48,4)or 0,
     lives=valid and read(game+0x30)or 0,frame=tonumber(lib.ascendant_pinball_frame(m))}
    local stats=message.stats[i]
    if job.duel then
     if phase=='preparing' and stats.main==2 and stats.sub==1 then prepared[i]=true end
     best[i]=math.max(best[i]or 0,stats.score);stats.score=best[i];stats.elapsed=elapsed[i]or 0
     if phase=='playing' and (stats.elapsed>=(job.frameLimit or 18000) or stats.main==2 and stats.sub>=2 and stats.field<2 or stats.main==8)then done[i]=true end
     stats.done=done[i]or false
    end
    if i==(job.audioSeat or 1) and channels.audio:getCount()<6 then
     local samples=lib.ascendant_pinball_audio(m,count,rate);local length=tonumber(count[0])
     if length>0 then
      local sound=love.sound.newSoundData(length,tonumber(rate[0]),16,1)
      ffi.copy(sound:getFFIPointer(),samples,length*2);channels.audio:push(sound)
     end
    end
   end
   if phase=='preparing'then
    local all=true;for i=1,#handles do if not prepared[i]then all=false end end
    if all then
     phase='waiting';local checkpoints={}
     for i,m in ipairs(handles)do checkpoints[i]=ffi.string(lib.ascendant_pinball_checkpoint(m))end
     emit{event='prepared',checkpoints=checkpoints}
    end
   elseif job.duel and phase=='playing'then
    local all=true;for i=1,#handles do if not done[i]then all=false end end
    if all then phase='finished'end
   end
   message.phase=phase;message.seconds=love.timer.getTime()-begin
   -- A small completed-frame FIFO absorbs variable native execution time.
   -- Clearing the mailbox before step() lost visible frames; publishing only
   -- the newest frame still magnified start/completion jitter. Bound latency
   -- to three frames while retaining every guest frame and original physics.
   channels.frames:performAtomic(function(channel)
    while channel:getCount()>=3 do release(channel:pop())end
    channel:push(message)
   end)
   -- Never skip guest frames or accelerate physics to hide a slow machine.
   nextFrame=math.max(nextFrame+280896/16777216,love.timer.getTime()-.05)
  end
 end
end)
close()
if not ok then emit{event='error',message=tostring(why)}end
