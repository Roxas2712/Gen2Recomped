-- All guest controls remain available alongside the host pause menu.
-- Contributions by Roxas2712.
package.path='./?.lua;'..package.path
local bit=require('bit');local Input=require('src.pinball.Input')
local pressed,axes={},{}
local pad={isGamepad=function()return true end,isConnected=function()return true end,
 isGamepadDown=function(_,key)return pressed[key]end,getGamepadAxis=function(_,key)return axes[key]or 0 end}
local input=Input.new(1,{pad});local no=function()return false end
pressed.leftstick=true;assert(input:buttons(1,no,nil,true)==4)
pressed={};axes.triggerleft=1;axes.triggerright=1;assert(input:buttons(1,no,nil,true)==768)
axes={};pressed.leftshoulder=true;pressed.rightshoulder=true;assert(input:buttons(1,no,nil,true)==33)
pressed={};pressed.back=true;assert(input:buttons(1,no,nil,true)==0,'host Back must not accidentally press guest Select')
assert(input:buttons(1,function(k)return k=='q'or k=='e'or k=='backspace'end,nil,true)==772)
assert(input:buttons(1,function()return true end,nil,false)==0,'unfocused guest releases every button')
assert(input:buttons(1,no,function(b)return b==3 end,true)==1,'GBA mouse launch is A')
local gbc=Input.new(1,{pad})
assert(gbc:buttons(1,no,function(b)return b==3 end,true)==1,'GBC mouse launch is A')
local vibration
pad.setVibration=function(_,left,right,duration)vibration={left,right,duration}end
gbc:rumble(1,true);assert(vibration[1]>.0 and vibration[3]<=.1,'Motor pulses are bounded')
gbc:stopRumble();assert(vibration[1]==0 and vibration[2]==0,'Shutdown releases the motor')
print('Pinball input: guest Select/L/R, flippers, host Back and focus release passed')

local Layout=require('src.pinball.ViewLayout')
for _,guest in ipairs{'gbc','gba'}do
 local w,h=guest=='gbc'and 192 or 256,guest=='gbc'and 285 or 388
 local nw,nh=guest=='gbc'and 160 or 240,guest=='gbc'and 144 or 160
 local expanded=Layout.fit(w,h,600,740,guest,true,false,false)
 local overlay=Layout.fit(nw,nh,600,740,guest,true,true,false)
 local bonus=Layout.fit(nw,nh,600,740,guest,false,true,false)
 assert(expanded==overlay and overlay==bonus,'Full-table overlays must keep their native pixel scale without zooming')
 assert(Layout.fit(nw,nh,600,740,guest,false,false,false)>overlay,'Original view still fills its own pane')
end
print('GBC/GBA fixed full-table framing: menu, bonus and original-view transitions retain scale')
