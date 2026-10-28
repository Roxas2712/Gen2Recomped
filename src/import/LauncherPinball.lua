-- GBA Pinball library card and shared-window launch, by Roxas2712.
local M={};local Json=require('src.link.Json');local Strings=require('src.core.Strings')
local function read(path)if not path then return end;local f=io.open(path,'rb');if not f then return end;local b=f:read('*a');f:close();return b end
local function exists(path)if type(path)~='string'then return false end;local f=io.open(path,'rb');if not f then return false end;f:close();return true end
local function sourceRoot()
 return require('src.pinball.Backend').root()
end
local LANGUAGES={{id='en',name='English · USA'},{id='fr',name='Français · EU',index=1},{id='de',name='Deutsch · EU',index=2},{id='it',name='Italiano · EU',index=3},{id='es',name='Español · EU',index=4}}
function M.session(locale)
 local root=sourceRoot();if not root then return end
 local raw=read(root..'/.local/pinball-rs/library.json');if not raw then return end
 local ok,data=pcall(Json.decode,raw)
 if ok and type(data)=='table'and data.ready and exists(data.bridge) and exists(data.rom) and exists(data.bios)then
  if locale and locale~='en'then
   local variant=data.variants and data.variants.eu
   if not variant or not exists(variant.bridge)or not exists(variant.rom)then return end
   local language;for _,v in ipairs(LANGUAGES)do if v.id==locale then language=v end end
   if not language then return end
   for k,v in pairs(variant)do data[k]=v end
   data.language_index=language.index;data.content=data.content..':'..locale
  end
  data.locale=locale or 'en'
  if os.getenv('OA_QA_IDENTITY')then data.player=root..'/.local/pinball-rs/test-player'end
  return data
 end
end
function M.available()return M.session()~=nil end
function M.install(RI)
 local U=RI._ui
 function RI:_pinImport(path)
  if self._pinJob or self._pinPlayer or self._pinPicker then return end
  local root=sourceRoot();if not root then self._pinNotice='Pinball import tools are unavailable.';return end
  self._pinImportChannel=love.thread.newChannel()
  self._pinJob=love.thread.newThread('src/pinball/import_worker.lua')
  self._pinNotice='Preparing your Pinball game …'
  self._pinJob:start({root=root,python=require('src.pinball.Backend').python(),path=path,
   cmake=os.getenv('ASCENDANT_PINBALL_CMAKE'),ninja=os.getenv('ASCENDANT_PINBALL_NINJA')},self._pinImportChannel)
 end
 function RI:_pinChooseImport()
  if self._pinJob or self._pinPlayer or self._pinPicker then return end
  if love.window and love.window.showFileDialog then
   local token={};self._pinPicker=token
   local ok,why=pcall(love.window.showFileDialog,'openfile',function(files,_,problem)
    if self._pinPicker~=token then return end;self._pinPicker=nil
    if not self._pinOpen or self.section~='games'then return end
    if problem then self._pinNotice=tostring(problem)
    elseif type(files)=='table'and files[1]then self:_pinImport(files[1])end
   end,{title='Pokémon Pinball: Ruby & Sapphire',filters={['GBA (.gba)']='gba'},multiselect=false,attachtowindow=true})
   if not ok then self._pinPicker=nil;self._pinNotice=tostring(why)end
  else
   local path=U.chooseFileByExt({'gba'},'Pokémon Pinball: Ruby & Sapphire (.gba)');if path then self:_pinImport(path)end
  end
 end
 function RI:_pinChooseSave()
  if self._pinPicker or self._pinPlayer then return end
  local session=M.session(self._pinLocale);if not session then return end
  local function chosen(path)
   if not self._pinOpen or self.section~='games' or self._pinPlayer then return end
   local ok,why=require('src.pinball.SaveFiles').import(session,path)
   self._pinProfiles=nil;self._pinNotice=ok and Strings('Pinball save imported. Previous data was backed up.')or tostring(why)
  end
  if love.window and love.window.showFileDialog then
   local token={};self._pinPicker=token
   local ok,why=pcall(love.window.showFileDialog,'openfile',function(files,_,problem)
    if self._pinPicker~=token then return end;self._pinPicker=nil
    if problem then self._pinNotice=tostring(problem)elseif type(files)=='table'and files[1]then chosen(files[1])end
   end,{title=Strings('Import save'),filters={['Pinball SRAM (.sav)']='sav'},multiselect=false,attachtowindow=true})
   if not ok then self._pinPicker=nil;self._pinNotice=tostring(why)end
  else local path=U.chooseFileByExt({'sav'},Strings('Import save'));if path then chosen(path)end end
 end
 local function cancelConnect(self)
  if self._pinConnectJob then self._pinConnectJob:cancel();self._pinConnectJob=nil end
 end
 local function library(self)
  cancelConnect(self)
  self._pinPendingInvite=nil;self._pinPendingPeer=nil;self._pinResumeInvite=nil;self._pinSwitchLocale=nil
  self._pinOpen=false;self._pinButtons={};self.gamesView='consoles';self.pageScroll=0
  if self._pinPreviousTab then self.tab=self._pinPreviousTab;self._pinPreviousTab=nil end
 end
 local function finishIntro(self)
  local intro=self._pinIntro;if not intro then return end
  self._pinIntro=nil;intro.scene:release();require('src.import.LauncherBackdrop').setPaused(false)
  intro.begin()
 end
 local function intro(self,session,begin)
  local root=sourceRoot();if not root then begin();return end
  local assets=os.getenv('ASCENDANT_INTRO_ASSETS')or session.intro_assets or(root..'/.local/pokemon-x/intro-assets')
  local ok,scene=pcall(function()
   local make=assert(love.filesystem.load('tools/ascendant-intro/IntroScene.lua'))()
   return make.new(function(path)
    local base=path:sub(1,7)=='assets/' and assets..'/'..path:sub(8)or sourceRoot()..'/tools/ascendant-intro/'..path
    return assert(read(base),'Private intro asset missing')
   end)
  end)
  if not ok then begin();return end
  self._pinIntro={scene=scene,elapsed=0,begin=begin}
 end
 local function start(self,seats,net,host,opponent)
  local session=M.session(self._pinLocale);if not session or self._pinPlayer then return false,'Pinball ist nicht bereit.'end
  if self._xyStopPreview then self:_xyStopPreview()end
  require('src.import.LauncherBackdrop').stop()
  self._pinPendingNet=net
  local function begin()
   self._pinPendingNet=nil
   if net and net.closed then self._pinNotice='Das Freundesduell wurde abgebrochen.';return end
   local ok,p=pcall(require('src.pinball.Player').new,session,{seats=seats or 1,duel=(seats or 1)==2 or net~=nil,field=self._pinField or 0,net=net,host=host,opponent=opponent})
   if ok then self._pinPlayer=p else
    if net then
     net:close()
     if self._pinFriends and self._pinFriends.net==net then self._pinFriends:finished()end
    end
    self._pinNotice=tostring(p)
   end
  end
  if self:_settings().launcherAnimations==false then begin();return self._pinPlayer~=nil,self._pinNotice end
  local state=require('src.import.LauncherSequence').new('play','pinballrs')
  state.cartAppearance=require('src.import.LauncherHardware').appearance(self,'pinballrs')
  state.onComplete=function()intro(self,session,begin)end;self._launcherSequence=state
  return true
 end
 local function friends(self,session)
  if self._pinFriends then self._pinFriends:close()end
  self._pinFriends=require('src.pinball.Friends').new(session,{field=self._pinField or 0,locale=self._pinLocale,
   prepare=function(invite,peer)
    self._pinPendingInvite=invite and invite.id or nil;self._pinPendingPeer=peer
    self._pinPendingAccount=require('src.cloud.RetroCloud').accountId()
    if invite and invite.rules then self._pinLocale=invite.rules.locale end
    require('src.import.AccountWorkspace').close(self)
    self:_sbOpenGame('pinballrs')
    local required=M.session(self._pinLocale)
    if required and invite and invite.rules.rom==required.rom_sha1 and invite.rules.backend~=required.backend then
     self._pinNotice=Strings('Both players need the same current app and Pinball version for this duel.')
     self._pinPendingInvite=nil;return
    end
    if required and invite and require('src.pinball.Friends').new(required):compatible(invite.rules)then
     self._pinSwitchLocale=self._pinLocale
    else
     self._pinNotice=Strings('Choose your matching Pinball import. The friend invitation will be kept.')
     self:_pinChooseImport()
    end
   end,
   start=function(net,host,rules,opponent)
    if self._pinPlayer or self._pinIntro or self._launcherSequence then return false,Strings('Pinball is busy.')end
    require('src.import.AccountWorkspace').close(self)
    self._pinField=rules.field;self._pinFriends.options.field=rules.field;self:_sbOpenGame('pinballrs')
    return start(self,1,net,host,opponent)
   end,
   stop=function(why)
    if self._pinPendingNet then
     self._pinPendingNet=nil;self._launcherSequence=nil
     if self._pinIntro then self._pinIntro.scene:release();self._pinIntro=nil end
     require('src.import.LauncherBackdrop').setPaused(false)
    end
    if self._pinPlayer then self._pinPlayer:stop()end;self._pinNotice=why
   end})
 end
 local function online(self,host,relay)
  if self._pinConnectJob then return end
  self._pinConnectJob=require('src.cloud.Task').new(function()
   local net=require('src.link.Net').new();local ok
   if relay then
    local address=self._pinRelay or '127.0.0.1:7781'
    if host then ok=net:hostOnline(address)else ok=net:joinOnline(address,self._pinCode or '')end
   elseif host then ok=net:host(7777)else ok=net:join(self._pinAddress or '127.0.0.1:7777')end
   if not ok then local why=net.error;net:close();return nil,why end
   return net
  end)
  self._pinConnectHost=host
  self._pinNotice=Strings(self._pinConnectJob and 'Preparing connection …'or 'Background connections are unavailable.')
 end
 local textinput=RI.textinput
 RI.textinput=function(self,text,...)
  if self._pinEdit then
   self[self._pinEdit]=((self[self._pinEdit]or '')..text:gsub('[^%w%.:%-%[%]]','')):sub(1,128);return
  end
  return textinput(self,text,...)
 end
 local keypressed=RI.keypressed
 RI.keypressed=function(self,key,...)
  if self._accountOverlay then return keypressed(self,key,...)end
  if self._pinEdit then
   if key=='backspace'then local v=self[self._pinEdit]or '';self[self._pinEdit]=v:sub(1,-2)
   elseif key=='return'or key=='escape'then self._pinEdit=nil;love.keyboard.setTextInput(false)end
   return
  end
  if self._pinOpen and self.section=='games' and self._pinButtons then
   if key=='up'or key=='down'then
    local n=#self._pinButtons
    if n>0 then self._pinIndex=((self._pinIndex or 1)+(key=='down'and 1 or -1)-1)%n+1;self._pinFocusNeeded=true end
    return
   elseif key=='return'then
    local r=self._pinButtons[self._pinIndex or 1];if r then r.action()end;return
   end
  end
  return keypressed(self,key,...)
 end
 local new=RI.new
 RI.new=function(...)
  local self=new(...)
  self._pinLocale=love.filesystem.read('pinball-locale.txt')or(self._settings and self:_settings().launcherLanguage)or 'en'
  if not M.session(self._pinLocale)then self._pinLocale='en'end
  friends(self,M.session(self._pinLocale))
  if os.getenv('ASCENDANT_PINBALL_START')then
   if self._xyIntro then self._xyIntro.scene:release();self._xyIntro=nil end
   self._pinAutoStart=true;self._launcherSequence=nil
  end
  return self
 end
 local draw=RI.draw
 RI.draw=function(self,...)if self._pinIntro then self._pinIntro.scene:draw(self._pinIntro.elapsed,love.graphics.getDimensions());self._pinIntro.presented=true;return end;if self._pinPlayer then self._pinPlayer:draw(love.graphics.getDimensions());return end;return draw(self,...)end
 local update=RI.update
 RI.update=function(self,dt,...)
  if self._pinJob then
   local raw=self._pinImportChannel:pop()
   while raw do
    local result=Json.decode(raw)
    if result.progress then self._pinNotice=result.progress
    else
     self._pinJob=nil;self._pinNotice=result.ok and(result.data and result.data.notice or 'Pinball game prepared.')or result.error
     if result.ok then
      self._pinProfiles=nil
      if not M.session(self._pinLocale)and not self._pinPendingInvite then self._pinLocale='en'end
      friends(self,M.session(self._pinLocale))
      self._pinResumeInvite=true
     end
    end
    raw=self._pinImportChannel:pop()
   end
   if self._pinJob and self._pinJob:getError()then self._pinNotice=self._pinJob:getError();self._pinJob=nil end
  end
  if self._pinConnectJob then
   local result=self._pinConnectJob:poll()
   if result then
    self._pinConnectJob=nil
    if result.kind=='done'and result.first then
     local net=result.first;self._pinNotice=net.address
     local launched,why=start(self,1,net,self._pinConnectHost)
     if not launched then net:close();self._pinNotice=why end
    else self._pinNotice=tostring(result.second or result.error or 'Verbindung fehlgeschlagen.')end
   end
  end
  if self._pinFriends then
   if self._pinSwitchLocale then
    self._pinSwitchLocale=nil;friends(self,M.session(self._pinLocale));self._pinResumeInvite=true
   end
   if self._pinResumeInvite then
    local Auth=require('src.cloud.RetroCloud')
    if Auth.signedIn()and Auth.accountId()==self._pinPendingAccount then
     local invite=self._pinPendingInvite and self._pinFriends:invitation(self._pinPendingInvite)
     if invite and self._pinFriends:compatible(invite.rules)then
      self._pinFriends:action('pinball:accept:'..invite.id);self._pinResumeInvite=nil;self._pinPendingInvite=nil
     elseif self._pinPendingPeer and self._pinFriends.session then
      self._pinFriends:action('pinball:inviteaccount:'..self._pinPendingPeer);self._pinResumeInvite=nil;self._pinPendingPeer=nil
     elseif invite then
      self._pinNotice=Strings('This import does not match the invitation. Language, cartridge and app build must match.');self._pinResumeInvite=nil
     end
    else self._pinResumeInvite=nil;self._pinPendingInvite=nil;self._pinPendingPeer=nil end
   end
   local available=not(self._pinConnectJob or self._pinPlayer or self._pinIntro or self._launcherSequence or self._xyPlayer or self._xyCheck or self.workState=='working' or self._storageTask)
   local overlay=self._accountOverlay
   local lobby=self._pinOpen or overlay and(overlay.mode=='friends'or overlay.mode=='inbox')
   local Play=require('src.cloud.Play')
   if lobby then Play.setExternalContext(self,self._pinFriends:context(available))else Play.clearExternalContext(self)end
   self._pinFriends:tick(available and lobby)
   if overlay and self._pinFriends.notice then overlay.notice=self._pinFriends.notice end
  end
  if self._pinIntro then
   local current=self._pinIntro;require('src.import.LauncherBackdrop').setPaused(true)
   if current.presented and love.window.isVisible()and love.window.hasFocus()then
    if not current.started then current.started=true;current.scene:play(.6)
    else current.elapsed=current.elapsed+math.max(0,math.min(dt,.1))end
    if current.elapsed>=current.scene.duration then finishIntro(self)end
   end
   return
  end
  if self._pinAutoStart then self._pinAutoStart=nil;self:_sbOpenGame('pinballrs');start(self,tonumber(os.getenv('ASCENDANT_PINBALL_SEATS'))or 1)end
  if self._pinPlayer then
   local p=self._pinPlayer;p:update(dt)
   if p.closed and not p.thread:isRunning()then
    self._pinNotice=p.error;p:dispose();self._pinPlayer=nil;self._pinProfiles=nil;self._pinPreview=nil
    if self._pinFriends then self._pinFriends:finished()end
   end
   return
  end
  return update(self,dt,...)
 end
 for _,method in ipairs{'keypressed','keyreleased','mousepressed','gamepadpressed'}do
  local original=RI[method]
  RI[method]=function(self,...)
   if self._accountOverlay then return original(self,...)end
   if self._pinIntro then if self._pinIntro.elapsed>.35 and method~='keyreleased'then finishIntro(self)end;return end
   if self._pinPlayer then return self._pinPlayer[method](self._pinPlayer,...)end
   if self._pinOpen and method=='gamepadpressed'then
    local _,key=...
    local mapped=({dpup='up',dpdown='down',a='return',start='return',b='escape',back='escape'})[key]
    if mapped then return self:keypressed(mapped)end
   end
   return original(self,...)
  end
 end
 local games=RI._sbGames
 RI._sbGames=function(self,...)self.ready.pinballrs=M.available();return games(self,...)end
 local open=RI._sbOpenGame
 RI._sbOpenGame=function(self,version,...)
  if self._xyStopPreview then self:_xyStopPreview()end
  self._pinOpen=false;self._pinButtons={};self._pinProfiles=nil
  if version=='pinballrs'then
   self.ready.pinballrs=M.available()
   self._xyOpen=false;self._pinOpen=true;self.section='games';self.gamesView='game';self.pageScroll=0
   self._pinPreviousTab=self._pinPreviousTab or self.tab;self.tab=version;self.browseConsole='gba';self.browseSeries='pokemon';self._pinIndex=M.available()and 2 or 1;return
  end
  cancelConnect(self)
  self._pinPendingInvite=nil;self._pinPendingPeer=nil;self._pinResumeInvite=nil;self._pinSwitchLocale=nil
  return open(self,version,...)
 end
 local content=RI._sbDrawContent
 local owns=RI._sbOwns
 RI._sbOwns=function(self,...)if self._pinOpen and self.section=='games'then return true end;return owns(self,...)end
 RI._sbDrawContent=function(self,x,y,w,h,...)
  if self.section~='games'or not self._pinOpen then return content(self,x,y,w,h,...)end
  local s=self._s;local paint=require('src.import.LauncherLibrary').paint;local top=y
  self._pinButtons={}
  local function text(t,font,color)paint.text(self,font or self.hintFont,Strings(t),x,y,w,color);y=y+32*s end
  local function keepVisible(r,index)
   if self._pinFocusNeeded and index==(self._pinIndex or 1)then
    self._pinFocusNeeded=nil
    if r.pinned then return end
    if r.y<150*s then self.pageScroll=math.max(0,self.pageScroll-(150*s-r.y))
    elseif r.y+r.height>love.graphics.getHeight()-60*s then self.pageScroll=self.pageScroll+r.y+r.height-love.graphics.getHeight()+60*s end
   end
  end
  local function button(label,action)
   local index=#self._pinButtons+1
   local r=self:_chipButton(x,y,((self._pinIndex or 1)==index and '› 'or '')..Strings(label),{w=math.min(w,340*s),h=38*s,kind='accent'});r.action=action
   self._pinButtons[#self._pinButtons+1]=r;y=y+48*s
   keepVisible(r,index)
  end
  local function register(r,action)
   if not r then return end;r.action=action;self._pinButtons[#self._pinButtons+1]=r;keepVisible(r,#self._pinButtons)
  end
  local session=M.session(self._pinLocale);local Saves=require('src.pinball.SaveFiles')
  if self._pinPreviewLocale~=self._pinLocale then self._pinPreview=nil end
  if self._pinPreview==nil then
   self._pinPreview=false;self._pinPreviewLocale=self._pinLocale
   local root=sourceRoot();local bytes=session and read(session.player and(session.player..'/preview-'..(session.locale or 'en')..'.png'))
   bytes=bytes or root and read(root..'/.local/pinball-rs/native/preview.png')
   if bytes then
    local ok,image=pcall(function()
     local data=love.filesystem.newFileData(bytes,'pinball-preview.png')
     local image=love.graphics.newImage(data);data:release();return image
    end)
    if ok then self._pinPreview=image;image:setFilter('nearest','nearest')end
   end
  end
  if not self._pinProfiles then
   self._pinProfiles={}
   for _,lang in ipairs(LANGUAGES)do
    local available=M.session(lang.id)
    if available then
     local id=lang.id
     self._pinProfiles[#self._pinProfiles+1]={name=lang.name,selected=id==self._pinLocale,saved=Saves.exists(available),select=function()
      self._pinLocale=id;self._pinProfiles=nil;self._pinIndex=2;love.filesystem.write('pinball-locale.txt',id);friends(self,M.session(id))
     end}
    end
   end
  end
  local actions={back=function()library(self)end,play=function()start(self,1)end,import=function()self:_pinChooseImport()end,
   saved=session and Saves.exists(session),profiles=self._pinProfiles,
   saveImport=function()self:_pinChooseSave()end,
   saveExport=function()
    local path,why=Saves.export(session)
    self._pinNotice=path and Strings('Pinball save exported.')or tostring(why)
    if path then love.system.openURL('file://'..path:match('^(.*)/'))end
   end,
   design=function()
    if self._openCartDesigner then self:_openCartDesigner('pinballrs');self._cartDraft.originalOnly=true end
   end}
  y=y+require('src.import.LauncherPinballPage').draw(self,RI,x,y,w,session,self._pinPreview,actions,register)
  if not M.available()then
   text('BETA / ROM REQUIRED',self.hintFont,RI.palette().warning)
   text('Import your own USA cartridge; add the European cartridge for German, French, Italian or Spanish.')
   if self._pinNotice then text(self._pinNotice,self.hintFont,RI.palette().warning)end
   return y-top
  end
  text('USA base · separate saves · keyboard / mouse / controller')
  local localeName='English · USA'
  for _,lang in ipairs(LANGUAGES)do if lang.id==self._pinLocale then localeName=lang.name end end
  button(Strings('LANGUAGE: %s',localeName),function()
   local at=1;for i,lang in ipairs(LANGUAGES)do if lang.id==self._pinLocale then at=i end end
   for n=1,#LANGUAGES do
    local candidate=LANGUAGES[(at+n-1)%#LANGUAGES+1]
    local session=M.session(candidate.id)
    if session then self._pinLocale=candidate.id;self._pinProfiles=nil;love.filesystem.write('pinball-locale.txt',candidate.id);friends(self,session);break end
   end
  end)
  button((self._pinField or 0)==0 and 'DUEL TABLE: RUBY' or 'DUEL TABLE: SAPPHIRE',function()self._pinField=1-(self._pinField or 0);if self._pinFriends then self._pinFriends.options.field=self._pinField end end)
  button('LOCAL · 2 PLAYERS',function()start(self,2)end)
  button('MODCOMPASS · WITH FRIENDS',function()
   local Account=require('src.import.AccountWorkspace');Account.open(self)
   if require('src.cloud.RetroCloud').signedIn()and self._accountOverlay then self._accountOverlay.afterView='friends'end
  end)
  text('Friend duels require ModCompass with Pinball support.')
  text('Score duel: 5 minutes or until game over · identical fresh start')
  if self._pinFriends then
   for _,entry in ipairs(self._pinFriends:rows())do
    if entry.id=='noop'then text(entry.label)else button(entry.label,function()self._pinFriends:action(entry.id)end)end
   end
   if self._pinFriends.notice then text(self._pinFriends.notice,self.hintFont,RI.palette().warning)end
  end
  local function edit(label,key,default)
   if self[key]==nil then self[key]=default end
   button(Strings(label)..': '..self[key]..(self._pinEdit==key and ' |'or ''),function()self._pinEdit=key;love.keyboard.setTextInput(true)end)
  end
  button(self._pinAdvanced and 'HIDE ADVANCED CONNECTION' or 'ADVANCED CONNECTION · LAN / CUSTOM RELAY',function()self._pinAdvanced=not self._pinAdvanced end)
  if self._pinAdvanced then
  edit('IP / Port','_pinAddress','127.0.0.1:7777')
  button('ONLINE / LAN · HOST DIRECTLY',function()online(self,true,false)end)
  button('ONLINE / LAN · CONNECT',function()online(self,false,false)end)
  text('Direct UDP on port 7777. Internet hosts must forward this port.')
  edit('Custom relay server','_pinRelay','127.0.0.1:7781')
  edit('Room code','_pinCode','')
  button('ONLINE · CREATE ROOM',function()online(self,true,true)end)
  button('ONLINE · JOIN ROOM',function()online(self,false,true)end)
  text('Custom relay: outgoing connection · active ModCompass account required.')
  end
  text('Image filters, pixel scale and quick states: Esc during play.')
  text('Player 1: arrows / X / Z / Enter · Player 2: WASD / F / G / Tab')
  text('Controllers stay assigned to their player.')
  if self._pinNotice then text(self._pinNotice,self.hintFont,RI.palette().warning)end
  return y-top
 end
 local mouse=RI._sbMousepressed
 RI._sbMousepressed=function(self,x,y,...)
  if self._pinOpen and self.section=='games'then for _,r in ipairs(self._pinButtons or {})do if U.inside(r,x,y)then r.action();return true end end end
  return mouse(self,x,y,...)
 end
 local back=RI._sbBack
 RI._sbBack=function(self,...)if self._pinOpen then library(self);return true end;return back(self,...)end
 local go=RI._sbGo
 RI._sbGo=function(self,...)cancelConnect(self);self._pinPendingInvite=nil;self._pinPendingPeer=nil;self._pinResumeInvite=nil;self._pinSwitchLocale=nil;self._pinOpen=false;self._pinButtons={};return go(self,...)end
 local backdrop=RI._sbBackdropWant
 RI._sbBackdropWant=function(self,...)if self._pinOpen or self._pinPlayer then return nil end;return backdrop(self,...)end
 local play=RI.play
 RI.play=function(self,...)
  if self._pinOpen then return start(self,1)end
  cancelConnect(self)
  require('src.cloud.Play').clearExternalContext(self)
  if self._pinFriends then self._pinFriends:close()end
  return play(self,...)
 end
 local dropped=RI.filedropped
 RI.filedropped=function(self,file,...)
  if self._pinOpen then
   local path=file and file.getFilename and file:getFilename()
   if path and path:lower():match('%.gba$')then self:_pinImport(path);return end
  end
  if dropped then return dropped(self,file,...)end
 end
end
return M
