-- Actual bridge viewport placement + synthetic standardized SDL controller.
package.path='./?.lua;'..package.path
love=require('tests.love_stub')
local checks=0;local function check(v,m)assert(v,m);checks=checks+1 end
local messages={};local channels={}
love.thread={getChannel=function(name)
 channels[name]=channels[name]or {clear=function()end,push=function(_,v)messages[#messages+1]=v end,pop=function()end,getCount=function()return 0 end};return channels[name]
end,newThread=function()return {start=function()end,isRunning=function()return true end}end}
love.timer={getTime=function()return 0 end};love.window.hasFocus=function()return true end
love.graphics.getDimensions=function()return 1200,800 end
local keys={};love.keyboard.isDown=function(...)for i=1,select('#',...)do if keys[select(i,...)]then return true end end return false end
local mouse={};love.mouse.isDown=function(button)return mouse[button]end;love.mouse.getPosition=function()return mouse.x or 0,mouse.y or 0 end
local pressed={};local axes={}
local pad={isGamepad=function()return true end,isGamepadDown=function(_,button)return pressed[button]or false end,getGamepadAxis=function(_,axis)return axes[axis]or 0 end}
love.joystick={getJoysticks=function()return {pad}end}
local P=require('src.import.PokemonXYNative').new({bridge=assert(os.getenv('POKEMON_XY_BRIDGE')),edition='y',data='/qa',resolution=3,settings={layout='overlay',overlay_position='right',hide_empty_touch=false}},'preview')
P:layout(1200,800);local top,bottom=P.places[1],P.places[2]
check(top.x+top.w<=bottom.x+.01,'right dock cannot cover the game image')
P.settings.overlay_position='left';P:layout(1200,800);top,bottom=P.places[1],P.places[2]
check(bottom.x+bottom.w<=top.x+.01,'left dock cannot cover the game image')
P.settings.overlay_position='free';P.settings.overlay_size=25;P.settings.overlay_x=0;P.settings.overlay_y=100;P:layout(1200,800);bottom=P.places[2]
check(bottom.x==0 and math.abs(bottom.y+bottom.h-800)<.01,'free placement remains inside window corners')
P.blankBottom=true;P.settings.hide_empty_touch=true;P.settings.layout='stacked';P:layout(1200,800)
check(#P.places==1 and P.places[1].w>1000,'blank lower screen releases reserved space even in classic dual view')
P.settings.display_mode='stretch';P:layout(1200,800)
check(P.places[1].w==1200 and P.places[1].h==800,'optional stretch fills the complete window')
P.settings.display_mode='crop';P:layout(1200,800)
check(P.places[1].w>=1200 and P.places[1].h>=800 and math.abs(P.places[1].w/P.places[1].h-5/3)<.001,'crop fills without changing the main screen aspect')
pressed.a=true;pressed.rightshoulder=true;pressed.rightstick=true;axes.leftx=.75;axes.rightx=1;axes.triggerleft=.8
P:input(.1)
local Json=require('src.link.Json');local input=Json.decode(messages[#messages]);local bit=require('bit')
check(bit.band(input.buttons,1+256+16384)==1+256+16384 and input.cx==.75,'controller face, shoulder, trigger and circle pad reach native HID')
check(input.tx>160 and input.ty==120,'right stick positions touch pointer and R3 touches')
P.suppressPadUntilRelease=true;P:input(.1);input=Json.decode(messages[#messages])
check(input.buttons==0 and input.tx==-1,'held controller input cannot leak out of a closed keyboard applet')
pressed={};P:input(.1);check(not P.suppressPadUntilRelease,'controller resumes after all applet buttons are released')
P.paused=true;P.menuSelection=1;local selected=0
P.menu={{action=function()selected=1 end},{action=function()selected=2 end}}
P:gamepadpressed(pad,'dpdown');P:gamepadpressed(pad,'a')
check(selected==2,'controller can choose menu actions without a mouse')
P:gamepadpressed(pad,'b');check(not P.paused,'controller B returns to the game')
P:gamepadpressed(pad,'leftstick');check(P.paused,'L3 opens the recompiler menu without consuming Start/Select')
print('3DS controller and layout: '..checks..' checks passed')
