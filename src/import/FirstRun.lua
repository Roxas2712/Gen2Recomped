-- A device-local introduction. Finishing it never creates an account, starts
-- an upload or changes an existing player's cloud choice. Artwork downloads
-- require the separate, explicit original-image option.
local W={VERSION=1}
local Saves=require('src.core.SaveData')
local Translation=require('src.translation.Service')
local function L(value) return Translation.launcherLookup(value) end
W.pages={
  {title='Your journey starts here.',tag='WELCOME',icon='games',body='Choose your language. You can change the launcher and game text languages separately in Settings.'},
  {title='Your look.',tag='MAKE IT YOURS',icon='settings',body='Choose the colors of your launcher. Your cartridges keep their own edition colors. Everything can be changed later.'},
  {title='Small cartridges. Big adventures.',tag='YOUR LIBRARY',icon='games',body='Import your own game files with Import ROMs. You can select several at once. The launcher extracts the data on this device; no games are included.',
    tips={'Choose original cartridge images below, or use Library → Load all original cartridges later. One saved choice can also cover new supported games.',
      'Prefer your own artwork? Open a cartridge’s design options to import a picture, change its colors or choose a logo label.',
      'Manual mod ZIP imports and local play work without an account. ModCompass browsing and direct installation use your account.'}},
  {title='Play here. Continue anywhere.',tag='SAVES & CLOUD',icon='news',body='You can play without signing in. Saves stay on this device. A free account connects your saves, Bank, profile and friends across your own devices.',
    tips={'Normal save: your adventure progress and an emulator-compatible .sav export. Portable suspend: the exact running moment, including a battle.',
      'To switch devices: open the in-game menu, save a portable suspend and upload it. Wait for Available on your other devices. On the other device, sign in, restore games and saves, then Continue.',
      'Both devices need the same app build and imported game version. Private game-cache upload is optional and has its own storage quota. It shares your imports only with your account.'}},
  {title='Make yourself at home.',tag='READY TO PLAY',icon='star',body='Sign in to an existing ModCompass account or create one here. Confirm your email once. You stay signed in on this device until you sign out.',
    tips={'Cloud saves and your Bank travel with your account. Friends, trading, cups and gift codes use the same profile.',
      'In-game quick menu: Esc / F1, the controller Guide button, or the Retro button on a touchscreen. Save, change speed, mute sound and open your friends.',
      'Need this guide again? Settings → Setup & guide. You can start locally now and connect your account whenever you want.'}},
}
function W.open(self)
  local o=self:_settings()
  self._setupOverlay={page=1,language=o.launcherLanguage or 'en',theme=o.launcherTheme or false,accent=o.launcherAccent or false,rects={},selected=1,scroll=0,originals=o.launcherOriginalCartridges==true and o.launcherOriginalCartridgesConsent==require('src.import.CartridgeBatch').CONSENT}
  Translation.setLauncher(o)
end
local function preview(self,f)
  local o={};for k,v in pairs(self:_settings()) do o[k]=v end
  o.launcherLanguage=f.language;o.launcherTheme=f.theme;o.launcherAccent=f.accent
  Translation.setLauncher(o);self.applyTheme(o);self.fontKey=nil
end
function W.finish(self,after)
  local f=self._setupOverlay;if not f then return end
  -- Persist one complete choice atomically; failed writes leave the guide open.
  local o={};for k,v in pairs(self:_settings()) do o[k]=v end
  o.launcherLanguage=f.language;o.launcherTheme=f.theme;o.launcherAccent=f.accent;o.launcherSetupVersion=W.VERSION
  o.launcherOriginalCartridges=f.originals==true
  if f.originalChoice or f.originals then o.launcherOriginalCartridgesConsent=require('src.import.CartridgeBatch').CONSENT end
  o.nativeLanguageDefault=require('src.translation.NativeLanguages').canonical(f.language)
  if not o.launcherSaveStorageChoice then o.launcherSaveStorageChoice='local';o.cloudAutoSync=false end
  local ran,ok=pcall(Saves.saveOptions,o)
  if not ran or not ok then f.notice='Your preferences could not be saved. Please try again.';return end
  self._settingsCache=nil;self._settingsRowCache=nil;self._setupOverlay=nil;self._setupPending=nil
  Translation.setLauncher(o);Translation.enqueueLauncher(o);self.applyTheme(o)
  if after=='login' or after=='register' then
    self:_openAccount();self._accountOverlay.mode=after
  elseif after=='import' then self:chooseRomBatch() end
  return true
end
function W.action(self,id)
  local f=self._setupOverlay;if not f then return end
  if id=='next' or id=='back' then f.page=math.max(1,math.min(#W.pages,f.page+(id=='next' and 1 or -1)));f.scroll=0;f.selected=1;f.notice=nil
  elseif id=='done' or id=='skip' then return W.finish(self)
  elseif id=='register' or id=='login' or id=='import' then return W.finish(self,id)
  elseif id=='originals' then f.originals=not f.originals;f.originalChoice=true
  elseif id=='downloadOriginals' then
    local batch=require('src.import.CartridgeBatch');local ok,why=batch.setAutomatic(self,true)
    if not ok then f.notice=why;return end
    f.originals=true;f.originalChoice=true
    if not(self._cartBatch and self._cartBatch.running)then self._cartBatch={consent=true};batch.start(self,true)end
  elseif id=='stopOriginals' then require('src.import.CartridgeBatch').cancel(self)
  elseif id=='originalSources' then love.system.openURL('https://archives.bulbagarden.net/wiki/Category:Game_cartridges')
  elseif id:match('^language:') then
    f.language=id:sub(10);preview(self,f)
  elseif id=='languageNext' then
    local languages=require('src.translation.Languages');local at=2
    for i,v in ipairs(languages) do if v[1]==f.language then at=i end end
    at=at%#languages+1;if languages[at][1]=='original' then at=2 end
    f.language=languages[at][1];preview(self,f)
  elseif id:match('^theme:') then f.accent=false;f.theme=id:sub(7);if f.theme=='default' then f.theme=false end;preview(self,f)
  elseif id:match('^accent:') then f.accent=id:sub(8);if f.accent=='default' then f.accent=false end;preview(self,f) end
end
function W.scroll(self,dy)
  local f=self._setupOverlay;if f then f.scroll=math.max(0,math.min(f.maxScroll or 0,f.scroll-dy*42)) end
end
local function navigate(self,delta)
  local f=self._setupOverlay;if not f or #f.rects==0 then return end
  f.selected=((f.selected or 1)-1+delta)%#f.rects+1;f.follow=true
end
function W.logo(self,x,y,w,h)
 local image=self.gen2Logo or self.logo;if not image then return end
 local iw,ih=image:getDimensions();local scale=math.min(w/iw,h/ih)
 love.graphics.setColor(1,1,1,1)
 require('src.import.LauncherTheme').drawLogo(image,x+(w-iw*scale)/2,y+(h-ih*scale)/2,0,scale,scale)
end
function W.draw(self)
  local f=self._setupOverlay;if not f or self._launcherSequence then return end
  local g=love.graphics;local ww,hh=g.getDimensions();local s=math.max(.6,math.min(ww/1060,hh/760,1.3))
  local w,h=math.min(1020*s,ww-24),math.min(708*s,hh-24);local x,y=(ww-w)/2,(hh-h)/2
  local U,P=self._ui,self.palette();local page=W.pages[f.page]
  g.push('all');g.setCanvas();g.origin();g.setShader();g.setScissor();g.setBlendMode('alpha')
  if g.setDepthMode then g.setDepthMode() end;if g.setStencilTest then g.setStencilTest() end
  if g.setColorMask then g.setColorMask(true,true,true,true) end
  g.setColor(.01,.02,.04,.96);g.rectangle('fill',0,0,ww,hh)
  U.col(P.bgBot);g.rectangle('fill',x,y,w,h,20*s,20*s)
  U.col(P.link,.45);g.setLineWidth(1);g.rectangle('line',x,y,w,h,20*s,20*s)
  local sidebar=ww>=850 and 252*s or 0
  if sidebar>0 then
    U.col(P.link,.07);g.rectangle('fill',x+1,y+1,sidebar,h-2,20*s,20*s)
    W.logo(self,x+18*s,y+75*s,sidebar-36*s,270*s)
    for i,p in ipairs(W.pages) do
      U.col(i==f.page and P.link or P.detail,i==f.page and 1 or .55)
      g.circle('fill',x+30*s,y+402*s+(i-1)*39*s,4*s)
      g.setFont(self.warningFont);g.printf(L(p.tag),x+44*s,y+394*s+(i-1)*39*s,sidebar-60*s,'left')
    end
  end
  local tx=x+sidebar+28*s;local tw=w-sidebar-56*s
  local header=sidebar==0 and 58*s or 0
  if sidebar==0 then W.logo(self,tx,y+12*s,tw,48*s)end
  g.setFont(self.labelFont);U.col(P.link);g.printf(L(page.tag)..'  /  '..f.page..'–'..#W.pages,tx,y+26*s+header,tw,'left')
  local dy=y+56*s+header
  g.setFont(self.gameNameFont);U.col(P.ink);local _,titleLines=self.gameNameFont:getWrap(L(page.title),tw)
  g.printf(L(page.title),tx,dy,tw,'left');dy=dy+#titleLines*self.gameNameFont:getHeight()+20*s
  local v={x=tx,y=dy,width=tw,height=math.max(20,h-(dy-y)-108*s)};f.viewport=v
  local top=v.y-f.scroll;f.rects={}
  g.setScissor(v.x,v.y,v.width,v.height)
  local function para(value)
    value=L(value);g.setFont(self.hintFont);U.col(P.detail)
    local _,lines=self.hintFont:getWrap(value,tw);g.printf(value,tx,top,tw,'left');top=top+#lines*self.hintFont:getHeight()+22*s
  end
  local function button(id,label,width,xx,yy,pinned)
    label=L(label);local font=self.hintFont;local _,lines=font:getWrap(label,(width or tw)-28*s)
    local bh=math.max(42*s,#lines*font:getHeight()+18*s)
    local r={id=id,x=xx or tx,y=yy or top,width=width or tw,height=bh,pinned=pinned};f.rects[#f.rects+1]=r
    local selected=(id=='language:'..f.language) or id=='theme:'..(require('src.import.LauncherTheme').resolve(f.theme) or 'default') or id=='accent:'..(f.accent or 'default')
    local focused=f.selected==#f.rects
    U.col(P.link,selected and .24 or focused and .14 or .06);g.rectangle('fill',r.x,r.y,r.width,r.height,8*s,8*s)
    U.col(P.link,selected and 1 or focused and .8 or .3);g.rectangle('line',r.x,r.y,r.width,r.height,8*s,8*s)
    U.col(selected and P.link or P.ink);g.setFont(font);g.printf(label,r.x+14*s,r.y+9*s,r.width-28*s,'center')
    local themeId=id:match('^theme:(.+)$');local preset=themeId and require('src.import.LauncherTheme').PRESETS[themeId]
    if preset then U.col(preset.accent.link);g.circle('fill',r.x+18*s,r.y+r.height/2,3*s)end
    if not yy then top=top+bh+10*s end
    return bh
  end
  para(page.body)
  if f.page==1 then
    local langs={{'en','English'},{'de','Deutsch'},{'fr','Français'},{'es','Español'},{'it','Italiano'},{'pb','Português (Brasil)'},
      {'ja','日本語'},{'ko','한국어'},{'zh','简体中文'},{'zh-Hant','繁體中文'}}
    local cw=(tw-10*s)/2
    for i,item in ipairs(langs) do
      local yy=top+math.floor((i-1)/2)*52*s
      button('language:'..item[1],item[2],cw,tx+((i-1)%2)*(cw+10*s),yy)
    end
    top=top+math.ceil(#langs/2)*52*s
    local name=f.language;for _,v in ipairs(require('src.translation.Languages')) do if v[1]==name then name=v[2];break end end
    button('languageNext',L('More languages')..' · '..L(name))
    para('Built-in game languages use your own matching language ROM. Japanese: Crystal. Korean: Gold and Silver. Additional launcher text can use on-device translation; a model download may be needed.')
  elseif f.page==2 then
    button('theme:default','RetroRecomped')
    local catalog=require('src.import.LauncherTheme')
    local cols=tw>=400*s and 2 or 1;local gap=10*s;local cw=(tw-gap*(cols-1))/cols
    for i,id in ipairs(catalog.PRESET_ORDER)do button('theme:'..id,catalog.PRESETS[id].label,cw,tx+((i-1)%cols)*(cw+gap),top+math.floor((i-1)/cols)*52*s)end
    top=top+math.ceil(#catalog.PRESET_ORDER/cols)*52*s
    para('Accent color')
    local choices={{'default','Edition default'},{'mint','Mint'},{'amber','Amber'},{'rose','Rose'}}
    -- Only offer accents present in the shared theme catalog.
    local theme=require('src.import.LauncherTheme')
    for _,v in ipairs(choices) do if v[1]=='default' or theme.ACCENTS[v[1]] then button('accent:'..v[1],v[2]) end end
  else
    if f.page==3 then
      para('Original cartridge images are an optional benefit for registered members with confirmed email.')
      para('Original cartridge images are served by ModCompass (about 20 MB for the current collection). Artwork belongs to Nintendo, Game Freak, Creatures and the respective rights holders. The source claims fair use; no reuse licence is granted. This downloads pictures, not games.')
      button('originalSources','REVIEW IMAGE SOURCES')
      button('originals',f.originals and '[x] ORIGINAL IMAGES NOW & FOR NEW GAMES' or '[ ] ORIGINAL IMAGES NOW & FOR NEW GAMES')
      para('Once enabled, missing original images are downloaded on this device after setup and when new supported games are added. Your custom designs are preserved. You can turn this off in the original cartridge collection.')
      if f.originals then
        if not require('src.import.CartridgeDownload').member()then
          para('Original cartridge images are a member benefit. Your saved automatic-download choice waits until you sign in and confirm your email.')
          button('login','SIGN IN FOR ORIGINAL IMAGES');button('register','REGISTER FOR ORIGINAL IMAGES')
        else
        local batch=self._cartBatch
        if batch and batch.running then button('stopOriginals','STOP IMAGE DOWNLOAD');para(require('src.translation.Service').launcherFormat('%d / %d images applied',batch.done or 0,batch.total or 0))
        else button('downloadOriginals','DOWNLOAD ORIGINAL IMAGES NOW');if batch and batch.notice then para(batch.notice)end end
        end
      end
    end
    if f.page==5 then
      para('WITHOUT AN ACCOUNT · Play imported games, save locally, import mod ZIPs and update installed mods.')
      para('WITH A CONFIRMED ACCOUNT · Cloud saves and private game cache, Bank and trading, friends and online battles, tournaments and gift codes, ModCompass browsing and installation, and original cartridge images. Cloud uploads remain optional.')
      button('register','CREATE AN ACCOUNT');button('login','SIGN IN');button('import','IMPORT MY GAMES') end
    for _,tip in ipairs(page.tips or {}) do para(tip) end
  end
  f.maxScroll=math.max(0,top+f.scroll-v.y-v.height)
  if f.follow then local r=f.rects[f.selected or 1];if r and not r.pinned then
    if r.y<v.y then f.scroll=math.max(0,f.scroll+r.y-v.y) elseif r.y+r.height>v.y+v.height then f.scroll=math.min(f.maxScroll,f.scroll+r.y+r.height-v.y-v.height) end
  end;f.follow=nil end
  g.setScissor()
  if f.maxScroll>0 then
    local track=math.max(12*s,v.height)
    local knob=math.max(24*s,track*v.height/(v.height+f.maxScroll))
    U.col(P.link,.16);g.rectangle('fill',v.x+v.width+10*s,v.y,3*s,track,2*s,2*s)
    U.col(P.link,.8);g.rectangle('fill',v.x+v.width+10*s,v.y+(track-knob)*math.min(1,f.scroll/f.maxScroll),3*s,knob,2*s,2*s)
  end
  local foot=y+h-66*s;local bw=(tw-20*s)/3
  button('back',f.page>1 and 'BACK' or 'WELCOME',bw,tx,foot,true)
  button('skip','SET UP LATER',bw,tx+bw+10*s,foot,true)
  button(f.page==#W.pages and 'done' or 'next',f.page==#W.pages and 'PLAY LOCALLY' or 'NEXT',bw,tx+2*(bw+10*s),foot,true)
  if f.notice then g.setFont(self.warningFont);U.col(P.warning);g.printf(L(f.notice),tx,foot-30*s,tw,'left') end
  g.pop()
end
function W.install(RI)
  local new=RI.new;RI.new=function(...)
    local self=new(...)
    if self.launcher and not self.forceImport and not self.toolFlow and not self.interruptedImport and (tonumber(self:_settings().launcherSetupVersion) or 0)<W.VERSION then self._setupPending=true end
    return self
  end
  local update=RI.update;RI.update=function(self,dt,...)
    if self._setupPending and not self._launcherSequence then self._setupPending=nil;W.open(self) end
    if self._setupOverlay and not self._launcherSequence then require('src.import.CartridgeBatch').tick(self);return end
    return update(self,dt,...)
  end
  local draw=RI.draw;RI.draw=function(self,...) draw(self,...);W.draw(self) end
  local press=RI.mousepressed;RI.mousepressed=function(self,x,y,b,...)
    local f=self._setupOverlay;if not f then return press(self,x,y,b,...) end
    if b~=1 then return end
    for _,r in ipairs(f.rects) do if (r.pinned or self._ui.inside(f.viewport,x,y)) and self._ui.inside(r,x,y) then W.action(self,r.id);return end end
  end
  local key=RI.keypressed;RI.keypressed=function(self,k,...)
    local f=self._setupOverlay;if not f then return key(self,k,...) end
    if k=='escape' then if f.page>1 then W.action(self,'back') else W.finish(self) end
    elseif k=='tab' or k=='down' or k=='right' then navigate(self,1)
    elseif k=='up' or k=='left' then navigate(self,-1)
    elseif k=='return' or k=='space' then local r=f.rects[f.selected];if r then W.action(self,r.id) end end
  end
  local pad=RI.gamepadpressed;RI.gamepadpressed=function(self,j,b,...)
    if not self._setupOverlay then return pad(self,j,b,...) end
    local k=({a='return',b='escape',dpup='up',dpdown='down',dpleft='left',dpright='right',start='return'})[b];if k then self:keypressed(k) end
  end
  local wheel=RI.wheelmoved;RI.wheelmoved=function(self,dx,dy,...) if self._setupOverlay then W.scroll(self,dy);return end;return wheel(self,dx,dy,...) end
  for _,method in ipairs({'touchpressed','touchmoved','touchreleased'}) do local original=RI[method]
    RI[method]=function(self,id,x,y,...)
      local f=self._setupOverlay;if not f then if original then return original(self,id,x,y,...) end;return end
      if method=='touchpressed' then if not f.touch then f.touch={id=id,x=x,y=y,startX=x,startY=y} end
      elseif method=='touchmoved' then local t=f.touch;if t and t.id==id then
        t.moved=t.moved or math.abs(x-t.startX)>8 or math.abs(y-t.startY)>8
        if t.moved then W.scroll(self,(y-t.y)/42) end;t.y=y
      end
      else local t=f.touch;if t and t.id==id then f.touch=nil
        if not t.moved and math.abs(x-t.startX)<=8 and math.abs(y-t.startY)<=8 then self:mousepressed(x,y,1) end
      end end
    end
  end
  for _,method in ipairs({'filedropped','textinput','mousereleased','gamepadaxis','joystickhat'}) do local original=RI[method]
    if original then RI[method]=function(self,...) if self._setupOverlay then return end;return original(self,...) end end
  end
  local rows=RI._launcherSettingsRows;RI._launcherSettingsRows=function(self,...)
    local result=rows(self,...);table.insert(result,2,{kind='action',label='SETUP & GUIDE',value='OPEN',action='setupGuide'});return result
  end
  local action=RI._settingsAction;RI._settingsAction=function(self,entry,...)
    if entry and entry.action=='setupGuide' then return W.open(self) end;return action(self,entry,...)
  end
  local category=RI._workspaceOpenCategory;RI._workspaceOpenCategory=function(self,id,...)
    if id=='setup' then return W.open(self) end;return category(self,id,...)
  end
end
return W
