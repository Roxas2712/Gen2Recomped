-- One native System, owned entirely by this worker. Integration by Roxas2712.
require('love.thread');require('love.timer');require('love.image');require('love.sound')
local Json=require('src.link.Json')
local job=Json.decode(...)
local ABI=require('src.import.PokemonXYABI');local ffi=ABI.ffi
local events=love.thread.getChannel(job.channel..'.events')
local frames=love.thread.getChannel(job.channel..'.frames')
local commands=love.thread.getChannel(job.channel..'.commands')
local audio=love.thread.getChannel(job.channel..'.audio')
local recycle=love.thread.getChannel(job.channel..'.recycle')
local pool,acknowledged={},{}
local function emit(event)events:push(Json.encode(event))end
local bit=require('bit')
local lib,handle
local picture=ffi.new('AscendantPicture[1]')
local count=ffi.new('size_t[1]')
local function failure()return ffi.string(lib.ascendant_3ds_error())end
local function status()return Json.decode(ffi.string(lib.ascendant_3ds_status(handle)))end
local function keep(data)
 if #pool<6 then pool[#pool+1]=data else data:release()end
end
local function release(message)
 if not message then return end
 for _,data in pairs(message.images or {})do keep(data)end
end
local function recycled()
 local returned=recycle:pop()
 while returned do
  acknowledged[returned.index]=returned.revision;keep(returned.data);returned=recycle:pop()
 end
end
local function imageData(w,h)
 for i,data in ipairs(pool)do if data:getWidth()==w and data:getHeight()==h then table.remove(pool,i);return data end end
 return love.image.newImageData(w,h,'rgba8')
end
local ok,why=pcall(function()
 lib=ABI.load(job.session.bridge)
 if job.mode=='playing'then job.session.language=1 end
 handle=lib.ascendant_3ds_open(Json.encode(job.session));assert(handle~=nil,failure())
 emit{event='ready',stats=status()}
 local language=job.mode=='playing'and require('src.import.PokemonXYLanguage').new(job.session,emit)or nil
 local input={buttons=0,cx=0,cy=0,tx=-1,ty=-1};local paused=false;local keys=0;local buttonQueue={};local nextFrame=love.timer.getTime();local n=0
 local lastKeyboard
 local durations={};local warmup=120;local samples=360
 while true do
  local request=commands:pop()
  while request do
   local message=Json.decode(request)
   if message.action=='quit' then lib.ascendant_3ds_close(handle);handle=nil;emit{event='closed'};return end
   if message.action=='input' then input=message end
   if message.action=='button' then buttonQueue[#buttonQueue+1]=message end
   if message.action=='clearKeys' then keys=0;buttonQueue={} end
   if message.action=='pause' then paused=message.paused;keys=0;buttonQueue={};nextFrame=love.timer.getTime() end
   if message.action=='slider' then job.session.stereo=message.value>0 and 'on' or 'off';lib.ascendant_3ds_slider(handle,message.value) end
   if message.action=='keyboard' then
    if not lib.ascendant_3ds_answer_keyboard(handle,message.text,message.button)then emit{event='notice',message=failure()}end
   end
   if message.action=='reset-language'and language then language:reset()end
   if message.action=='state' then
    local success=lib.ascendant_3ds_state(handle,message.path,message.load)
    emit{event='notice',message=success and (message.load and 'Schnellstand geladen.' or 'Schnellstand gespeichert.') or failure()}
   end
   request=commands:pop()
  end
  local now=love.timer.getTime()
  if paused then love.timer.sleep(.01)
  elseif job.mode~='benchmark' and now<nextFrame then love.timer.sleep(math.min(.01,nextFrame-now))
  else
   local begin=love.timer.getTime()
   -- Preserve both edges even when several key events arrive between two
   -- emulation frames. Polling alone can merge quick repeated taps.
   local edge=table.remove(buttonQueue,1)
   if edge then keys=edge.pressed and bit.bor(keys,edge.bit) or bit.band(keys,bit.bnot(edge.bit)) end
   local buttons=bit.bor(input.buttons or 0,keys)
   -- Private, input-free player data for previews; acknowledge only startup
   -- prompts there, never send these scripted inputs to a player's session.
   if job.mode=='preview' and (n>=150 and n<156 or n>=230 and n<236) then buttons=1 end
   if language and language.active then buttons=language:buttons(tonumber(lib.ascendant_3ds_language_prompt(handle)),buttons,n)end
   local result=lib.ascendant_3ds_step(handle,buttons,input.cx or 0,input.cy or 0,input.tx or -1,input.ty or -1,job.session.stereo~='off')
   assert(result==0,failure());n=n+1
   if job.mode=='playing'then
    local request=lib.ascendant_3ds_keyboard(handle);local current=request~=nil and ffi.string(request)or nil
    if current~=lastKeyboard then lastKeyboard=current;emit{event='keyboard',request=current and Json.decode(current)or false}end
   end
   local stepEnded=love.timer.getTime();recycled()
   release(frames:pop())
   local blank=lib.ascendant_3ds_blank(handle,1)
   local checked=love.timer.getTime()
   local message={images={},revisions={},frame=n,blank_bottom=blank,right=false}
   for i=0,2 do
    if lib.ascendant_3ds_picture(handle,i,picture) then
     if i==2 then message.right=true end
     local revision=tonumber(lib.ascendant_3ds_revision(handle,i));message.revisions[i+1]=revision
     if acknowledged[i+1]~=revision then
      local p=picture[0];local data=imageData(tonumber(p.width),tonumber(p.height))
      ffi.copy(data:getFFIPointer(),p.data,tonumber(p.bytes));message.images[i+1]=data
     end
    end
   end
   local copied=love.timer.getTime()
   if job.mode=='playing' or job.mode=='benchmark' then
    local data=lib.ascendant_3ds_audio(handle,count);local length=tonumber(count[0])
    if length>0 and audio:getCount()<12 then
     local sound=love.sound.newSoundData(length,32728,16,2)
     ffi.copy(sound:getFFIPointer(),data,length*4);audio:push(sound)
    end
   end
   message.seconds=love.timer.getTime()-begin;message.blank_ms=(checked-stepEnded)*1000;message.copy_ms=(copied-checked)*1000
   -- Retain the stage breakdown of isolated stalls too; a steady presenter
   -- can otherwise conceal a blocked emulation frame between HUD samples.
   if n%60==0 or message.seconds>.05 then
    message.stats=status();message.stats.sample_frame=n
    if message.seconds>.05 then message.stats.top_blank=lib.ascendant_3ds_blank(handle,0)end
   end
   frames:push(message)
   if job.mode=='benchmark' and n>warmup then durations[#durations+1]=love.timer.getTime()-begin end
   if job.mode=='benchmark' and #durations>=samples then
    emit{event='benchmark',durations=durations,stats=status()};lib.ascendant_3ds_close(handle);handle=nil;return
   end
   nextFrame=math.max(nextFrame+4481136/268111856,love.timer.getTime()-.05)
  end
 end
end)
if handle~=nil and lib then lib.ascendant_3ds_close(handle)end
local returned=recycle:pop();while returned do returned.data:release();returned=recycle:pop()end
for _,data in ipairs(pool)do data:release()end
if not ok then emit{event='error',message=tostring(why)}end
