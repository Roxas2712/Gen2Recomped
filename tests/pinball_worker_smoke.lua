-- Real LÖVE worker + native guests, private ROM/profile paths from environment.
-- Run through a managed starter with isolated saves; no global GPU slot needed.
local Json=require('src.link.Json')
local root=assert(os.getenv('PINBALL_SMOKE_ROOT'))
local f=assert(io.open(root..'/.local/pinball-rs/library.json'));local session=Json.decode(f:read('*a'));f:close()
local locale=os.getenv('PINBALL_SMOKE_LOCALE')
if locale and locale~='en'then
 local eu=assert(session.variants and session.variants.eu,'EU variant missing')
 for k,v in pairs(eu)do session[k]=v end
 session.locale=locale;session.language_index=({fr=1,de=2,it=3,es=4})[locale];session.content=session.content..':'..locale
end
local field=tonumber(os.getenv('PINBALL_SMOKE_FIELD'))or 0
local prefix='pinball.smoke'
local events=love.thread.getChannel(prefix..'.events')
local frames=love.thread.getChannel(prefix..'.frames')
local audio=love.thread.getChannel(prefix..'.audio')
local commands=love.thread.getChannel(prefix..'.commands')
local thread=love.thread.newThread('src/pinball/worker.lua')
local Net=require('src.link.Net');local Duel=require('src.pinball.Duel')
assert(Net.available(),'LÖVE ENet transport unavailable')
local host,join=Net.new(),Net.new();local port=assert(tonumber(os.getenv('PINBALL_SMOKE_PORT')))
assert(host:host(port),host.error);assert(join:join('127.0.0.1:'..port),join.error)
local rules={rom=session.rom_sha1,backend=session.backend,content=session.content,field=field,frames=1800,seed=0}
local left,right=Duel.new(host,true,rules),Duel.new(join,false,rules)
local Input=require('src.pinball.Input')
local function pad(button)
 return {connected=true,isGamepad=function()return true end,isConnected=function(self)return self.connected end,
  isGamepadDown=function(self,b)return b==button end,getGamepadAxis=function()return 0 end}
end
local pad1,pad2=pad('leftshoulder'),pad('rightshoulder')
local input=Input.new(2,{pad1,pad2});local none=function()return false end
assert(input:buttons(1,none,nil,true)==32 and input:buttons(2,none,nil,true)==1,'Two-controller mapping failed')
pad1.connected=false
assert(input:buttons(1,none,nil,true)==0 and input:buttons(2,none,nil,true)==1,'Controller seats shifted after disconnect')
assert(input:buttons(2,none,nil,false)==0,'Unfocused input leaked')
local replacement=pad('a')
assert(input:join(replacement)==1 and input.pads[2]==pad2,'Replacement controller displaced the other player')
local started,finished,pending=false,false,false
local begin=love.timer.getTime();local maxScore=0;local measured={};local latest
local out=assert(os.getenv('PINBALL_SMOKE_OUTPUT'))
local function report(data)
 local file=assert(io.open(out..'/worker-report.json','w'));file:write(Json.encode(data));file:close()
end
function love.load()
 thread:start(Json.encode{session=session,channel=prefix,seats=2,duel=true,field=field,frameLimit=1800})
end
function love.update()
 left:update(.001);right:update(.001)
 local raw=events:pop()
 while raw do
  local msg=Json.decode(raw)
  assert(msg.event~='error',msg.message)
  if msg.event=='prepared'then
   assert(msg.checkpoints[1]==msg.checkpoints[2],'Starting checkpoints differ')
   assert(#msg.checkpoints[1]==40,'Missing native checkpoint')
   print('PREPARED '..msg.checkpoints[1]);assert(left:ready(msg.checkpoints[1]));assert(right:ready(msg.checkpoints[2]))
  elseif msg.event=='closed'then
   assert(finished,'Worker stopped before game end');love.event.quit(0)
  end
  raw=events:pop()
 end
 assert(not thread:getError(),thread:getError())
 if not started and left.state=='playing'and right.state=='playing'then commands:push(Json.encode{action='start'});started=true end
 local msg=frames:pop()
 if msg then
  latest=msg.stats
  if started then
   for i,d in ipairs{left,right}do
    local stats=latest[i]
    if stats.elapsed>0 and not d.localDone then assert(d:progress(stats.elapsed,string.format('%.0f',stats.score),stats.done),'Native score update rejected')end
   end
  end
  if started and msg.phase=='playing'then
   measured[#measured+1]=msg.seconds*1000
   local tick=latest[1].elapsed
   local buttons=tick%120<55 and 1 or tick%120<110 and 32 or 0
   commands:push(Json.encode{action='input',buttons={buttons,0}})
   maxScore=math.max(maxScore,latest[1].score)
   if tick%300<3 then print('PLAY '..tick..' '..latest[1].score..' / '..latest[2].score)end
  end
  if msg.phase=='finished'and not pending then
   pending=true
   for i,data in ipairs(msg.images)do data:encode('png','pinball-seat-'..i..'.png')end
  end
  for _,data in ipairs(msg.images)do data:release()end
 end
 if pending and left.state=='finished'and right.state=='finished'and not finished then
  finished=true;local want=latest[1].score==latest[2].score and 'draw'or latest[1].score>latest[2].score and 'win'or 'loss';local opposite=({win='loss',loss='win',draw='draw'})[want];assert(left.result==want and right.result==opposite,'Incorrect online winner from native scores')
  local sum=0;for _,v in ipairs(measured)do sum=sum+v end;table.sort(measured)
  report{passed=true,transport='real localhost ENet',left_result=left.result,right_result=right.result,
   phase='finished',guests=latest,maxScore=maxScore,measured_frames=#measured,
   mean_ms=sum/math.max(1,#measured),p95_ms=measured[math.ceil(#measured*.95)]}
  commands:push(Json.encode{action='quit'});host:close();join:close()
 end
 assert(left.state~='cancelled',left.error);assert(right.state~='cancelled',right.error)
 local sound=audio:pop();while sound do sound:release();sound=audio:pop()end
 if love.timer.getTime()-begin>110 then
  commands:push(Json.encode{action='quit'});report{passed=false,error='timeout',latest=latest};error('Native worker smoke timed out')
 end
 love.timer.sleep(.001)
end
function love.errorhandler(message)
 print('PINBALL TEST FAILURE '..tostring(message));report{passed=false,error=tostring(message)}
 commands:push(Json.encode{action='quit'});thread:wait()
 return function()return 1 end
end
