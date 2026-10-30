-- Separate original Pokémon TCG cartridge; integration by Roxas2712.
local M={}
local function exists(path)local f=type(path)=='string'and io.open(path,'rb');if not f then return false end;f:close();return true end
function M.session()
 local root=os.getenv('ASCENDANT_TCG_GBC_ROOT')or(love and love.filesystem.getSource())
 if not root then return end
 local f=io.open(root..'/.local/tcg-gbc/library.json','rb');if not f then return end
 local bytes=f:read('*a');f:close();local ok,d=pcall(require('src.link.Json').decode,bytes)
 if ok and type(d)=='table'and d.schema==1 and d.ready and d.protocol==1 and d.rom_sha1=='0f8670a583255cff3e5b7ca71b5d7454d928fc48'and exists(d.bridge)and exists(d.rom)and type(d.player)=='string'and type(d.runtime_revision)=='string'and type(d.backend_sha256)=='string'then
  if os.getenv('OA_QA_IDENTITY')then d.player=root..'/.local/tcg-gbc/test-player'end
  return d
 end
end
function M.available()return M.session()~=nil end
function M.install(RI)
 local function import(self,path)
  if self._tcgJob or self._tcgPlayer then return end
  local root=os.getenv('ASCENDANT_TCG_GBC_ROOT')or love.filesystem.getSource()
  if not root or not exists(root..'/tools/tcg_gbc.py')then self._tcgNotice='TCG-Buildwerkzeuge sind in diesem Paket nicht verfügbar.';return end
  self._tcgChannel=love.thread.newChannel();self._tcgJob=love.thread.newThread('src/tcg/import_worker.lua')
  self._tcgNotice='TCG wird vorbereitet …'
  self._tcgJob:start({root=root,path=path,python=os.getenv('ASCENDANT_TCG_PYTHON')or'python3',
   cmake=os.getenv('ASCENDANT_TCG_CMAKE'),ninja=os.getenv('ASCENDANT_TCG_NINJA'),runtime=os.getenv('ASCENDANT_TCG_RUNTIME'),
   ['min-free-gib']=os.getenv('ASCENDANT_TCG_MIN_FREE_GIB')},self._tcgChannel)
 end
 local function choose(self)
  if self._tcgJob or self._tcgPlayer or self._tcgPicker then return end
  if love.window.showFileDialog then
   self._tcgPicker=true
   local ok,why=pcall(love.window.showFileDialog,'openfile',function(files,_,problem)
    self._tcgPicker=nil
    if problem then self._tcgNotice=tostring(problem)elseif files and files[1]then import(self,files[1])end
   end,{title='Pokémon Trading Card Game',filters={['Game Boy (.gb)']='gb',['Game Boy Color (.gbc)']='gbc'},multiselect=false,attachtowindow=true})
   if not ok then self._tcgPicker=nil;self._tcgNotice=tostring(why)end
  else local path=RI._ui.chooseFileByExt({'gb','gbc'},'Pokémon Trading Card Game');if path then import(self,path)end end
 end
 local function start(self,mode)
  if self._tcgPlayer or self._tcgJob then return end
  local s=M.session();if not s then self._tcgNotice='Zuerst tools/tcg_gbc.py prepare mit deiner ROM ausführen.';return end
  if self._xyStopPreview then self:_xyStopPreview()end
  require('src.import.LauncherBackdrop').stop()
  local address=self._tcgAddress or '127.0.0.1:8766'
  local options=mode and{mode=mode,address=address:match('^([^:]+)'),port=tonumber(address:match(':(%d+)$'))or 8766}or nil
  local ok,p=pcall(require('src.tcg.Player').new,s,options)
  if ok then self._tcgPlayer=p;self._tcgNotice=nil else self._tcgNotice=tostring(p)end
 end
 local function finish(self)
  if self._tcgPlayer then local ok,why=self._tcgPlayer:close();self._tcgPlayer=nil;if not ok then self._tcgNotice=why end end
 end
 local open=RI._sbOpenGame
 RI._sbOpenGame=function(self,v,...)
  self._tcgOpen=v=='tcggbc';self._tcgEditing=false
  if self._tcgOpen then
   self.ready.tcggbc=M.available()
   self._pinOpen=false;self._xyOpen=false;self._gbcOpen=false;self.section='games';self.gamesView='game'
   self._tcgOldTab=self._tcgOldTab or self.tab;self.tab=v;self.browseConsole='gbc';self.browseSeries='pokemon';self.pageScroll=0;return
  end
  return open(self,v,...)
 end
 local games=RI._sbGames
 RI._sbGames=function(self,...)self.ready.tcggbc=M.available();return games(self,...)end
 local content=RI._sbDrawContent
 RI._sbDrawContent=function(self,x,y,w,h,...)
  if not(self._tcgOpen and self.section=='games')then return content(self,x,y,w,h,...)end
  local paint=require('src.import.LauncherLibrary').paint;local s=self._s
  paint.text(self,self.gameNameFont,'Pokémon Trading Card Game',x,y,w)
  paint.text(self,self.hintFont,'Game Boy Color · USA / Australia',x,y+48*s,w)
  self._tcgButtons={}
  self._tcgButtons[1]={rect=self:_chipButton(x,y+90*s,self._tcgJob and 'WIRD VORBEREITET …'or 'ROM IMPORTIEREN',{w=math.min(w,420*s),h=38*s}),action='import'}
  for i,row in ipairs{{'SPIELEN','solo'},{'ONLINE HOSTEN','host'},{'ONLINE BEITRETEN','join'},{(self._tcgEditing and '> 'or '')..(self._tcgAddress or '127.0.0.1:8766'),'edit'}}do
   self._tcgButtons[i+1]={rect=self:_chipButton(x,y+(140+(i-1)*50)*s,row[1],{w=math.min(w,420*s),h=38*s,kind=i==1 and'accent'or nil}),action=row[2]}
  end
  paint.text(self,self.hintFont,'Adresse anklicken und IP:Port eingeben. Der Host öffnet diesen TCP-Port.',x,y+344*s,w)
  paint.text(self,self.hintFont,'Duell: Link-Duell im Spiel. Karten: Gift Center, Send / Receive Card.',x,y+380*s,w)
  paint.text(self,self.hintFont,'Pfeile / X / Z / Enter · F1: Steuerung · Esc: Bibliothek',x,y+420*s,w)
  if self._tcgNotice then paint.text(self,self.hintFont,self._tcgNotice,x,y+460*s,w)end
  local yMods=y+515*s
  if not self._tcgMods then
   local ok,rows=pcall(require('src.tcg.Mods').list)
   self._tcgMods=ok and rows or{};if not ok then self._tcgNotice=tostring(rows)end
  end
  paint.text(self,self.stateFont,'TCG-MODS · API 1',x,yMods,w);yMods=yMods+40*s
  for _,mod in ipairs(self._tcgMods)do
   self._tcgButtons[#self._tcgButtons+1]={rect=self:_chipButton(x,yMods,(mod.enabled and '[AN] 'or '[AUS] ')..(mod.name or mod.id),{w=math.min(w,420*s),h=38*s}),action='mod',id=mod.id}
   yMods=yMods+46*s
  end
  return yMods-y+24*s
 end
 local owns=RI._sbOwns
 RI._sbOwns=function(self,...)if self._tcgOpen and self.section=='games'then return true end;return owns(self,...)end
 local play=RI.play;RI.play=function(self,...)if self._tcgOpen then return start(self)end;return play(self,...)end
 local key=RI.keypressed
 RI.keypressed=function(self,k,...)
  if self._tcgPlayer then return self._tcgPlayer:keypressed(k)end
  if self._tcgOpen and self.section=='games'and not self._accountOverlay then
   if self._tcgEditing then
    if k=='return'or k=='escape'then self._tcgEditing=false elseif k=='backspace'then self._tcgAddress=(self._tcgAddress or '127.0.0.1:8766'):sub(1,-2)end;return
   elseif k=='return'then return start(self)end
  end
  return key(self,k,...)
 end
 for _,method in ipairs{'keyreleased','mousepressed','mousereleased','gamepadpressed','gamepadreleased','touchpressed','touchmoved','touchreleased','wheelmoved','textinput'}do
  local old=RI[method];if old then RI[method]=function(self,...)if self._tcgPlayer then return end;return old(self,...)end end
 end
 local text=RI.textinput
 RI.textinput=function(self,value,...)
  if self._tcgOpen and self._tcgEditing then
   self._tcgAddress=((self._tcgAddress or '127.0.0.1:8766')..value:gsub('[^%w%.:%-]','')):sub(1,259);return
  end
  if text then return text(self,value,...)end
 end
 local mouse=RI._sbMousepressed
 RI._sbMousepressed=function(self,x,y,...)
  if self._tcgOpen and self.section=='games'then
   for _,row in ipairs(self._tcgButtons or{})do if row.rect and RI._ui.inside(row.rect,x,y)then self._tcgEditing=row.action=='edit';if row.action=='mod'then local ok,why=pcall(require('src.tcg.Mods').toggle,row.id);self._tcgMods=nil;if not ok then self._tcgNotice=tostring(why)end
     elseif row.action=='import'then choose(self)elseif not self._tcgEditing then start(self,row.action~='solo'and row.action or nil)end;return true end end
  end
  return mouse(self,x,y,...)
 end
 local update=RI.update
 RI.update=function(self,dt,...)
  if self._tcgJob then
   local raw=self._tcgChannel:pop()
   while raw do
    local ok,row=pcall(require('src.link.Json').decode,raw)
    if ok and row.progress then self._tcgNotice='TCG wird vorbereitet: '..row.progress
    elseif ok then self._tcgNotice=row.ok and 'TCG ist bereit.'or row.error;self._tcgResult=true end
    raw=self._tcgChannel:pop()
   end
   if not self._tcgJob:isRunning()then
    local why=self._tcgJob:getError();if why then self._tcgNotice=why elseif not self._tcgResult then self._tcgNotice='TCG-Import wurde ohne Ergebnis beendet.'end
    self._tcgJob=nil;self._tcgResult=nil;self.ready.tcggbc=M.available()
   end
  end
  if self._tcgPlayer then
   local ok,why=pcall(self._tcgPlayer.update,self._tcgPlayer,dt)
   if not ok then self._tcgPlayer.desynced=true;self._tcgNotice=tostring(why);finish(self)elseif self._tcgPlayer.done then finish(self)end
   return
  end
  return update(self,dt,...)
 end
 local draw=RI.draw
 RI.draw=function(self,...)if self._tcgPlayer then return self._tcgPlayer:draw(love.graphics.getDimensions())end;return draw(self,...)end
 local back=RI._sbBack
 RI._sbBack=function(self,...)
  if self._tcgOpen then self._tcgOpen=false;self.tab=self._tcgOldTab or 'gold';self._tcgOldTab=nil;self.gamesView='consoles';return true end
  return back(self,...)
 end
 local go=RI._sbGo
 RI._sbGo=function(self,...)
  if self._tcgOpen then self.tab=self._tcgOldTab or'gold';self._tcgOldTab=nil end
  self._tcgOpen=false;self._tcgEditing=false;return go(self,...)
 end
 local dropped=RI.filedropped
 RI.filedropped=function(self,file,...)
  if not self._tcgPlayer then
   local path=file and file.getFilename and file:getFilename()
   local f=path and io.open(path,'rb')
   if f then f:seek('set',0x134);local title=f:read(8);f:close();if title=='POKECARD'then self:_sbOpenGame('tcggbc');import(self,path);return end end
  end
  if dropped then return dropped(self,file,...)end
 end
 for _,method in ipairs{'leave','quit'}do local old=RI[method];RI[method]=function(self,...)finish(self);if old then return old(self,...)end end end
 local new=RI.new
 RI.new=function(...)
  local self=new(...)
  self.ready.tcggbc=M.available()
  if os.getenv('ASCENDANT_TCG_GBC_START')=='1'then self._launcherSequence=nil;self:_sbOpenGame('tcggbc');start(self)end
  return self
 end
end
return M
