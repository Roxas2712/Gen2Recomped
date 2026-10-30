-- Original Pokémon TCG in the shared LÖVE window. By Roxas2712.
local ffi=require('ffi')
ffi.cdef[[
const char* tcg_gbc_error(void);
void* tcg_gbc_open(const char*,int);
int tcg_gbc_step(void*,uint8_t,uint8_t,uint8_t,uint8_t);
const uint8_t* tcg_gbc_picture(void*,int);
const int16_t* tcg_gbc_audio(void*,int,size_t*);
int tcg_gbc_ram(void*,int,uint8_t*,size_t,int);
void tcg_gbc_digest(void*,char*);
uint64_t tcg_gbc_counter(void*,int,int);
int tcg_gbc_memory(void*,int,int,uint32_t,uint8_t*,size_t,int);
void tcg_gbc_close(void*);
int open(const char*,int,...);int flock(int,int);int close(int);
]]
local P={};P.__index=P
local active={};local RATE=4194304/70224
local function read(path)local f=io.open(path,'rb');if not f then return end;local s=f:read('*a');f:close();return s end
local function write(path,s)
 local f,why=io.open(path..'.pending','wb');if not f then return nil,why end
 local ok=f:write(s);local done=f:close();if not ok or not done then return nil,'Cannot write TCG save'end
 return os.rename(path..'.pending',path)
end
local function keys()
 local d,b=255,255;local focused=not love.window.hasFocus or love.window.hasFocus()
 local pads=love.joystick and love.joystick.getJoysticks()or{};local pad
 for _,p in ipairs(pads)do if p:isGamepad()then pad=p;break end end
 local function down(k,g)return focused and(love.keyboard.isDown(k)or(pad and pad:isGamepadDown(g)))end
 if down('right','dpright')then d=d-1 end;if down('left','dpleft')then d=d-2 end
 if down('up','dpup')then d=d-4 end;if down('down','dpdown')then d=d-8 end
 if down('x','a')then b=b-1 end;if down('z','b')then b=b-2 end
 if down('rshift','back')then b=b-4 end;if down('return','start')then b=b-8 end
 return d,b
end
function P.new(session,options)
 options=options or{}
 local self=setmetatable({session=session,elapsed=0,seat=options.mode=='join'and 1 or 0,online=options.mode~=nil,frames=0,lib=ffi.load(session.bridge)},P)
 local ok,why=pcall(function()
  self.savePath=session.player..'/tcg-gbc.sav'
  self.lock=ffi.C.open(self.savePath..'.lock',ffi.os=='OSX'and 514 or 66,ffi.new('int',384))
  assert(self.lock>=0,'Cannot open TCG save lock')
  assert(ffi.C.flock(self.lock,6)==0,'TCG is already open in another window')
  self.original=read(self.savePath);assert(not self.original or #self.original==32768,'TCG save must contain 32768 bytes; file preserved')
  self.handle=self.lib.tcg_gbc_open(session.rom,options.mode and 2 or 1)
  assert(self.handle~=nil,ffi.string(self.lib.tcg_gbc_error()))
  self.ram=ffi.new('uint8_t[32768]');self.hash=ffi.new('char[65]');self.pcmFrames=ffi.new('size_t[1]')
  if self.original then ffi.copy(self.ram,self.original,32768)else assert(self.lib.tcg_gbc_ram(self.handle,0,self.ram,32768,0)==1)end
  self.mods=require('src.tcg.Mods').new(self,options.mode~=nil)
  if options.mode then
   if self.original then
    local backup=self.savePath..'.before-online-'..os.time();local n=0
    while read(backup..'-'..n..'.sav')do n=n+1 end
    assert(write(backup..'-'..n..'.sav',self.original))
   end
   self.net=require('src.tcg.Net').new(options.mode,options.address,options.port or 8766,session.runtime_revision..':'..session.backend_sha256..':'..session.rom_sha1..':'..self.mods.signature,ffi.string(self.ram,32768))
   self.seat=self.net.seat
  else assert(self.lib.tcg_gbc_ram(self.handle,0,self.ram,32768,1)==1);self.started=true end
  self.imageData=love.image.newImageData(160,144,'rgba8');self.image=love.graphics.newImage(self.imageData);self.image:setFilter('nearest','nearest')
  self.font=love.graphics.newFont(14);self.audio=love.audio.newQueueableSource(44100,16,2,16);self.audio:setVolume(.6)
 end)
 if not ok then self:close(false);error(why)end
 active[self]=true;return self
end
function P:update(dt)
 if self.failed then return end
 if self.net then
  self.net:update();if self.net.error then self.failed=self.net.error;self.audio:stop();return end
  if not self.started then
   if not self.net.remote then return end
   local saves={};saves[self.seat+1]=self.net.ram;saves[2-self.seat]=self.net.remote
   for i=0,1 do ffi.copy(self.ram,saves[i+1],32768);assert(self.lib.tcg_gbc_ram(self.handle,i,self.ram,32768,1)==1)end
   self.started=true
  end
 elseif love.window.hasFocus and not love.window.hasFocus()then self.elapsed=0;self.audio:stop();return end
 if not self.modsStarted then self.mods:emit('start',self:modInfo());self.modsStarted=true end
 self.elapsed=math.min(self.elapsed+dt,4/RATE)
 local d,b=keys();local changed=false
 while self.elapsed>=1/RATE do
  local d0,b0,d1,b1=d,b,255,255
  if self.net then
   self.lib.tcg_gbc_digest(self.handle,self.hash)
   local ok,a,c,e,f=pcall(self.net.inputs,self.net,d,b,ffi.string(self.hash))
   if not ok then self.failed=tostring(a);self.desynced=true;self.audio:stop();return end
   if a==nil then self.net:update();break end;d0,b0,d1,b1=a,c,e,f
  end
  self.mods:emit('frame',self:modInfo())
  assert(self.lib.tcg_gbc_step(self.handle,d0,b0,d1,b1)~=0,ffi.string(self.lib.tcg_gbc_error()))
  local serial=tonumber(self.lib.tcg_gbc_counter(self.handle,self.seat,3));local ir=tonumber(self.lib.tcg_gbc_counter(self.handle,self.seat,4))
  if serial~=(self.serial or 0)or ir~=(self.ir or 0)then self.mods:emit('link',{serial=serial,infrared=ir,frame=self.frames,seat=self.seat})end
  self.serial=serial;self.ir=ir
  self.frames=self.frames+1;self.elapsed=self.elapsed-1/RATE;changed=true
  local pcm=self.lib.tcg_gbc_audio(self.handle,self.seat,self.pcmFrames);local n=tonumber(self.pcmFrames[0])
  if n>0 and self.audio:getFreeBufferCount()>0 then local s=love.sound.newSoundData(n,44100,16,2);ffi.copy(s:getFFIPointer(),pcm,n*4);self.audio:queue(s);s:release()end
 end
 if changed then ffi.copy(self.imageData:getFFIPointer(),self.lib.tcg_gbc_picture(self.handle,self.seat),160*144*4);self.image:replacePixels(self.imageData)end
 if not self.audio:isPlaying()and self.audio:getFreeBufferCount()<=12 then self.audio:play()end
end
function P:draw(w,h)
 local g=love.graphics;g.push('all');g.origin();g.setShader();g.setScissor();g.clear(.025,.035,.055);g.setFont(self.font)
 local scale=math.min(w/160,(h-74)/144);if scale>=1 then scale=math.floor(scale)end
 local x,y=(w-160*scale)/2,(h-74-144*scale)/2
 g.setColor(1,1,1,1);g.draw(self.image,x,y,0,scale,scale)
 if self.mods and self.started and not self.failed then
  g.push('all');g.translate(x,y);g.scale(scale,scale);g.setScissor(x,y,160*scale,144*scale)
  local ok,why=pcall(self.mods.draw,self.mods);g.pop()
  if not ok then self.failed=tostring(why);self.desynced=true end
 end
 local status=self.failed or(self.net and(not self.started and 'Warte auf Verbindung …'or 'Online: Link-Duell / Gift Center')or 'Pokémon Trading Card Game · GBC')
 if self.help then status='Pfeile: Steuerkreuz · X: A · Z: B · Enter: Start · Rechte Umschalttaste: Select'end
 g.printf(status,8,h-64,w-16,'center');g.printf('F1: Steuerung · Esc: speichern und Bibliothek',8,h-32,w-16,'center');g.pop()
end
function P:keypressed(key)if key=='escape'then self.done=true elseif key=='f1'then self.help=not self.help end end
function P:close(save)
 local ok,why=true
 if self.mods then local done,problem=self.mods:close();if not done then self.desynced=true;ok=false;why=problem end;self.mods=nil end
 if self.handle~=nil and self.handle then
  if save~=false and self.started and self.frames>0 and not self.desynced then
   assert(self.lib.tcg_gbc_ram(self.handle,self.seat,self.ram,32768,0)==1)
   local bytes=ffi.string(self.ram,32768)
   if bytes~=self.original then
    if read(self.savePath)~=self.original then ok=false;why='TCG save changed in another session; existing file preserved'
    else ok,why=write(self.savePath,bytes)end
   end
  end
  self.lib.tcg_gbc_close(self.handle);self.handle=nil
 end
 if self.net then self.net:close();self.net=nil end
 if self.lock and self.lock>=0 then ffi.C.close(self.lock);self.lock=nil end
 for _,key in ipairs{'audio','image','imageData','font'}do if self[key]then if key=='audio'then self[key]:stop()end;self[key]:release();self[key]=nil end end
 active[self]=nil;return ok,why
end
local regions={wram=0,eram=1,vram=2,io=3,hram=4,oam=5,rom=6}
function P:modInfo()return{game='tcggbc',api=1,romSha1=self.session.rom_sha1,frame=self.frames,online=self.online,seat=self.seat,serial=self.serial or 0,infrared=self.ir or 0}end
function P:modRead(region,offset,n,seat)
 seat=seat or self.seat;n=n or 1
 assert(regions[region]and type(offset)=='number'and offset%1==0 and offset>=0 and offset<=1048576 and type(n)=='number'and n%1==0 and n>=0 and n<=4096,'Invalid TCG memory read')
 assert(not self.online or seat==self.seat,'Online mods can only read their own device')
 local buffer=ffi.new('uint8_t[?]',math.max(1,n));assert(self.lib.tcg_gbc_memory(self.handle,seat,regions[region],offset,buffer,n,0)==1,'TCG read exceeds region');return ffi.string(buffer,n)
end
function P:modWrite(region,offset,data)
 assert(not self.online and(region=='wram'or region=='eram')and type(offset)=='number'and offset%1==0 and offset>=0 and offset<=32768 and type(data)=='string'and #data<=4096,'Invalid TCG memory write')
 local buffer=ffi.new('uint8_t[?]',math.max(1,#data));ffi.copy(buffer,data,#data);assert(self.lib.tcg_gbc_memory(self.handle,self.seat,regions[region],offset,buffer,#data,1)==1,'TCG write exceeds region');return true
end
function P.shutdown()for p in pairs(active)do local ok,why=p:close();if not ok then error(why)end end end
return P
