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
print('Pinball input: guest Select/L/R, flippers, host Back and focus release passed')
