-- Actual native worker focus/pause scheduling, private paths. By Roxas2712.
local Json=require('src.link.Json')
local f=assert(io.open(assert(os.getenv('PINBALL_PRIORITY_MANIFEST'))))
local session=Json.decode(f:read('*a'));f:close()
local prefix='pinball.priority';local channels={}
for _,k in ipairs{'commands','frames','audio','events'}do channels[k]=love.thread.getChannel(prefix..'.'..k)end
local thread=love.thread.newThread('src/pinball/worker.lua')
local function command(t)channels.commands:push(Json.encode(t))end
thread:start(Json.encode{session=session,channel=prefix,seats=1,duel=true,foreground=true,diagnostics=true})
local checked={}
local function waitFor(want)
 local deadline=love.timer.getTime()+10
 while love.timer.getTime()<deadline do
  assert(not thread:getError(),thread:getError())
  local event=channels.events:pop()
  while event do local e=Json.decode(event);assert(e.event~='error',e.message);if e.event=='priority'and e.priority==want then checked[#checked+1]=want;return end;event=channels.events:pop()end
  local frame=channels.frames:pop()
  if frame then
   local priority=frame.diagnostics.priority
   for _,image in ipairs(frame.images)do image:release()end
   if priority==want then checked[#checked+1]=want;return end
  end
  local sound=channels.audio:pop();while sound do sound:release();sound=channels.audio:pop()end
  love.timer.sleep(.002)
 end
 error('Native worker did not reach expected QoS '..want)
end
local ok,why=pcall(function()
 waitFor(33) -- Darwin QOS_CLASS_USER_INTERACTIVE
 command{action='foreground',value=false};waitFor(33) -- active audio keeps its class without focus
 command{action='pause',value=true};waitFor(17) -- only actual pause relinquishes it
 command{action='pause',value=false};waitFor(33)
 command{action='pause',value=true};waitFor(17)
 command{action='foreground',value=true};command{action='pause',value=false};waitFor(33)
end)
command{action='quit'};thread:wait();assert(not thread:getError(),thread:getError())
local frame=channels.frames:pop();while frame do for _,image in ipairs(frame.images)do image:release()end;frame=channels.frames:pop()end
local sound=channels.audio:pop();while sound do sound:release();sound=channels.audio:pop()end
thread:release();assert(ok,why)
print('Actual native worker QoS focus/pause transitions passed: '..Json.encode(checked))
