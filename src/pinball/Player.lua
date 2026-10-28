-- Shared-window Pinball player. Contributions by Roxas2712.
local M={};local live=setmetatable({},{__mode='k'});local serial=0
local Json=require('src.link.Json')
local FrameCap=require('src.core.FrameCap')
-- Six completed guest frames cover short interpreter/scheduler spikes without
-- changing the cartridge clock or stretching samples (about 100 ms at 60 Hz).
local AUDIO_BUFFERS,AUDIO_PREROLL=16,6
local FILTERS={'pixels','smooth','lcd','scanlines'}
local DISPLAY_SHADER=[[
extern vec2 sourceSize;
extern number displayMode;
vec4 effect(vec4 color, Image image, vec2 uv, vec2 screen) {
 vec4 pixel=Texel(image,uv)*color;
 vec2 grid=fract(uv*sourceSize);
 if(displayMode<1.5){
  float edge=smoothstep(0.0,0.1,min(min(grid.x,1.0-grid.x),min(grid.y,1.0-grid.y)));
  pixel.rgb=pow(clamp(pixel.rgb,0.0,1.0),vec3(0.92))*(0.88+0.12*edge);
 }else{pixel.rgb*=0.87+0.13*cos(6.2831853*grid.y);}
 return pixel;
}
]]
local function free(v)if v and v.release then v:release()end end
function M.shutdown()for p in pairs(live)do p:stop();p.thread:wait();p:dispose()end end
function M.new(session,options)
 options=options or {};serial=serial+1
 local self={session=session,options=options,seats=options.seats==2 and 2 or 1,images={},stats={},notice='Pinball wird geladen …',
  settings={filter='pixels',integer=false,audioSeat=1,full_table=false,opponentView=true},font=love.graphics.newFont(16),small=love.graphics.newFont(12)}
 local saved=love.filesystem.read('pinball-display.json')
 if saved then local ok,v=pcall(Json.decode,saved);if ok and type(v)=='table'then for _,k in ipairs{'filter','integer','audioSeat','full_table','opponentView'}do if v[k]~=nil then self.settings[k]=v[k]end end end end
 self.input=require('src.pinball.Input').new(self.seats,love.joystick.getJoysticks())
 self.channel='ascendant.pinball.'..serial..'.'..love.timer.getTime()
 for _,k in ipairs{'commands','frames','audio','events'}do self[k]=love.thread.getChannel(self.channel..'.'..k);self[k]:clear()end
 self.audioRate=32768;self.sound=love.audio.newQueueableSource(self.audioRate,16,1,AUDIO_BUFFERS);self.sound:setVolume(session.volume or .6)
 local ok,shader=pcall(love.graphics.newShader,DISPLAY_SHADER);if ok then self.shader=shader end
 self.thread=love.thread.newThread('src/pinball/worker.lua')
 if options.net then
  self.duel=require('src.pinball.Duel').new(options.net,options.host,{rom=session.rom_sha1,backend=session.backend,
   content=session.content,field=options.field or 0,frames=18000,seed=0},{view=true})
 end
 self.thread:start(Json.encode{session=session,channel=self.channel,seats=self.seats,duel=options.duel,
  field=options.field or 0,frameLimit=18000,broadcastView=options.net~=nil,full_table=self.settings.full_table,audioSeat=self.settings.audioSeat,diagnostics=options.diagnostics,foreground=love.window.hasFocus()})
 function self:command(msg)if self.thread:isRunning()then self.commands:push(Json.encode(msg))end end
 function self:stop()if self.closing then return end;self.closing=true;FrameCap.setRealtime(self,false);if self.activity then self.activity:release()end;if self.liveView then self.liveView:stop()end;if self.duel then self.duel:close()end;self:command{action='quit'};self.sound:stop()end
 function self:dispose()
  if self.disposed then return end;self.disposed=true
  FrameCap.setRealtime(self,false);live[self]=nil
  if self.activity then self.activity:release()end
  if self.liveView then self.liveView:dispose();self.liveView=nil end
  local previews=love.thread.getChannel(self.channel..'.previewSource')
  local preview=previews:pop();while preview do free(preview.image);preview=previews:pop()end
  for _,image in pairs(self.images)do free(image)end
  local msg=self.frames:pop();while msg do for _,data in ipairs(msg.images)do free(data)end;msg=self.frames:pop()end
  local sound=self.audio:pop();while sound do free(sound);sound=self.audio:pop()end
  free(self.sound);free(self.font);free(self.small);free(self.shader)
 end
 function self:update(dt)
  local focused=love.window.hasFocus()
  if self.lastForeground~=focused then self.lastForeground=focused;self:command{action='foreground',value=focused}end
  local event=self.events:pop()
  while event do
   local msg=Json.decode(event)
   if msg.event=='ready'then self.ready=true;self.notice=''
   elseif msg.event=='error'then self.error=msg.message;self.closed=true
   elseif msg.event=='prepared'then
    self.checkpoint=msg.checkpoints[1]
    if self.seats==2 and self.checkpoint~=msg.checkpoints[2]then self.error='Die Startzustände unterscheiden sich.';self:stop()
    elseif not self.duel then self.countdown=3 end
   elseif msg.event=='closed'then self.closed=true
   elseif msg.event=='notice'then self.notice=msg.message end
   event=self.events:pop()
  end
  local err=self.thread:getError();if err then self.error=err;self.closed=true end
  local msg
  if self.videoStarted or self.frames:getCount()>=2 then self.videoStarted=true;msg=self.frames:pop()end
  if msg then
   for i,data in ipairs(msg.images)do
    local image=self.images[i]
    if image and image:getWidth()==data:getWidth() and image:getHeight()==data:getHeight()then image:replacePixels(data)
    else free(image);image=love.graphics.newImage(data);self.images[i]=image end
    image:setFilter(self.settings.filter=='smooth' and 'linear'or 'nearest');data:release()
   end
   self.stats=msg.stats;self.frame=msg.frame;self.frameMs=msg.seconds*1000;self.phase=msg.phase;self.diagnostics=msg.diagnostics
   if self.phase~=self.audioPhase then
    self.audioPhase=self.phase
    if self.phase=='waiting'or self.phase=='finished'then
     self.sound:stop();self.audio:clear();self.audioStarted=false
    end
   end
   if self.seats==2 and self.phase=='finished'then
    self.result=self.stats[1].score==self.stats[2].score and 'Unentschieden' or self.stats[1].score>self.stats[2].score and 'Spieler 1 gewinnt' or 'Spieler 2 gewinnt'
   end
  end
  if self.duel then
   self.duel:update(dt)
   if self.duel.viewEnabled and not self.liveView then self.liveView=require('src.pinball.LiveView').new(self.channel)end
   if self.liveView then
    local picture=self.duel:pollPicture();if picture and self.settings.opponentView then self.liveView:receive(picture)end
    local data,packet=self.liveView:update()
    if packet then self.duel:picture(packet)end
    if data then
     local image=self.images[2]
     if image and image:getWidth()==data:getWidth()and image:getHeight()==data:getHeight()then image:replacePixels(data)
     else free(image);image=love.graphics.newImage(data);self.images[2]=image end
     image:setFilter(self.settings.filter=='smooth'and'linear'or'nearest');data:release()
    end
    if self.liveView.error then self.viewFailed=self.liveView.error end
   end
   if self.viewFailed then free(self.images[2]);self.images[2]=nil;self.notice='Live-Ansicht nicht verfügbar · dein Punkteduell läuft weiter.'end
   if self.checkpoint and self.duel.state=='lobby' and not self.duel.localReady then self.duel:ready(self.checkpoint)end
   if self.duel.started and not self.duelStarted then self.duelStarted=true;self.countdown=3 end
   local st=self.stats[1]
   if st and self.duel.state=='playing' and (st.elapsed or 0)>0 and not self.duel.localDone
    and (st.done or (st.elapsed or 0)>=(self.reported or -30)+30)then
    self.duel:progress(st.elapsed,string.format('%.0f',st.score),st.done);self.reported=st.elapsed
   end
   if self.duel.state=='cancelled' and not self.duelCancelled then
    self.duelCancelled=true;self:command{action='pause',value=true};self.notice=self.duel.error
   elseif self.duel.state=='finished'then
    self.result=({win='Du gewinnst',loss='Dein Gegner gewinnt',draw='Unentschieden'})[self.duel.result]
    if self.activity then self.activity:release()end
   elseif not self.checkpoint then self.notice='Punkteduell: gemeinsame Startpartie wird vorbereitet …'
   elseif not self.duel.started then self.notice='Warte auf den anderen Spieler … '..(self.duel.net.code and ('Raum '..self.duel.net.code)or '')end
  end
  if self.countdown and not self.duelCancelled then
   self.countdown=self.countdown-dt
   if self.countdown<=0 then self.countdown=nil;self.videoStarted=false;self:command{action='start'};self.notice=''end
  end
  if self.ready and not self.closing then
   local input={}
   for i=1,self.seats do input[i]=self.input:buttons(i,function(k)return love.keyboard.isDown(k)end,
    not self.paused and function(b)return love.mouse.isDown(b)end or nil,love.window.hasFocus() and not self.paused)end
   if not self.lastInput or input[1]~=self.lastInput[1]or input[2]~=self.lastInput[2]then
    self.lastInput=input;self:command{action='input',buttons=input}
   end
  end
  if self.paused then self.audio:clear()end
  while not self.paused and self.sound:getFreeBufferCount()>0 do
   local data=self.audio:pop();if not data then break end
   if data:getSampleRate()~=self.audioRate then
    self.audioRate=data:getSampleRate()
    self.sound:stop();free(self.sound);self.sound=love.audio.newQueueableSource(data:getSampleRate(),16,1,AUDIO_BUFFERS);self.audioStarted=false;self.sound:setVolume(session.volume or .6)
   end
   local ok=pcall(self.sound.queue,self.sound,data);data:release()
   if not ok then break end
  end
  if self.ready and self.phase~='waiting'and self.phase~='finished'and not self.paused and not self.closing and not self.sound:isPlaying()
   and AUDIO_BUFFERS-self.sound:getFreeBufferCount()>=AUDIO_PREROLL then
   if self.audioStarted then
    self.audioRestarts=(self.audioRestarts or 0)+1
    if options.diagnostics then
     self.audioRestartHistory=self.audioRestartHistory or {}
     if #self.audioRestartHistory<16 then self.audioRestartHistory[#self.audioRestartHistory+1]={at=love.timer.getTime(),frame=self.frame,phase=self.phase,main=self.stats[1]and self.stats[1].main,sub=self.stats[1]and self.stats[1].sub}end
    end
   end
   self.sound:play();self.audioStarted=true
  end
 end
 function self:draw(w,h,preview)
  if self.disposed then return end
  local g=love.graphics;g.push('all');g.clear(.025,.035,.05);g.setFont(self.font)
  local views=self.duel and self.settings.opponentView and 2 or self.seats
  local header=preview and 0 or self.duel and 90 or 72;local footer=preview and 0 or 38
  local gap=views>1 and 12 or 0;local slot=(w-gap*(views-1))/views
  for i=1,views do
   local image=self.images[i];local x=(i-1)*(slot+gap)
   if image then
    local scale=math.min(slot/image:getWidth(),(h-header-footer)/image:getHeight())
    if self.settings.integer and scale>=1 then scale=math.floor(scale)end
    if self.shader and (self.settings.filter=='lcd'or self.settings.filter=='scanlines')then
     self.shader:send('sourceSize',{image:getWidth(),image:getHeight()});self.shader:send('displayMode',self.settings.filter=='lcd'and 1 or 2);g.setShader(self.shader)
    end
    g.setColor(1,1,1);g.draw(image,x+(slot-image:getWidth()*scale)/2,header+(h-header-footer-image:getHeight()*scale)/2,0,scale,scale);g.setShader()
   end
   if not image and self.duel and i==2 then
    g.setColor(.63,.71,.76);g.printf(self.viewFailed and 'Gegneransicht nicht verfügbar' or self.duel.viewEnabled and 'Gegneransicht wird vorbereitet …' or 'Dieser Freund nutzt noch eine Version ohne Live-Ansicht.',x+16,h*.5,slot-32,'center')
   end
   if not preview then
    local title=self.duel and (i==1 and 'DU' or self.options.opponent or 'DEIN FREUND')or self.seats>1 and ('SPIELER '..i)or 'POKÉMON PINBALL · RUBY & SAPPHIRE'
    g.setColor(.44,.83,.89);g.printf(title,x+12,12,slot-24,'left')
    local points=self.duel and i==2 and self.duel.remoteScore or self.stats[i]and self.stats[i].score
    if points then g.setColor(1,1,1);g.printf(string.format('%.0f Punkte',points),x+12,self.duel and 36 or 12,slot-24,'right')end
   end
  end
  if not preview then
   g.setFont(self.small);g.setColor(.63,.71,.76)
   g.print(self.duel and 'Esc: Menü   F6: Tischansicht   F7: Gegneransicht   F9: Bildfilter   F10: Pixelmaßstab   F11: Vollbild' or 'Esc: Menü   F5/F8: Schnellstand   F6: Tischansicht   F9: Bildfilter   F10: Pixelmaßstab   F11: Vollbild',12,h-27)
   if self.duel and views==1 and self.duel.state=='playing'then
    g.setColor(.44,.83,.89);g.printf(string.format('GEGNER: %.0f Punkte',self.duel.remoteScore),12,36,w-24,'left')
   end
   if self.countdown or self.result then
    g.setFont(self.font);g.setColor(.025,.04,.06,.9);g.rectangle('fill',w*.25,h*.43,w*.5,70,12,12)
    g.setColor(1,1,1);g.printf(self.result or tostring(math.ceil(self.countdown)),w*.25,h*.43+25,w*.5,'center')
   end
   if self.notice~=''then g.setColor(1,.78,.35);g.printf(self.notice,12,self.duel and 64 or 44,w-24,'center')end
   if self.paused then
    g.setColor(.02,.03,.05,.94);g.rectangle('fill',w*.15,h*.2,w*.7,h*.6,15,15)
    g.setFont(self.font);g.setColor(.44,.83,.89);g.printf('RECOMPILED ASCENDANT · PINBALL',w*.18,h*.24,w*.64,'center')
    g.setColor(1,1,1);g.printf('Esc / Controller Back: Weiter\nF5: Schnellstand speichern · F8: laden\nF6: Volltisch (Beta) / Original\nF9: Bildfilter · F10: Pixelmaßstab\nF11: Vollbild · Q: Zur Bibliothek\n\nSpieler 1: Pfeile · X/Z · Enter · Q/E: L/R\nBackspace: Select · Spieler 2: WASD / F/G / Tab\nController: Schultern = Flipper · Trigger = L/R\nLinken Stick drücken = Select · Start = Spielpause\nMaus: links/rechts Flipper · Mitte Abschuss',w*.2,h*.32,w*.6,'center')
   end
  end
  g.pop()
 end
 function self:togglePause()
  self.paused=not self.paused;FrameCap.setRealtime(self,not self.paused or self.duel~=nil);if not self.duel then self:command{action='pause',value=self.paused}end
  if not self.duel then
   if self.paused and self.activity then self.activity:release()
   elseif not self.paused then self.activity=require('src.pinball.Activity').acquire()end
  end
  if self.paused then self.sound:stop();self.audio:clear();self.audioStarted=false end
 end
 function self:keypressed(key,_,isrepeat)
  if isrepeat then return end
  local changed=false
  if key=='escape'then self:togglePause()
  elseif self.paused and key=='q'then self:stop()
  elseif key=='f6'then changed=true;self.settings.full_table=not self.settings.full_table;self:command{action='view',full_table=self.settings.full_table};self.notice=self.settings.full_table and 'Volltisch · Beta: Standardfelder; Menüs bleiben in Originalansicht.'or 'Originalansicht'
  elseif key=='f7'and self.duel then changed=true;self.settings.opponentView=not self.settings.opponentView
  elseif key=='f5'or key=='f8'then self:command{action='state',load=key=='f8'}
  elseif key=='f9'then
   changed=true
   local at=1;for i,v in ipairs(FILTERS)do if v==self.settings.filter then at=i end end
   self.settings.filter=FILTERS[at%#FILTERS+1];self.notice='Bildfilter: '..self.settings.filter
   for _,img in pairs(self.images)do img:setFilter(self.settings.filter=='smooth'and 'linear'or 'nearest')end
  elseif key=='f10'then changed=true;self.settings.integer=not self.settings.integer
  elseif key=='f11'then love.window.setFullscreen(not love.window.getFullscreen(),'desktop')end
  if changed then love.filesystem.write('pinball-display.json',Json.encode(self.settings))end
 end
 function self:keyreleased()end
 function self:mousepressed()end
 function self:gamepadpressed(pad,key)
  if key=='back'then self:togglePause()else self.input:join(pad)end
 end
 self.activity=require('src.pinball.Activity').acquire()
 FrameCap.setRealtime(self,true);live[self]=true;return self
end
return M
