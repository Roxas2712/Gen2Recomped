-- Same-window 3DS presentation and controls. Integration by Roxas2712.
local M={};local serial=0;local live=setmetatable({},{__mode='k'})
function M.shutdown() for player in pairs(live)do player:stop()end end
local Json=require('src.link.Json')
local ABI=require('src.import.PokemonXYABI');local ffi=ABI.ffi
local layouts={'stacked','side_by_side','large_top','overlay','top_only','bottom_only'}
local stereo={'off','anaglyph','side_by_side','half_side_by_side','interlaced'}
local layoutNames={stacked='Zwei Screens ohne Spalt',side_by_side='Nebeneinander',large_top='Groß + klein',overlay='Hauptbild + Touch-Overlay',top_only='Nur Hauptbild',bottom_only='Nur Touch-Menü'}
local stereoNames={off='Aus',anaglyph='Rot/Cyan',side_by_side='Side-by-Side',half_side_by_side='Side-by-Side kompakt',interlaced='Zeilenraster'}
local function index(list,value)for i,v in ipairs(list)do if v==value then return i-1 end end return 0 end
local function key(...)return love.keyboard.isDown(...)end
local keyboardBits={x=1,z=2,backspace=4,['return']=8,right=16,left=32,up=64,down=128,w=256,q=512,s=1024,a=2048,['1']=16384,['2']=32768}
local function release(data)if data and data.release then data:release()end end
local function classify(lib,durations,stats,scale)
 local times=ffi.new('double[?]',#durations)
 for i,v in ipairs(durations)do times[i-1]=v end
 local result=ffi.new('AscendantAssessment[1]')
 assert(lib.ascendant_3ds_assess(times,#durations,stats.hardware==true,(stats.recompiled or 0)>0,scale,result),'Invalid device assessment')
 local v=result[0];local names={[0]='incomplete','unsupported_backend','startup_pass','lower_resolution','device_too_weak'}
 return {status=names[tonumber(v.status)],can_play=v.status==2,measured_fps=tonumber(v.fps),p95_ms=tonumber(v.p95_ms),resolution=scale,samples=tonumber(v.samples),scope='startup',hardware=stats.hardware,recompiled=stats.recompiled}
end
function M.new(session,mode)
 serial=serial+1
 local self={session=session,mode=mode or 'playing',images={},places={},ready=false,notice='3DS wird geladen …',paused=false,font=love.graphics.newFont(16)}
 self.settings=session.settings or {};self.settings.layout=self.settings.layout or 'stacked';self.settings.stereo=self.settings.stereo or 'off'
 self.settings.overlay_position=self.settings.overlay_position or 'right'
 self.settings.overlay_size=self.settings.overlay_size or 32
 self.settings.overlay_x=self.settings.overlay_x or 98;self.settings.overlay_y=self.settings.overlay_y or 98
 if self.settings.hide_empty_touch==nil then self.settings.hide_empty_touch=true end
 self.lib=ABI.load(session.bridge);self.channel='ascendant.xy.'..serial..'.'..tostring(love.timer.getTime())
 for _,kind in ipairs{'events','frames','commands','audio','recycle'}do self[kind]=love.thread.getChannel(self.channel..'.'..kind);self[kind]:clear()end
 self.thread=love.thread.newThread('src/import/pokemon_xy_native_worker.lua')
 self.thread:start(Json.encode{session=session,channel=self.channel,mode=self.mode})
 if self.mode=='playing' then
  local ok,source=pcall(love.audio.newQueueableSource,32728,16,2,16)
  if ok then self.sound=source;source:setVolume(session.volume or .7) end
 end
 function self:command(message)if self.thread:isRunning()then self.commands:push(Json.encode(message))end end
 function self:stop()self.closing=true;self:command{action='quit'};if self.sound then self.sound:stop()end end
 function self:dispose()
  if self.disposed then return end;self.disposed=true;live[self]=nil
  for _,img in pairs(self.images)do release(img)end;self.images={}
  local f=self.frames:pop();if f then for _,data in pairs(f.images)do release(data)end end
  while self.audio:getCount()>0 do release(self.audio:pop())end
  local returned=self.recycle:pop();while returned do release(returned.data);returned=self.recycle:pop()end
  if self.keyboardForm then love.keyboard.setTextInput(false)end
  release(self.sound);self.sound=nil;release(self.shader);self.shader=nil;release(self.font);self.font=nil
 end
 function self:layout(w,h)
  local places=ffi.new('AscendantPlace[4]')
  local arrangement=self.settings.layout
  local hidden=arrangement~='bottom_only'and self.settings.hide_empty_touch and self.blankBottom
  if hidden then arrangement='top_only'
  elseif arrangement=='overlay'and self.settings.overlay_position~='free'then arrangement='large_top'end
  local count=tonumber(self.lib.ascendant_3ds_layout(w,h,index(layouts,arrangement),index(stereo,self.settings.stereo),self.settings.swap_eyes==true,self.images[3]~=nil,places,4))
  self.places={}
  for i=0,count-1 do
   local p=places[i];local v={x=p.x,y=p.y,w=p.width,h=p.height,screen=tonumber(p.screen)}
   if self.settings.layout=='overlay'and not hidden then
    if self.settings.overlay_position=='left'then v.x=w-v.x-v.w
    elseif self.settings.overlay_position=='free'and v.screen==1 then
     v.w=math.min(w*(self.settings.overlay_size or 32)/100,h*4/3);v.h=v.w*3/4
     v.x=(w-v.w)*(self.settings.overlay_x or 98)/100;v.y=(h-v.h)*(self.settings.overlay_y or 98)/100
    end
   end
   self.places[#self.places+1]=v
  end
  if self.settings.display_mode and self.settings.display_mode~='fit'and #self.places>0 then
   local left,top,right,bottom=w,h,0,0
   for _,p in ipairs(self.places)do left=math.min(left,p.x);top=math.min(top,p.y);right=math.max(right,p.x+p.w);bottom=math.max(bottom,p.y+p.h)end
   local sx,sy=w/math.max(1,right-left),h/math.max(1,bottom-top)
   if self.settings.display_mode=='crop'then sx=math.max(sx,sy);sy=sx end
   local ox,oy=(w-(right-left)*sx)/2,(h-(bottom-top)*sy)/2
   for _,p in ipairs(self.places)do p.x=ox+(p.x-left)*sx;p.y=oy+(p.y-top)*sy;p.w=p.w*sx;p.h=p.h*sy end
  end
 end
 function self:input(dt)
  if not love.window.hasFocus() then self:command{action='clearKeys'};self:command{action='input',buttons=0,cx=0,cy=0,tx=-1,ty=-1};return end
  local bits=0
  local cx=(key('l')and 1 or 0)-(key('j')and 1 or 0);local cy=(key('i')and 1 or 0)-(key('k')and 1 or 0)
  local pad=love.joystick and love.joystick.getJoysticks()[1]
  if self.suppressPadUntilRelease then
   local held=false
   if pad and pad:isGamepad()then for _,b in ipairs{'a','b','x','y','start','back','dpup','dpdown','dpleft','dpright','leftshoulder','rightshoulder','rightstick'}do if pad:isGamepadDown(b)then held=true;break end end end
   if held then self:command{action='input',buttons=0,cx=0,cy=0,tx=-1,ty=-1};return end
   self.suppressPadUntilRelease=nil
  end
  if pad and pad:isGamepad() then
   local bit=require('bit')
   if self.suppressedPad and not pad:isGamepadDown(self.suppressedPad)then self.suppressedPad=nil end
   for _,b in ipairs{{'a',1},{'b',2},{'back',4},{'start',8},{'dpright',16},{'dpleft',32},{'dpup',64},{'dpdown',128},{'rightshoulder',256},{'leftshoulder',512},{'x',1024},{'y',2048}}do if b[1]~=self.suppressedPad and pad:isGamepadDown(b[1])then bits=bit.bor(bits,b[2])end end
   local ax,ay=pad:getGamepadAxis('leftx'),-pad:getGamepadAxis('lefty');if math.abs(ax)>.15 then cx=ax end;if math.abs(ay)>.15 then cy=ay end
   if pad:getGamepadAxis('triggerleft')>.5 then bits=bit.bor(bits,16384)end
   if pad:getGamepadAxis('triggerright')>.5 then bits=bit.bor(bits,32768)end
   local rx,ry=pad:getGamepadAxis('rightx'),pad:getGamepadAxis('righty')
   if math.abs(rx)>.18 or math.abs(ry)>.18 or pad:isGamepadDown('rightstick')then
    self.touchCursor=self.touchCursor or {x=160,y=120};local step=math.min(dt or 1/60,.1)*240
    if math.abs(rx)>.18 then self.touchCursor.x=math.max(0,math.min(319,self.touchCursor.x+rx*step))end
    if math.abs(ry)>.18 then self.touchCursor.y=math.max(0,math.min(239,self.touchCursor.y+ry*step))end
   end
  end
  local tx,ty=-1,-1
  if self.drag then
   if love.mouse.isDown(self.drag.button)then
    local mx,my=love.mouse.getPosition();local w,h=love.graphics.getDimensions()
    self.settings.overlay_x=math.floor(math.max(0,math.min(100,(mx-self.drag.dx)/math.max(1,w-self.drag.w)*100))+.5)
    self.settings.overlay_y=math.floor(math.max(0,math.min(100,(my-self.drag.dy)/math.max(1,h-self.drag.h)*100))+.5)
   else self.drag=nil end
  elseif love.mouse.isDown(1)and not key('lalt','ralt')then
   local mx,my=love.mouse.getPosition()
   for _,p in ipairs(self.places)do if p.screen==1 and mx>=p.x and my>=p.y and mx<p.x+p.w and my<p.y+p.h then tx=math.floor((mx-p.x)/p.w*320);ty=math.floor((my-p.y)/p.h*240)end end
  end
  if pad and pad:isGamepad()and pad:isGamepadDown('rightstick')and self.touchCursor then tx=math.floor(self.touchCursor.x);ty=math.floor(self.touchCursor.y)end
  self:command{action='input',buttons=bits,cx=cx,cy=cy,tx=tx,ty=ty}
 end
 function self:update(dt)
  local event=self.events:pop()
  while event do
   local message=Json.decode(event)
   if message.event=='ready'then self.ready=true;self.notice=nil;self.stats=message.stats end
   if message.event=='closed'then self.closed=true end
   if message.event=='error'then self.error=message.message;self.closed=true end
   if message.event=='notice'then self.notice=message.message end
   if message.event=='keyboard'then
    if not message.request and self.keyboardForm then self.suppressPadUntilRelease=true end
    self.keyboardForm=message.request and require('src.import.PokemonXYKeyboard').new(message.request,function(text,button)self:command{action='keyboard',text=text,button=button}end)or nil
    love.keyboard.setTextInput(self.keyboardForm~=nil);self:command{action='clearKeys'}
   end
   if message.event=='benchmark'then self.result=classify(self.lib,message.durations,message.stats,self.session.resolution);self.closed=true end
   event=self.events:pop()
  end
  if self.thread:getError()then self.error=self.thread:getError();self.closed=true end
  local frame=self.frames:pop()
  if frame then
   local uploadStart=love.timer.getTime()
   if not frame.right then release(self.images[3]);self.images[3]=nil end
   for i,data in pairs(frame.images)do
    local image=self.images[i]
    if image and (image:getWidth()~=data:getWidth() or image:getHeight()~=data:getHeight())then release(image);image=nil end
    if image then image:replacePixels(data)else image=love.graphics.newImage(data);self.images[i]=image end
    image:setFilter(self.settings.filter=='pixels' and 'nearest' or 'linear',self.settings.filter=='pixels' and 'nearest' or 'linear')
    self.recycle:push{data=data,index=i,revision=frame.revisions[i]}
   end
   self.uploadMs=(love.timer.getTime()-uploadStart)*1000
   self.stats=frame.stats or self.stats;self.copyMs=frame.copy_ms;self.blankMs=frame.blank_ms
   self.blankBottom=frame.blank_bottom;self.frame=frame.frame;self.frameSeconds=frame.seconds
  end
  while self.audio:getCount()>0 do
   local sound=self.audio:pop()
   if self.sound and not self.paused and self.sound:getFreeBufferCount()>0 then self.sound:queue(sound);if not self.sound:isPlaying()then self.sound:play()end end
   sound:release()
  end
  if self.mode=='playing' and self.ready and not self.paused and not self.closing and not self.keyboardForm then self:input(dt)end
  if self.closing and not self.thread:isRunning()then self.closed=true end
 end
 local shaderText=[[
 extern Image rightEye;
 extern number mode;
 extern number swapEyes;
 extern number sharp;
 extern vec2 imageSize;
 vec4 effect(vec4 color,Image tex,vec2 uv,vec2 pixel){
  if(sharp>0.5){
   vec2 p=uv*imageSize;vec2 span=max(fwidth(p),vec2(0.00001));
   uv=(floor(p)+0.5+clamp((fract(p)-0.5)/span,-0.5,0.5))/imageSize;
  }
  vec4 a=Texel(tex,uv);
  if(mode<0.5)return a*color;
  vec4 b=Texel(rightEye,uv);
  if(swapEyes>0.5){vec4 t=a;a=b;b=t;}
  if(mode<1.5)return vec4(a.r,b.g,b.b,1.0)*color;
  return (mod(floor(pixel.y),2.0)<1.0?a:b)*color;
 }
 ]]
 function self:draw(w,h,preview)
  local g=love.graphics;g.push('all');g.setFont(self.font);g.setColor(.015,.022,.035);g.rectangle('fill',0,0,w,h)
  self:layout(w,h)
  for _,p in ipairs(self.places)do
   local image=self.images[p.screen==3 and 1 or p.screen+1] or self.images[1]
   if image and not (p.screen==1 and self.settings.layout=='overlay' and self.settings.hide_empty_touch and self.blankBottom) then
    self.shader=self.shader or g.newShader(shaderText)
    self.shader:send('rightEye',self.images[3] or image)
    self.shader:send('mode',p.screen==3 and (self.settings.stereo=='anaglyph' and 1 or 2) or 0)
    self.shader:send('swapEyes',self.settings.swap_eyes and 1 or 0)
    self.shader:send('sharp',self.settings.filter=='sharp' and 1 or 0)
    self.shader:send('imageSize',{image:getWidth(),image:getHeight()});g.setShader(self.shader)
    g.setColor(1,1,1);g.draw(image,p.x,p.y,0,p.w/image:getWidth(),p.h/image:getHeight());g.setShader()
   end
  end
  if not preview then
   if not self.ready then g.setColor(1,1,1);g.printf(self.notice or 'Laden …',0,h/2,w,'center')end
   if self.settings.show_fps and self.frameSeconds then
    g.setColor(1,1,1);g.print(string.format('Emulation %.1f ms · Readback %.1f ms · Kopie %.1f ms · Upload %.1f ms',self.stats and self.stats.emulation_ms or 0,self.stats and self.stats.readback_ms or 0,self.copyMs or 0,self.uploadMs or 0),12,10)
   end
   if self.touchCursor and not self.paused then
    for _,p in ipairs(self.places)do if p.screen==1 then
     local xx,yy=p.x+self.touchCursor.x/320*p.w,p.y+self.touchCursor.y/240*p.h
     g.setColor(0,0,0,.9);g.setLineWidth(4);g.circle('line',xx,yy,7)
     g.setColor(.4,.9,1);g.setLineWidth(2);g.circle('line',xx,yy,7);g.line(xx-11,yy,xx+11,yy);g.line(xx,yy-11,xx,yy+11)
    end end
   end
   if self.keyboardForm then self.keyboardForm:draw(w,h)elseif self.paused then self:drawMenu(w,h)end
  end
  g.pop()
 end
 function self:keyreleased(key)
  if keyboardBits[key]then self:command{action='button',bit=keyboardBits[key],pressed=false}end
 end
 function self:textinput(text)if self.keyboardForm then self.keyboardForm:append(text)end end
 function self:keypressed(key)
  if self.keyboardForm then self.keyboardForm:keypressed(key);return end
  if keyboardBits[key] and not self.paused then self:command{action='button',bit=keyboardBits[key],pressed=true}end
  if key=='escape'then self.paused=not self.paused;self.menuSelection=1;self.drag=nil;self:command{action='pause',paused=self.paused};if self.sound then self.sound:stop()end;return end
  if key=='f6' then self.settings.layout=self.settings.layout=='overlay'and'top_only'or'overlay'
  elseif key=='f7' then self.settings.layout=self.settings.layout=='stacked'and'top_only'or'stacked'
  elseif key=='f9' then self.settings.layout=layouts[(index(layouts,self.settings.layout)+1)%#layouts+1]
  elseif key=='f10' then self.settings.layout=self.settings.layout=='bottom_only'and'top_only'or'bottom_only'
  elseif key=='f11'then love.window.setFullscreen(not love.window.getFullscreen())
  elseif key=='f5'or key=='f8'then self:command{action='state',path=self.session.data..'/states/'..self.session.edition..'/quick.state',load=key=='f8'} end
 end
 function self:drawMenu(w,h)
  local g=love.graphics;g.setColor(.015,.022,.035,.92);g.rectangle('fill',0,0,w,h)
  local scale=math.min(w/800,h/900);local bw=math.min(510*scale,w-40);local x=(w-bw)/2;local y=math.max(12,(h-860*scale)/2)
  self.menu={};g.setColor(1,1,1);g.printf('Pokémon '..self.session.edition:upper()..' · Recompiled Ascendant · '..tostring(self.session.resolution)..'×',x,y,bw,'center');y=y+42*scale
  local rows={
   {'WEITERSPIELEN',function()self:keypressed('escape')end},
   {'BILDSCHIRME: '..(layoutNames[self.settings.layout] or self.settings.layout),function()self:keypressed('f9')end},
   {'FENSTERNUTZUNG: '..({fit='Originalverhältnis',crop='Randlos · Zuschnitt',stretch='Fenster füllen · Strecken'})[self.settings.display_mode or 'fit'],function()local modes={'fit','crop','stretch'};self.settings.display_mode=modes[(index(modes,self.settings.display_mode or 'fit')+1)%#modes+1]end},
   {'TOUCH-POSITION: '..({right='Rechts daneben',left='Links daneben',free='Frei verschiebbar'})[self.settings.overlay_position],function()local positions={'right','left','free'};self.settings.overlay_position=positions[(index(positions,self.settings.overlay_position)+1)%#positions+1];self.settings.layout='overlay'end},
   {'OVERLAY-GRÖSSE: '..self.settings.overlay_size..' %',function()self.settings.overlay_size=self.settings.overlay_size>=60 and 20 or math.min(60,self.settings.overlay_size+5);self.settings.overlay_position='free';self.settings.layout='overlay'end},
   {'LEERES TOUCH-BILD: '..(self.settings.hide_empty_touch and 'Ausblenden' or 'Anzeigen'),function()self.settings.hide_empty_touch=not self.settings.hide_empty_touch end},
   {'STEREO-3D: '..(stereoNames[self.settings.stereo] or self.settings.stereo),function()self.settings.stereo=stereo[(index(stereo,self.settings.stereo)+1)%#stereo+1];self:command{action='slider',value=self.settings.stereo=='off'and 0 or(self.settings.depth_3d or 50)/100}end},
   {'3D-TIEFE: '..tostring(self.settings.depth_3d or 50)..' %',function()self.settings.depth_3d=((self.settings.depth_3d or 50)+25)%125;self:command{action='slider',value=self.settings.stereo=='off'and 0 or self.settings.depth_3d/100}end},
   {self.muted and 'TON EINSCHALTEN' or 'TON AUSSCHALTEN',function()self.muted=not self.muted;if self.sound then self.sound:setVolume(self.muted and 0 or(self.session.volume or .7))end end},
   {'SCHNELL SPEICHERN · F5',function()self:keypressed('f5')end},
   {'SCHNELL LADEN · F8',function()self:keypressed('f8')end},
   {'SPRACHAUSWAHL ZURÜCKSETZEN',function()self:command{action='reset-language'}end},
   {'ZUR BIBLIOTHEK',function()self:stop()end},
  }
  for i,row in ipairs(rows)do
   local rect={x=x,y=y,w=bw,h=42*scale,action=row[2]};self.menu[#self.menu+1]=rect
   if self.menuSelection==i then g.setColor(.19,.32,.40)else g.setColor(.12,.19,.25)end;g.rectangle('fill',x,y,bw,rect.h,7,7);g.setColor(.5,.8,.9);g.rectangle('line',x,y,bw,rect.h,7,7);g.setColor(1,1,1);g.printf(row[1],x,y+12*scale,bw,'center');y=y+50*scale
  end
  g.setColor(.65,.78,.84);g.printf('X=A · Z=B · Pfeile=D-Pad · IJKL=Circle Pad\nTouch verschieben: Rechts ziehen oder Alt + Ziehen\nController: L3 Menü · rechter Stick Touch · R3 tippen',x,y+8,bw,'center')
  if self.notice then g.setColor(1,.85,.5);g.printf(self.notice,x,y+76,bw,'center')end
 end
 function self:gamepadpressed(_,button)
  if self.keyboardForm then self.keyboardForm:gamepadpressed(button);return end
  if button=='guide'or button=='leftstick'then self:keypressed('escape');return end
  if not self.paused then return end
  if button=='b'then self:keypressed('escape');self.suppressedPad='b';return end
  local count=#(self.menu or {});if count==0 then return end
  self.menuSelection=self.menuSelection or 1
  if button=='dpdown'then self.menuSelection=self.menuSelection%count+1
  elseif button=='dpup'then self.menuSelection=(self.menuSelection-2)%count+1
  elseif button=='a'then self.menu[self.menuSelection].action();if not self.paused then self.suppressedPad='a'end end
 end
 function self:mousepressed(x,y,button)
  if self.keyboardForm then self.keyboardForm:mousepressed(x,y);return end
  if not self.paused and self.settings.layout=='overlay'and(button==2 or(button==1 and key('lalt','ralt')))then
   for _,p in ipairs(self.places)do
    if p.screen==1 and x>=p.x and y>=p.y and x<p.x+p.w and y<p.y+p.h then
     local w,h=love.graphics.getDimensions();self.settings.overlay_position='free'
     self.settings.overlay_size=math.max(15,math.min(60,math.floor(p.w/w*100+.5)))
     self.settings.overlay_x=math.floor(p.x/math.max(1,w-p.w)*100+.5);self.settings.overlay_y=math.floor(p.y/math.max(1,h-p.h)*100+.5)
     self.drag={button=button,dx=x-p.x,dy=y-p.y,w=p.w,h=p.h};return
    end
   end
  end
  if self.paused then for _,r in ipairs(self.menu or {})do if x>=r.x and y>=r.y and x<=r.x+r.w and y<=r.y+r.h then r.action();return end end end
 end
 live[self]=true
 return self
end
return M
