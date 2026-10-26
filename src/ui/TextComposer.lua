-- System IME on mobile/love-nx, with a controller and touch fallback.
local C={}
local function native(enabled)
 if love.keyboard and love.keyboard.setTextInput then pcall(love.keyboard.setTextInput,enabled) end
end
function C.open(owner,value,done,limit)
 C.close(owner,false)
 local osName=love.system and love.system.getOS and love.system.getOS()or'Unknown'
 owner.composer={value=value or '',done=done,limit=limit or 1000,cursor=1,grid=osName~='iOS' and osName~='Android' and osName~='NX'}
 native(false);native(true)
end
function C.close(owner,commit)
 local c=owner.composer;if not c then return end
 owner.composer=nil;native(false)
 if commit then c.done(c.value)end
end
function C.text(owner,text)
 local c=owner.composer;if not c then return false end
 text=text:gsub('[%c]',' ')
 for char in text:gmatch('[%z\1-\127\194-\244][\128-\191]*')do
  local _,count=c.value:gsub('[\128-\191]','');local chars=#c.value-count
  if chars>=c.limit then break end;c.value=c.value..char
 end
 return true
end
local function keys(c)
 local out={};local chars=c.upper and 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' or 'abcdefghijklmnopqrstuvwxyz'
 for char in (chars..'0123456789.,!?@#-_/'):gmatch('.')do out[#out+1]=char end
 for _,k in ipairs({'SPACE','⌫','SHIFT','DONE','CANCEL'})do out[#out+1]=k end
 return out
end
local function choose(owner,k)
 local c=owner.composer
 if k=='DONE'then C.close(owner,true)
 elseif k=='CANCEL'then C.close(owner,false)
 elseif k=='SHIFT'then c.upper=not c.upper
 elseif k=='⌫'then c.value=c.value:gsub('[%z\1-\127\194-\244][\128-\191]*$','')
 else C.text(owner,k=='SPACE'and' 'or k)end
end
function C.key(owner,k)
 local c=owner.composer;if not c then return false end
 if k=='escape'then C.close(owner,false)
 elseif k=='return'then C.close(owner,true)
 elseif k=='backspace'then choose(owner,'⌫')
 elseif k=='v'and love.keyboard.isDown('lctrl','rctrl','lgui','rgui')then C.text(owner,love.system.getClipboardText()or'')end
 return true
end
function C.pad(owner,b)
 local c=owner.composer;if not c then return false end
 local list=keys(c);c.grid=true
 if b=='a'then choose(owner,list[c.cursor])
 elseif b=='b'then choose(owner,'⌫')
 elseif b=='start'then C.close(owner,true)
 elseif b=='back'then C.close(owner,false)
 else
  local step=({dpup=-10,dpdown=10,dpleft=-1,dpright=1})[b]
  if step then c.cursor=(c.cursor-1+step)%#list+1 end
 end
 return true
end
function C.press(owner,x,y)
 if not owner.composer then return false end
 for _,r in ipairs(owner.composer.rects or {})do if x>=r.x and x<=r.x+r.w and y>=r.y and y<=r.y+r.h then choose(owner,r.key);break end end
 return true
end
function C.draw(owner)
 local c=owner.composer;if not c then return end
 local g=love.graphics;g.push('all');g.origin();g.setScissor()
 local ww,hh=g.getDimensions();local w=math.min(780,ww-24);local x=(ww-w)/2;local h=math.min(400,hh-24);local y=math.max(12,(hh-h)/2)
 C.font=C.font or g.newFont(16);g.setFont(C.font);g.setColor(0,0,0,.7);g.rectangle('fill',0,0,ww,hh)
 g.setColor(.04,.08,.13,1);g.rectangle('fill',x,y,w,h,12,12)
 g.setScissor(x+16,y+16,w-32,64)
 g.setColor(.9,.97,1,1);g.printf(c.value..'|',x+16,y+16,w-32,'left')
 g.setScissor()
 c.rects={};local list=c.grid and keys(c)or{'DONE','CANCEL'};local cols=c.grid and 10 or 2;local keyw=(w-24)/cols;local rows=math.ceil(#list/cols);local keyh=math.min(42,(h-112)/rows)
 for i,k in ipairs(list)do
  local kx=x+12+((i-1)%cols)*keyw;local ky=y+92+math.floor((i-1)/cols)*keyh
  g.setColor(i==c.cursor and .18 or .08,i==c.cursor and .43 or .19,.29,1);g.rectangle('fill',kx,ky,keyw-3,keyh-3,4,4)
  g.setColor(.92,.98,1,1);g.printf(k,kx,ky+6,keyw-3,'center')
  c.rects[#c.rects+1]={key=k,x=kx,y=ky,w=keyw-3,h=keyh-3}
 end
 g.setColor(.62,.79,.85,1);g.printf(c.grid and 'D-pad · A selects · B deletes · Start finishes' or 'Use your system keyboard · Done keeps the draft',x+12,y+h-24,w-24,'center')
 g.pop()
end
return C
