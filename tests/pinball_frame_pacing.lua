-- Native playback leases keep the real consumer at >=60 Hz, including alt-tab.
package.path='./?.lua;'..package.path
package.loaded['src.core.Performance']={backgroundPacing=true,framePacingSpin=false}
local cap=require('src.core.FrameCap');cap.spinPacing=false;cap.vsyncPacing=false
local elapsed=0;local timer={getTime=function()return elapsed end,sleep=function(dt)elapsed=elapsed+dt end}
local function nextFrame()elapsed=0;cap.pace(timer,{},false,0);return elapsed end
cap.current=30;cap.setFocus(false)
assert(math.abs(nextFrame()-.05)<.00001,'ordinary background launcher retains its 20 Hz cap')
local first,second={},{};cap.setRealtime(first,true)
assert(math.abs(nextFrame()-1/60)<.00001,'native game keeps audio/video updates at 60 Hz without focus')
cap.setRealtime(second,true);cap.setRealtime(first,false)
assert(cap.realtime()and math.abs(nextFrame()-1/60)<.00001,'another active native owner keeps the lease')
cap.setRealtime(second,false)
assert(not cap.realtime()and math.abs(nextFrame()-.05)<.00001,'closing the native game restores ordinary background pacing')
cap.setFocus(true);assert(math.abs(nextFrame()-1/30)<.00001,'ordinary foreground frame cap is preserved')
print('Pinball frame pacing: background/foreground native leases and release passed')
