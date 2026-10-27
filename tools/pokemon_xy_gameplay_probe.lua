-- Interactive gameplay/presentation QA using the production native frontend.
-- Integration by Roxas2712. Only standard console input; no save/memory edits.
local Json=require('src.link.Json')
local root=assert(os.getenv('KALOS_QA_OUTPUT'));local player,rows,sequence,active,untilFrame,segment
local elapsed,readAt,nextTelemetry,nextScreenshot=0,0,0,0
local instrumentationUntil=0
local initialCapture=false
local lastSlowFrame=0;local slowCount=0
local phase='startup';local segments={};local dtRows={};local totalDraws=0;local startedFrame=0
local function write(name,value)local f=assert(io.open(root..'/'..name,'wb'));f:write(type(value)=='string'and value or Json.encode(value));f:close()end
local function metric(values)
 if #values==0 then return {}end
 local sorted={};local sum=0;for i,v in ipairs(values)do sorted[i]=v;sum=sum+v end;table.sort(sorted)
 return {samples=#values,mean_ms=sum/#values,p95_ms=sorted[math.max(1,math.ceil(#sorted*.95))],p99_ms=sorted[math.max(1,math.ceil(#sorted*.99))],max_ms=sorted[#sorted]}
end
local function finishSegment()
 if not segment then return end
 segment.wall_seconds=elapsed-segment.start;segment.emulated_frames=(player.frame or 0)-segment.first_frame
 segment.emulated_hz=segment.emulated_frames/math.max(.001,segment.wall_seconds)
 segment.presentation=metric(dtRows);segments[#segments+1]=segment;segment=nil;dtRows={}
 write('summary.json',{edition=player.session.edition,resolution=player.session.resolution,stereo=player.settings.stereo,segments=segments,scope='visible production frontend, native audio queue, standard HID; instrumented QA host'})
end
local function mark(name)
 finishSegment();phase=name;segment={name=name,start=elapsed,first_frame=player.frame or 0,hitches_over_33ms=0,hitches_over_50ms=0,hitches_over_100ms=0}
end
local function capture(name)
 instrumentationUntil=elapsed+.5
 love.graphics.captureScreenshot(function(data)local encoded=data:encode('png');write(name..'.png',encoded:getString());encoded:release();data:release()end)
end
function love.load()
 local f=assert(io.open(assert(os.getenv('KALOS_QA_SESSION')),'rb'));local session=Json.decode(f:read('*a'));f:close()
 player=require('src.import.PokemonXYNative').new(session,'playing')
 if os.getenv('KALOS_RESUME_STATE')then player:command{action='state',path=os.getenv('KALOS_RESUME_STATE'),load=true}end
 local original=player.input
 player.input=function(self,dt)
  if active then self:command{action='input',buttons=active.buttons or 0,cx=active.cx or 0,cy=active.cy or 0,tx=active.tx or -1,ty=active.ty or -1}
  else original(self,dt)end
 end
 rows=assert(io.open(root..'/frames.csv','w'));rows:write('seconds,phase,dt_ms,emu_frame,worker_ms,upload_ms,copy_ms,audio_playing,audio_free,focused,qa_instrumentation,emulation_ms,readback_ms\n')
 mark('startup')
end
local function command(c)
 local log=assert(io.open(root..'/inputs.jsonl','a'));log:write(Json.encode{seconds=elapsed,frame=player.frame,command=c},'\n');log:close()
 if c.action=='sequence'then sequence=c.steps;active=nil;untilFrame=nil
 elseif c.action=='mark'then mark(c.name)
 elseif c.action=='capture'then capture(c.name)
 elseif c.action=='state'then instrumentationUntil=elapsed+.5;player:command{action='state',path=root..'/'..c.name..'.state',load=c.load==true}
 elseif c.action=='keyboard'then assert(player.keyboardForm,'No keyboard applet');player:command{action='keyboard',text=c.text,button=c.button or 1}
 elseif c.action=='quit'then finishSegment();player:stop()
 elseif c.action=='pause'then player.paused=c.paused;player:command(c)
 end
end
function love.update(dt)
 elapsed=elapsed+dt
 -- A screenshot requested below must not erase the slow frame that triggered it.
 -- Encoding costs belong to subsequent samples, after the capture was requested.
 local qaSample=elapsed<instrumentationUntil
 player:update(dt)
 if player.error then error(player.error)end
 if not initialCapture and player.ready and (player.frame or 0)>30 and elapsed>2 then initialCapture=true;capture('entry')end
 if player.frame and player.frame~=lastSlowFrame and (player.frameSeconds or 0)>.1 and slowCount<24 then
  lastSlowFrame=player.frame;slowCount=slowCount+1
  local log=assert(io.open(root..'/slow-frames.jsonl','a'));log:write(Json.encode{seconds=elapsed,frame=player.frame,worker_ms=player.frameSeconds*1000,stats=player.stats,phase=phase,focused=love.window.hasFocus(),qa_instrumentation=qaSample},'\n');log:close()
  capture('slow-'..player.frame)
 end
 if sequence and player.ready then
  if not active or (player.frame or 0)>=(untilFrame or 0)then
   active=table.remove(sequence,1)
   if active then
    if active.mark then mark(active.mark)end
    if active.capture then capture(active.capture)end
    if active.state then instrumentationUntil=elapsed+.5;player:command{action='state',path=root..'/'..active.state..'.state',load=active.load==true}end
    untilFrame=(player.frame or 0)+(active.frames or 1)
   else sequence=nil;untilFrame=nil;player:command{action='input',buttons=0,cx=0,cy=0,tx=-1,ty=-1}end
  end
 end
 if segment and not player.paused and not qaSample then
  dtRows[#dtRows+1]=dt*1000
  for _,limit in ipairs{33,50,100}do if dt*1000>limit then local name='hitches_over_'..limit..'ms';segment[name]=segment[name]+1 end end
 end
 rows:write(string.format('%.4f,%s,%.3f,%d,%.3f,%.3f,%.3f,%s,%d,%s,%s,%.3f,%.3f\n',elapsed,phase,dt*1000,player.frame or 0,(player.frameSeconds or 0)*1000,player.uploadMs or 0,player.copyMs or 0,tostring(player.sound and player.sound:isPlaying()or false),player.sound and player.sound:getFreeBufferCount()or -1,tostring(love.window.hasFocus()),tostring(qaSample),player.stats and player.stats.emulation_ms or 0,player.stats and player.stats.readback_ms or 0))
 if elapsed>=nextTelemetry then
  nextTelemetry=elapsed+1;rows:flush()
  write('live.json',{elapsed=elapsed,phase=phase,frame=player.frame,draw_calls=totalDraws,graphics_active=love.graphics.isActive(),focused=love.window.hasFocus(),ready=player.ready,notice=player.notice,error=player.error,keyboard=player.keyboardForm and player.keyboardForm.request,sequence_remaining=sequence and #sequence or 0,active=active,settings=player.settings})
 end
 if elapsed>=readAt then
  readAt=elapsed+.2;local f=io.open(root..'/command.json','rb')
  if f then local bytes=f:read('*a');f:close();os.rename(root..'/command.json',root..'/command.received.json');local batch=Json.decode(bytes);for _,c in ipairs(batch)do command(c)end end
 end
 if player.closed and not player.thread:isRunning()then finishSegment();rows:close();rows=nil;player:dispose();love.event.quit()end
end
function love.draw()if player and not player.disposed then player:draw(love.graphics.getDimensions())end;totalDraws=totalDraws+1 end
function love.keypressed(key,...)if key=='f12'then capture('manual-'..math.floor(elapsed))else player:keypressed(key,...)end end
function love.keyreleased(...)player:keyreleased(...)end
function love.textinput(...)player:textinput(...)end
function love.mousepressed(...)player:mousepressed(...)end
function love.gamepadpressed(...)player:gamepadpressed(...)end
function love.quit()if player then finishSegment();player:stop()end;if rows then rows:close();rows=nil end end
function love.errorhandler(message)write('fatal.txt',tostring(message));io.stderr:write(tostring(message)..'\n');return function()return 1 end end
