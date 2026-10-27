-- External Kalos backend integration by Roxas2712.
-- These entries never enter GameVersion.set or the native Lua import cache.
local M={}
local Json=require('src.link.Json')
local function read(path)
 local f=io.open(path,'rb');if not f then return end
 local s=f:read('*a');f:close();return s
end
local function decode(s)
 local ok,v=pcall(Json.decode,s or '');return ok and type(v)=='table' and v or nil
end
local function sourceRoot()
 local r=os.getenv('POKEMON_XY_ROOT') or (love and love.filesystem and love.filesystem.getSource and love.filesystem.getSource())
 if r and read(r..'/.local/pokemon-x/library.json') then return r end
end
function M.available() return sourceRoot()~=nil end
function M.info(version)
 if version=='x' or version=='y' then
  return {generation=6,displayName='Pokémon '..version:upper(),importable=true,external=true}
 end
end
function M.versions(console,series)
 if M.available() and (not console or console=='3ds') and (not series or series=='pokemon') then return {'x','y'} end
 return {}
end
local CHOICES={
 {'resolution','Auflösung',{1,2,3,4,5,6,8},function(v)return v..'×' end},
 {'layout','Bildschirme',{'stacked','side_by_side','large_top','overlay','top_only','bottom_only'}},
 {'display_mode','Fensternutzung',{'fit','crop','stretch'}},
 {'overlay_position','Touch-Position',{'right','left','free'}},
 {'overlay_size','Overlay-Größe',{20,25,32,40,50,60},function(v)return v..' %' end},
 {'hide_empty_touch','Leeres Touch-Bild ausblenden',{true,false}},
 {'filter','Bildfilter',{'smooth','sharp','pixels'}},
 {'stereo','Stereo-3D',{'off','anaglyph','side_by_side','half_side_by_side','interlaced'}},
 {'depth_3d','3D-Tiefe',{0,10,25,50,75,100},function(v)return v..' %' end},
 {'swap_eyes','Augen tauschen',{false,true}},
 {'texture_packs','Texturpakete',{true,false}},
 {'show_fps','FPS anzeigen',{false,true}},
}
local LABELS={stacked='Zwei Screens · ohne Spalt',side_by_side='Nebeneinander',large_top='Groß + klein',
 fit='Originalverhältnis',crop='Randlos · Zuschnitt',stretch='Fenster füllen · Strecken',
 right='Rechts neben Hauptbild',left='Links neben Hauptbild',free='Frei verschiebbar',
 overlay='Einzelbild + Touch-Overlay',top_only='Nur Hauptbild',bottom_only='Nur Touch-Menü',
 smooth='Weich',sharp='Scharf',pixels='Pixel',off='Aus',anaglyph='Rot/Cyan',half_side_by_side='SBS · halbe Breite',interlaced='Zeilenraster'}
local function value(v) if type(v)=='boolean' then return v and 'An' or 'Aus' end return LABELS[v] or tostring(v) end
function M.install(RI)
 local U=RI._ui
 local function start(self,action,args,mode)
  if self._xyJob then return end
  local root=sourceRoot();if not root then return end
  local f=io.open('/opt/homebrew/bin/python3','rb')
  local python=f and '/opt/homebrew/bin/python3' or 'python3';if f then f:close() end
  local channel=love.thread.getChannel('pokemon.xy.result');channel:clear()
  self._xyJob=love.thread.newThread('src/import/pokemon_xy_worker.lua')
  self._xyNotice=action=='prepare' and 'Spiel wird für das gemeinsame Fenster vorbereitet …' or 'Wird angewendet …'
  local qa=os.getenv('OA_QA_IDENTITY')
  self._xyJob:start(Json.encode{root=root,python=python,edition=self._xyEdition or 'x',action=action,args=args or {},mode=mode,
   qa_profile=qa and (root..'/.local/qa/pokemon-xy-native-ui/player-'..(self._xyEdition or 'x')) or nil})
 end
 local function load(self)
  local root=sourceRoot();if not root then return end
  if not self._xyData then
   self._xyData=decode(read(root..'/.local/pokemon-x/library-ui.json')) or decode(read(root..'/.local/pokemon-x/library.json'))
  end
  return self._xyData
 end
 local function newIntro(self,onComplete)
  local root=sourceRoot();if not root then return end
  if self._xyIntro then self._xyIntro.scene:release() end
  local ctor=assert(love.filesystem.load('tools/ascendant-intro/IntroScene.lua'))()
  local scene=ctor.new(function(path)
   return assert(read(root..(path:sub(1,7)=='assets/' and '/.local/pokemon-x/intro-assets/'..path:sub(8) or '/tools/ascendant-intro/'..path)))
  end)
  local fixed=os.getenv('OA_QA_IDENTITY') and tonumber(os.getenv('POKEMON_XY_QA_INTRO_AT'))
  self._xyIntro={scene=scene,elapsed=fixed or 0,fixed=fixed,onComplete=onComplete}
  self._launcherSequence=nil
 end
 local new=RI.new
 RI.new=function(...)
  local self=new(...)
  local edition=os.getenv('POKEMON_XY_EDITION')
  if M.info(edition) then
   -- Direct edition starters play the complete intro after preparation once.
   self._launcherSequence=nil;self._xyEdition=edition;self._xyOpen=true;self._xyAutoPlay=true
  elseif self._launcherSequence and self._launcherSequence.kind=='intro' and M.available() then newIntro(self) end
  return self
 end
 local draw=RI.draw
 RI.draw=function(self,...)
  if self._xyPlayer then self._xyPlayer:draw(love.graphics.getDimensions());return end
  local intro=self._xyIntro
  if intro then
   intro.scene:draw(intro.elapsed,love.graphics.getDimensions());intro.presented=true;return
  end
  return draw(self,...)
 end
 local function finishIntro(self)
  local intro=self._xyIntro;if not intro then return end
  self._xyIntro=nil;intro.scene:release();self._sequenceInputGuard=.15
  require('src.import.LauncherBackdrop').setPaused(false)
  if intro.onComplete then intro.onComplete() end
 end
 for _,method in ipairs{'keypressed','mousepressed','gamepadpressed','joystickpressed'}do
  local original=RI[method]
  RI[method]=function(self,...)
   if self._xyPlayer then
    if method=='keypressed' then self._xyPlayer:keypressed(...)
    elseif method=='mousepressed' then self._xyPlayer:mousepressed(...)
    elseif method=='gamepadpressed' then self._xyPlayer:gamepadpressed(...) end
    return
   end
   if self._xyIntro then
    if self._xyIntro.started and self._xyIntro.elapsed>.35 then finishIntro(self) end
    return
   end
   return original(self,...)
  end
 end
 local textinput=RI.textinput
 RI.textinput=function(self,text,...)if self._xyPlayer then return self._xyPlayer:textinput(text)end;return textinput(self,text,...)end
 local released=RI.keyreleased
 RI.keyreleased=function(self,key,...)
  if self._xyPlayer then return self._xyPlayer:keyreleased(key) end
  if released then return released(self,key,...) end
 end
 local settingsAction=RI._settingsAction
 RI._settingsAction=function(self,entry,...)
  if entry and entry.action=='launcherPreviewIntro' and M.available() then newIntro(self);return end
  return settingsAction(self,entry,...)
 end
 local function stopPreview(self)
  if self._xyPreview then self._xyPreview:stop();self._xyRetiring=self._xyRetiring or {};self._xyRetiring[#self._xyRetiring+1]=self._xyPreview;self._xyPreview=nil end
 end
 local function saveReport(self,session,result)
  local root=sourceRoot();if not root then return end
  local dir=session.report_dir or root..'/.local/pokemon-x/device-tests'
  -- Parent prepared by the Python bridge; atomic replacement keeps reports readable.
  local name=dir..'/'..session.edition..'.json'
  local file=io.open(name..'.pending','wb')
  if file then file:write(Json.encode{profile=session.profile_key,result=result});file:close();os.rename(name..'.pending',name) end
  self._xyDevice=result
 end
 local function openNative(self,session)
  session.volume=math.max(0,math.min(1,(tonumber(self:_settings().musicVol) or 5)/7))
  local Sequence=require('src.import.LauncherSequence')
  local function begin()
   local ok,player=pcall(require('src.import.PokemonXYNative').new,session,'playing')
   if ok then self._xyPlayer=player else self._xyNotice=tostring(player) end
  end
  if self:_settings().launcherAnimations==false then begin();return end
  local state=Sequence.new('play',session.edition)
  state.cartAppearance=require('src.import.LauncherHardware').appearance(self,session.edition)
  state.onComplete=function()newIntro(self,begin)end;self._launcherSequence=state
 end
 local function receiveSession(self,session,mode)
  stopPreview(self)
  self._xyPendingSession=session
  local report=decode(read((session.report_dir or session.root..'/.local/pokemon-x/device-tests')..'/'..session.edition..'.json'))
  if mode~='benchmark' and report and report.profile==session.profile_key and report.result and report.result.can_play then
   session.resolution=report.result.resolution;openNative(self,session);self._xyPendingSession=nil;return
  end
  local ok,check=pcall(require('src.import.PokemonXYNative').new,session,'benchmark')
  if ok then self._xyCheck=check;self._xyAfterCheck=mode~='benchmark';self._xyNotice='Gerätetest: Aufwärmen und 360 gemessene Frames …'
  else self._xyNotice=tostring(check);self._xyPendingSession=nil end
 end
 function RI:_xyStart(mode)
  if self._xyJob or self._xyPlayer or self._xyCheck then return end
  stopPreview(self);start(self,'prepare',nil,mode or 'playing')
 end
 function RI:_xyPreviewStart()
  if self._xyJob or self._xyPlayer or self._xyCheck or self._xyPreview or self._launcherSequence or self._xyIntro then return end
  local root=sourceRoot();local row=load(self) and self._xyData[self._xyEdition]
  if not root or not row or not row.ready then return end
  local file=io.open(root..'/.local/pokemon-x/bin/libascendant_3ds_bridge.dylib','rb');if not file then return end;file:close()
  local settings={};for k,v in pairs(row.settings or {})do settings[k]=v end
  settings.layout='top_only';settings.stereo='off'
  local data=root..'/.local/pokemon-x/previews/'..self._xyEdition
  local session={rom=row.rom,library=row.library,bridge=root..'/.local/pokemon-x/bin/libascendant_3ds_bridge.dylib',
   data=data,session_lock=data..'/session.lock',resolution=1,language=3,depth_3d=0,stereo='off',texture_packs=false,
   settings=settings,edition=self._xyEdition,root=root}
  local ok,preview=pcall(require('src.import.PokemonXYNative').new,session,'preview')
  if ok then self._xyPreview=preview else self._xyNotice=tostring(preview) end
 end
 local update=RI.update
 RI.update=function(self,dt,...)
  for i=#(self._xyRetiring or {}),1,-1 do
   local old=self._xyRetiring[i];old:update(dt)
   if old.closed and not old.thread:isRunning()then old:dispose();table.remove(self._xyRetiring,i)end
  end
  if self._xyPlayer then
   self._xyPlayer:update(dt)
   if self._xyPlayer.closed and not self._xyPlayer.thread:isRunning() then
    local player=self._xyPlayer
    self._xyNotice=player.error or 'Zurück in der Bibliothek.';player:dispose();self._xyPlayer=nil
    if player.session.data==sourceRoot()..'/.local/pokemon-x/player' then
     local args={}
     for _,key in ipairs{'layout','stereo','depth_3d','swap_eyes','display_mode','overlay_position','overlay_size','overlay_x','overlay_y','hide_empty_touch'}do if player.settings[key]~=nil then args[#args+1]='--set';args[#args+1]=key..'='..Json.encode(player.settings[key])end end
     start(self,'configure',args)
    else start(self,'status')end
   end
   return
  end
  if self._xyCheck then
   local check=self._xyCheck;check:update(dt)
   if check.closed and not check.thread:isRunning() then
    self._xyCheck=nil;local session=self._xyPendingSession;local result=check.result;check:dispose()
    if result and result.status=='lower_resolution' then
     session.resolution=1
     self._xyNotice='Gerätetest: Prüfung bei 1× Auflösung …'
     self._xyCheck=require('src.import.PokemonXYNative').new(session,'benchmark')
    else
     self._xyPendingSession=nil
     if result then
      saveReport(self,session,result)
      self._xyNotice=result.can_play and string.format('Starttest: %.1f Emu-Frames/s · p95 %.1f ms · %d×',result.measured_fps,result.p95_ms,result.resolution) or 'Device too weak · Der gemessene Starttest erreicht auch bei 1× keine volle Geschwindigkeit.'
      if result.can_play and self._xyAfterCheck then openNative(self,session)end
     else self._xyNotice=check.error or 'Gerätetest nicht abgeschlossen.' end
    end
   end
   return
  end
  if self._xyPreview then
   self._xyPreview:update(dt)
   if self._xyPreview.closed and not self._xyPreview.thread:isRunning() then self._xyNotice=self._xyPreview.error;self._xyPreview:dispose();self._xyPreview=nil;self._xyPreviewFailed=true end
  end
  if self._xyAutoPlay and not self._xyIntro then self._xyAutoPlay=nil;self:_xyStart()end
  local intro=self._xyIntro
  if intro then
   require('src.import.LauncherBackdrop').setPaused(true)
   if intro.fixed then intro.elapsed=intro.fixed;intro.started=true;return end
   if not intro.presented or not love.window.isVisible() or not love.window.hasFocus() then return end
   if not intro.started then
    intro.started=true
    intro.scene:play(math.max(0,math.min(1,(tonumber(self:_settings().musicVol) or 5)/7))*.7)
   else intro.elapsed=intro.elapsed+math.max(0,math.min(dt,.1)) end
   if intro.elapsed>=intro.scene.duration then finishIntro(self) end
   return
  end
  if self._xyJob then
   local response=love.thread.getChannel('pokemon.xy.result'):pop()
   if response then
    local result=decode(response)
    self._xyJob=nil
    if result and result.ok then self._xyData=result.data;self._xyNotice='Bereit.';if result.session then receiveSession(self,result.session,result.mode)end
    else self._xyNotice=(result and result.error or 'Unbekannter Backend-Fehler'):sub(-700) end
   elseif self._xyJob:getError() then self._xyNotice=self._xyJob:getError();self._xyJob=nil end
  end
  return update(self,dt,...)
 end
 local function buttons(self)self._xyButtons={}end
 local function button(self,x,y,w,label,action)
  local r=self:_chipButton(x,y,label,{w=w,h=34*self._s,kind='accent'})
  r.action=action;self._xyButtons[#self._xyButtons+1]=r
 end
 local function panel(self,x,y,w,h)
  local s,g,p=self._s,love.graphics,RI.palette();local top=y
  local paint=require('src.import.LauncherLibrary').paint
  local text=function(font,t,yy,color)paint.text(self,font,t,x,yy,w,color)end
  buttons(self)
  button(self,x,y,165*s,'ZUR BIBLIOTHEK',function()stopPreview(self);self._xyOpen=false;self.pageScroll=0 end)
  y=y+51*s
  text(self.gameNameFont,'Pokémon '..self._xyEdition:upper(),y);y=y+45*s
  text(self.hintFont,'Recompiled Ascendant · by Roxas2712',y,p.link);y=y+30*s
  local data=load(self) or {};local row=data[self._xyEdition] or {};local settings=row.settings or {}
  local ready=row.ready
  text(self.stateFont,ready and 'Bereit für Kalos.' or 'Recompile wird vorbereitet.',y,ready and p.green or p.warning);y=y+36*s
  local previewH=math.min(210*s,w*.5)
  paint.surface(x,y,w,previewH,12*s,p.link,false)
  if self._xyPreview then
   local g=love.graphics;g.push('all');g.translate(x+w*.48,y);self._xyPreview:draw(w*.52,previewH,true);g.pop()
  end
  require('src.import.LauncherHardware').cartridge(self,self._xyEdition,x+w*.23,y+previewH*.5,w*.38,previewH*.82)
  y=y+previewH+20*s
  if self._xyCheck then
   text(self.hintFont,'GERÄTETEST · '..tostring(self._xyCheck.frame or 0)..' / 480 Frames',y,p.warning)
  elseif self._xyJob then text(self.hintFont,'Wird vorbereitet …',y,p.warning)
  else
   if ready then button(self,x,y,math.min(180*s,(w-12*s)/2),'SPIELEN',function()self:_xyStart()end) end
   button(self,x+math.min(180*s,(w-12*s)/2)+12*s,y,math.min(165*s,(w-12*s)/2),'Status erneuern',function()start(self,'status')end)
  end
  y=y+44*s
  button(self,x,y,math.min(220*s,w),'GERÄT TESTEN',function()self:_xyStart('benchmark')end)
  y=y+52*s
  text(self.labelFont,'GRAFIK & FREIE SCREEN-WAHL',y,p.link);y=y+31*s
  for _,entry in ipairs(CHOICES) do
   local key,title,choices,fmt=entry[1],entry[2],entry[3],entry[4]
   local current=settings[key]
   local bw=math.min(290*s,w*.59)
   paint.surface(x,y,w,42*s,6*s,p.link,false)
   paint.text(self,self.hintFont,title,x+12*s,y+12*s,w-bw-20*s)
   local label=fmt and current~=nil and fmt(current) or value(current==nil and choices[1] or current)
   button(self,x+w-bw-4*s,y+4*s,bw,label..'  ›',function()
    if self._xyJob then return end
    local at=0;for i,v in ipairs(choices)do if v==current then at=i end end
    start(self,'configure',{'--set',key..'='..Json.encode(choices[at%#choices+1])})
   end)
   y=y+49*s
  end
  text(self.hintFont,'F6: Overlay an/aus · F7: Zwei Screens an/aus',y,p.detail);y=y+23*s
  text(self.hintFont,'F9: Layout wechseln · F10: Hauptbild/Touch · F11: Vollbild',y,p.detail);y=y+23*s
  text(self.hintFont,'Esc: Spielmenü, Controller, Cheats und weitere Einstellungen',y,p.detail);y=y+30*s
  g.setFont(self.hintFont);U.col(p.detail)
  g.printf('Stereo-3D: Rot/Cyan benötigt eine passende Brille. SBS/Zeilenraster benötigen eine passende Anzeige. Die klassische Ansicht bleibt frei wählbar.',x,y,w,'left');y=y+60*s
  button(self,x,y,math.min(w,310*s),'Sprachauswahl zurücksetzen',function()start(self,'reset-language')end)
  y=y+48*s
  text(self.labelFont,'MODS & TEXTUREN',y,p.link);y=y+29*s
  text(self.hintFont,tostring(row.mod_files or 0)..' Mod-Dateien · '..(row.mods_enabled==false and 'pausiert' or 'aktiv'),y,p.detail);y=y+29*s
  local bw=math.min(185*s,(w-20*s)/3)
  button(self,x,y,bw,'Mod-Ordner',function()
   local path=row.mods_path
   if path then love.system.openURL('file://'..path:gsub('([^%w%-%._~/])',function(c)return string.format('%%%02X',c:byte())end)) end
  end)
  button(self,x+bw+10*s,y,bw,'Ordner importieren',function()
   if self._xyJob then return end
   local folder=U.chooseFolder('X/Y-Mod auswählen: Ordner mit romfs oder textures')
   if folder then start(self,'install-mod',{'--mod-source',folder}) end
  end)
  button(self,x+2*(bw+10*s),y,bw,row.mods_enabled==false and 'Mods aktivieren' or 'Mods pausieren',function()start(self,'toggle-mods')end)
  y=y+52*s
  g.setFont(self.hintFont);U.col(p.detail)
  g.printf('RomFS-Mods und Citra-/Azahar-Texturpakete bleiben pro Edition getrennt. Importierte Dateien ersetzen keine bereits installierten Mod-Dateien. Code-Patches können einen neuen Recompile benötigen.',x,y,w,'left');y=y+72*s
  if self._xyNotice then g.setFont(self.hintFont);U.col(p.warning);g.printf(self._xyNotice,x,y,w,'left');y=y+110*s end
  return y-top
 end
 local content=RI._sbDrawContent
 RI._sbDrawContent=function(self,x,y,w,h,...)
  if self.section=='games' and self._xyOpen then
   if not self._xyPreviewFailed and not self._xyJob then self:_xyPreviewStart()end
   return panel(self,x,y,w,h)
  end
  return content(self,x,y,w,h,...)
 end
 local games=RI._sbGames
 RI._sbGames=function(self,...)
  self._xyButtons={}
  local data=load(self)
  if data then for _,edition in ipairs{'x','y'}do self.ready[edition]=data[edition] and data[edition].ready or false end end
  return games(self,...)
 end
 local openGame=RI._sbOpenGame
 RI._sbOpenGame=function(self,version,...)
  if M.info(version) and M.available() then
   stopPreview(self);self._xyPreviewFailed=nil;self._xyEdition=version;self._xyOpen=true;self.section='games';self.pageScroll=0;start(self,'status');return
  end
  return openGame(self,version,...)
 end
 local mouse=RI._sbMousepressed
 RI._sbMousepressed=function(self,x,y,...)
  if self.section=='games' then
   for _,r in ipairs(self._xyButtons or {})do if U.inside(r,x,y)then r.action();return true end end
  end
  return mouse(self,x,y,...)
 end
 local backdrop=RI._sbBackdropWant
 RI._sbBackdropWant=function(self,...)if self._xyOpen or self._xyPlayer or self._xyCheck then return nil end;return backdrop(self,...)end
 local back=RI._sbBack
 RI._sbBack=function(self,...)
  if self._xyOpen then stopPreview(self);self._xyOpen=false;self.pageScroll=0;return true end
  return back(self,...)
 end
 local go=RI._sbGo
 RI._sbGo=function(self,...)stopPreview(self);self._xyOpen=false;self._xyButtons={};return go(self,...)end
end
return M
