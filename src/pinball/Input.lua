-- Stable seat assignment: unplugging player one never moves player two.
local bit=require('bit')
local M={};M.__index=M
local KEYS={
 {left=32,right=16,up=64,down=128,['return']=8,x=1,z=2,backspace=4,q=512,e=256},
 {a=32,d=16,w=64,s=128,tab=8,f=1,g=2,['`']=4,r=512,t=256},
}
local PAD={a=1,b=2,back=4,start=8,dpright=16,dpleft=32,dpup=64,dpdown=128,leftshoulder=32,rightshoulder=1}
function M.new(seats,pads)
 local self=setmetatable({seats=seats,pads={}},M)
 for _,p in ipairs(pads or {})do if p:isGamepad()then self:join(p)end end
 return self
end
function M:join(pad)
 if not pad:isGamepad()then return end
 for i,p in pairs(self.pads)do if p==pad then return i end end
 for i=1,self.seats do if not self.pads[i]or not self.pads[i]:isConnected()then self.pads[i]=pad;return i end end
end
function M:buttons(seat,keyboard,mouse,focused)
 if not focused then return 0 end
 local buttons=0
 for name,value in pairs(KEYS[seat])do if keyboard(name)then buttons=bit.bor(buttons,value)end end
 local pad=self.pads[seat]
 if pad and pad:isConnected()then
  for name,value in pairs(PAD)do if pad:isGamepadDown(name)then buttons=bit.bor(buttons,value)end end
  -- Left stick follows the original D-pad; flipper-left is left on default controls.
  local x,y=pad:getGamepadAxis('leftx'),pad:getGamepadAxis('lefty')
  if x<-.35 then buttons=bit.bor(buttons,32)elseif x>.35 then buttons=bit.bor(buttons,16)end
  if y<-.35 then buttons=bit.bor(buttons,64)elseif y>.35 then buttons=bit.bor(buttons,128)end
 end
 if seat==1 and mouse then
  if mouse(1)then buttons=bit.bor(buttons,32)end
  if mouse(2)then buttons=bit.bor(buttons,1)end
  if mouse(3)then buttons=bit.bor(buttons,1)end
 end
 return buttons
end
return M
