-- In-game 3DS applet UI; keyboard/controller input never reaches the game.
-- Integration by Roxas2712. Native validation remains authoritative.
local K={};local utf8=require('utf8')
function K.new(request,answer)
 local self={request=request,value=request.text or '',selection=1,lower=false,buttons={}}
 local keys={};for c in ('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'):gmatch('.')do keys[#keys+1]=c end
 for _,c in ipairs{'LEER','⌫','a/A','OK','ABBRUCH'}do keys[#keys+1]=c end
 function self:submit(button)answer(self.value,button)end
 function self:append(text)
  local joined=self.value..text
  if utf8.len(joined)and utf8.len(joined)<=(self.request.max_length or 64)then self.value=joined end
 end
 function self:erase()local offset=utf8.offset(self.value,-1);if offset then self.value=self.value:sub(1,offset-1)end end
 function self:activate()
  local item=keys[self.selection]
  if item=='OK'then self:submit(#self.request.buttons-1)
  elseif item=='ABBRUCH'then if #self.request.buttons>1 then self:submit(0)end
  elseif item=='⌫'then self:erase()
  elseif item=='a/A'then self.lower=not self.lower
  elseif item=='LEER'then self:append(' ')
  elseif item then self:append(self.lower and item:lower()or item)end
 end
 function self:keypressed(key)
  if key=='return'then self:submit(#self.request.buttons-1)
  elseif key=='escape'then if #self.request.buttons>1 then self:submit(0)end
  elseif key=='backspace'then self:erase()end
 end
 function self:gamepadpressed(button)
  if button=='dpup'then self.selection=(self.selection-11)%#keys+1
  elseif button=='dpdown'then self.selection=(self.selection+9)%#keys+1
  elseif button=='dpleft'then self.selection=(self.selection-2)%#keys+1
  elseif button=='dpright'then self.selection=self.selection%#keys+1
  elseif button=='a'then self:activate()
  elseif button=='b'then self:erase()
  elseif button=='x'then self.lower=not self.lower
  elseif button=='start'then self:keypressed('return')end
 end
 function self:draw(w,h)
  local g=love.graphics;g.setColor(.015,.022,.035,.96);g.rectangle('fill',0,0,w,h)
  local width=math.min(w-32,760);local x=(w-width)/2;local y=math.max(20,(h-420)/2)
  g.setColor(1,1,1);g.printf(self.request.hint or 'Texteingabe',x,y,width,'center');y=y+40
  g.setColor(.12,.19,.25);g.rectangle('fill',x,y,width,46,8,8);g.setColor(1,1,1);g.printf(self.value..'▏',x+10,y+12,width-20,'left');y=y+66
  local cw=width/10;self.buttons={}
  for i,item in ipairs(keys)do
   local bx,by=x+((i-1)%10)*cw,y+math.floor((i-1)/10)*48
   self.buttons[i]={x=bx,y=by,w=cw-4,h=42}
   if i==self.selection then g.setColor(.2,.38,.48)else g.setColor(.12,.19,.25)end
   g.rectangle('fill',bx,by,cw-4,42,6,6);g.setColor(1,1,1)
   g.printf(self.lower and #item==1 and item:lower()or item,bx,by+12,cw-4,'center')
  end
  g.setColor(.65,.78,.84);g.printf('Tastatur oder Controller · A wählen · B löschen · X Groß/klein · Start bestätigen',x,y+260,width,'center')
 end
 function self:mousepressed(x,y)
  for i,p in ipairs(self.buttons)do if x>=p.x and y>=p.y and x<p.x+p.w and y<p.y+p.h then self.selection=i;self:activate();return end end
 end
 return self
end
return K
