local W={}
local A=require('src.cloud.NativeAccount')
local Auth=require('src.cloud.RetroCloud')
local Task=require('src.cloud.Task')
local function inputMode(f,id)
  f.focus=id
  if love.keyboard and love.keyboard.setTextInput then love.keyboard.setTextInput(id~=nil) end
end
local function clearSecrets(f) f.password='';f.confirmation='';f.code='' end
local function job(self,purpose,fn)
  local f=self._accountOverlay;if f.job then return end
  local task,why=Task.new(fn);f.job=task;f.purpose=purpose
  f.notice=task and 'Connecting securely...' or tostring(why)
  inputMode(f,nil)
end
function W.open(self,after)
  if self._developerOverlay then require('src.import.DeveloperWorkspace').close(self) end
  self._accountOverlay={mode=Auth.signedIn() and 'account' or 'login',after=after,email='',name='',password='',confirmation='',code='',repositories={''},rects={},scroll=0}
  job(self,Auth.signedIn() and 'devices' or 'policy',Auth.signedIn() and A.devices or A.policy)
end
function W.close(self)
  local f=self._accountOverlay;if f then if f.job then f.job:cancel() end;clearSecrets(f);f.challenge=nil;inputMode(f,nil) end
  self._accountOverlay=nil
end
local function connected(self,f)
  -- Connecting an account never silently enables uploads or downloads.
  local settings=self:_settings();settings.cloudAutoSync=f.cloudSync==true
  if self._saveSettings then self:_saveSettings() end
  self._settingsRowCache=nil
  local after=f.after;W.close(self)
  if after=='developer' then self:_openDeveloper()
  elseif after=='browse' then self.findLoaded=false;self:_refreshFind(true)
  else W.open(self) end
end
function W.action(self,id)
  local f=self._accountOverlay;if not f then return end
  if id=='close' then W.close(self);return end
  if id=='back' and f.document then f.document=nil;f.scroll=0;return end
  if f.job then return end
  if id:match('^field:') then inputMode(f,id:sub(7));return end
  inputMode(f,nil)
  if id=='login' or id=='register' or id=='forgot' or id=='back' then
    clearSecrets(f);f.challenge=nil;f.mode=id=='back' and 'login' or id;f.scroll=0;f.notice=nil
    if id=='register' and not f.policy then job(self,'policy',A.policy) end
  elseif id:match('^read:') then
    if not f.policy then job(self,'policy',A.policy);return end
    f.document=id:sub(6);f.scroll=0
  elseif id:match('^toggle:') then local key=id:sub(8);f[key]=not f[key]
  elseif id=='addRepo' then f.repositories[#f.repositories+1]='';f.focus='repo'..#f.repositories;inputMode(f,f.focus)
  elseif id=='submit' then
    if f.mode=='login' then
      local email,password=f.email,f.password;job(self,'auth',function() return A.login(email,password) end);clearSecrets(f)
    elseif f.mode=='register' then
      if not f.policy then f.notice='Load the current terms before registering.';return end
      if not f.terms or not f.privacy or f.developer and not f.rights then f.notice='Please review and accept the required account agreements.';return end
      local repositories={};if f.developer then for _,r in ipairs(f.repositories) do if r:match('%S') then repositories[#repositories+1]=r end end end
      local payload={name=f.name,email=f.email,password=f.password,password_confirmation=f.confirmation,developer=f.developer==true,repositories=repositories,
        terms_version=f.policy.version,terms_accepted=f.terms==true,privacy_acknowledged=f.privacy==true,developer_rights_accepted=f.rights==true}
      job(self,'auth',function() return A.register(payload) end);clearSecrets(f)
    elseif f.mode=='forgot' then local email=f.email;job(self,'auth',function() return A.forgot(email) end)
    elseif f.mode=='reset_code' then
      local challenge,code,password,confirmation=f.challenge,f.code,f.password,f.confirmation
      job(self,'auth',function() return A.reset(challenge,code,password,confirmation) end);clearSecrets(f)
    elseif f.challenge then local challenge,code=f.challenge,f.code;job(self,'auth',function() return A.complete(challenge,code) end);clearSecrets(f) end
  elseif id=='resend' and f.challenge then local challenge=f.challenge;job(self,'resend',function() return A.resend(challenge) end)
  elseif id=='devices' then job(self,'devices',A.devices)
  elseif id:match('^revoke:') then
    local device=f.devices and f.devices[tonumber(id:sub(8))]
    if device then job(self,'revoke',function() local doc,why=A.revoke(device.id);if doc and device.current then Auth.expire() end;return doc,why end) end
  elseif id=='signout' then job(self,'signout',function() Auth.signOut();return {ok=true} end)
  elseif id=='developer' then W.close(self);self:_openDeveloper()
  elseif id=='browse' then W.close(self);self.findLoaded=false;self:_refreshFind(true)
  end
end
function W.tick(self)
  local f=self._accountOverlay;if not f or not f.job then return end
  local r=f.job:poll();if not r then return end
  local purpose=f.purpose;f.job=nil
  if r.kind~='done' or not r.first then f.notice=tostring(r.second or r.error or 'Account unavailable.');return end
  local doc=r.first
  if purpose=='policy' then f.policy=doc;f.notice=nil
  elseif purpose=='devices' then f.devices=doc.devices;f.notice=nil
  elseif purpose=='resend' then f.notice=doc.message or 'A fresh code was requested. Check your email.'
  elseif purpose=='signout' or purpose=='revoke' then
    if not Auth.signedIn() then f.mode='login';f.devices=nil;f.notice='This device is disconnected.'
    else job(self,'devices',A.devices) end
  elseif doc.state=='connected' then connected(self,f)
  elseif doc.state=='password_reset' then f.mode='login';f.challenge=nil;f.notice='Password updated. Sign in with your new password.';f.scroll=0
  elseif doc.challenge then
    f.mode=doc.state;f.challenge=doc.challenge;f.scroll=0
    f.notice=doc.state=='mfa_code' and 'Enter your authenticator code or a recovery code.' or 'Enter the eight-digit code from your ModCompass email. It expires after 15 minutes.'
  else f.notice='Account response incomplete. Please try again.' end
end
function W.scroll(self,dy)
  local f=self._accountOverlay;if f then f.scroll=math.max(0,math.min(f.maxScroll or 0,f.scroll-dy*45)) end
end
function W.navigate(self,step)
  local f=self._accountOverlay;if not f or #f.rects==0 then return end
  inputMode(f,nil);f.padIndex=((f.padIndex or 1)-1+step)%#f.rects+1;f.padActive=true
  local r=f.rects[f.padIndex];local v=f.viewport
  if not r.pinned then
    if r.y<v.y then f.scroll=math.max(0,f.scroll+r.y-v.y)
    elseif r.y+r.height>v.y+v.height then f.scroll=math.min(f.maxScroll or 0,f.scroll+r.y+r.height-v.y-v.height) end
  end
end
function W.draw(self)
  local f=self._accountOverlay;if not f then return end
  local g=love.graphics;local ww,hh=g.getDimensions();local s=math.max(.65,math.min(ww/1050,hh/720,1.25))
  local width=math.min(800*s,ww-28*s);local height=math.min(670*s,hh-28*s);local x,y=(ww-width)/2,(hh-height)/2
  local U,p=self._ui,self.palette();f.rects={}
  g.push('all');g.setCanvas();g.origin();g.setShader();g.setScissor();g.setBlendMode('alpha')
  g.setColor(.015,.025,.05,.96);g.rectangle('fill',0,0,ww,hh)
  g.setColor(.06,.09,.14,1);g.rectangle('fill',x,y,width,height,14*s,14*s)
  local function text(value,tx,ty,w,big)
    g.setFont(big and self.stateFont or self.hintFont);U.col(big and p.ink or p.detail);g.printf(value,tx,ty,w,'left')
  end
  local function button(label,bx,by,bw,id)
    local r=self:_chipButton(bx,by,label,{w=bw,h=38*s,kind='accent'});r.id=id;f.rects[#f.rects+1]=r;return r
  end
  text('RETRORECOMPED · YOUR ACCOUNT',x+24*s,y+20*s,width-150*s,true)
  button('CLOSE',x+width-108*s,y+18*s,84*s,'close').pinned=true
  local v={x=x+18*s,y=y+76*s,width=width-36*s,height=height-94*s};f.viewport=v
  local top=v.y-f.scroll
  local function paragraph(value,big)
    local font=big and self.stateFont or self.hintFont;local _,lines=font:getWrap(value,width-48*s)
    text(value,x+24*s,top,width-48*s,big);top=top+math.max(1,#lines)*font:getHeight()+16*s
  end
  local function row(label,id)
    local _,lines=self.hintFont:getWrap(label,width-72*s)
    local h=math.max(38*s,#lines*self.hintFont:getHeight()+20*s)
    local r=self:_chipButton(x+24*s,top,'',{w=width-48*s,h=h,kind='accent'});r.id=id;f.rects[#f.rects+1]=r
    text(label,x+36*s,top+10*s,width-72*s);top=top+h+12*s
  end
  local function check(label,key) row((f[key] and '[x] ' or '[ ] ')..label,'toggle:'..key) end
  local function field(label,key,secret)
    paragraph(label)
    local value=key:match('^repo(%d+)$') and f.repositories[tonumber(key:sub(5))] or f[key] or ''
    if secret then value=string.rep('*',math.min(#value,50)) end
    row((value~='' and value or '...')..(f.focus==key and ' |' or ''),'field:'..key)
  end
  g.setScissor(v.x,v.y,v.width,v.height)
  if f.document then
    local d=f.policy[f.document];if d then paragraph(d.title,true);paragraph(d.text);paragraph('Version '..f.policy.version) end
    row('BACK','back')
  elseif f.mode=='account' then
    paragraph('Connected as '..tostring(Auth.account()),true)
    paragraph('The same account connects your mods, developer projects and optional cloud storage.')
    row('BROWSE MODS','browse');row('MOD DEVELOPER · MY REPOSITORIES','developer');row('REFRESH CONNECTED DEVICES','devices')
    for i,d in ipairs(f.devices or {}) do paragraph(tostring(d.label)..(d.current and ' · THIS DEVICE' or ''));paragraph('Expires '..tostring(d.expires_at));row('DISCONNECT DEVICE','revoke:'..i) end
    row('SIGN OUT ON THIS DEVICE','signout')
  else
    paragraph('One account for RetroRecomped and ModCompass. Signing in links this device. Your password is never saved here.')
    if f.mode=='register' then
      paragraph('CREATE YOUR ACCOUNT',true);field('Nickname','name');field('Email','email');field('Password','password',true);field('Confirm password','confirmation',true)
      check('I develop mods','developer')
      if f.developer then
        paragraph('Add your public GitHub repositories. Each project gets its own control proof and catalogue review. You can add more later.')
        for i=1,#f.repositories do field('Repository '..i,'repo'..i) end
        row('+ ADD ANOTHER REPOSITORY','addRepo');row('READ DEVELOPER CONFIRMATION','read:developer');check('I confirm my rights to submit these projects','rights')
      end
      row('READ TERMS OF USE','read:terms');check('I accept the terms of use','terms')
      row('READ PRIVACY NOTICE','read:privacy');check('I have read the privacy notice','privacy')
      check('Enable automatic save sync on this device (optional)','cloudSync')
      paragraph('Mod profile sync and automatic mod downloads are separate settings. No ROMs or cartridge pictures are uploaded.')
      row('CREATE ACCOUNT · SEND EMAIL CODE','submit');row('ALREADY REGISTERED? SIGN IN','login')
    elseif f.mode=='login' then
      paragraph('WELCOME BACK',true);field('Email','email');field('Password','password',true)
      check('Enable automatic save sync on this device (optional)','cloudSync')
      row('SIGN IN & LINK THIS DEVICE','submit');row('CREATE AN ACCOUNT','register');row('FORGOT PASSWORD','forgot')
    elseif f.mode=='forgot' then paragraph('RECOVER YOUR ACCOUNT',true);field('Email','email');row('SEND RECOVERY CODE','submit');row('BACK TO SIGN IN','back')
    else
      paragraph(f.mode=='mfa_code' and 'TWO-FACTOR VERIFICATION' or 'CHECK YOUR EMAIL',true);field(f.mode=='mfa_code' and 'Authenticator / recovery code' or 'Email code','code')
      if f.mode=='reset_code' then field('New password','password',true);field('Confirm new password','confirmation',true) end
      row(f.mode=='reset_code' and 'UPDATE PASSWORD' or 'VERIFY & CONTINUE','submit')
      if f.mode~='mfa_code' then row('RESEND EMAIL CODE','resend') end
      row('START AGAIN','back')
    end
  end
  paragraph(f.notice or '')
  f.maxScroll=math.max(0,top+f.scroll-v.y-v.height);f.scroll=math.min(f.scroll,f.maxScroll)
  local selected=f.padActive and f.rects[f.padIndex or 1]
  if selected and not selected.pinned then U.col(p.link);g.setLineWidth(2*s);g.rectangle('line',selected.x-3*s,selected.y-3*s,selected.width+6*s,selected.height+6*s,6*s,6*s) end
  g.setScissor()
  if f.maxScroll>0 then
    U.col(p.cardBlue);g.rectangle('fill',x+width-12*s,v.y,3*s,v.height)
    U.col(p.link);local th=math.max(20*s,v.height*v.height/(v.height+f.maxScroll))
    g.rectangle('fill',x+width-12*s,v.y+(v.height-th)*f.scroll/f.maxScroll,3*s,th)
  end
  g.pop()
end
local function append(f,value)
  if not f.focus then return end
  value=value:gsub('[%c]','')
  local index=tonumber(f.focus:match('^repo(%d+)$'))
  local limit=(f.focus=='password' or f.focus=='confirmation') and 512 or 255
  if index then f.repositories[index]=(f.repositories[index]..value):sub(1,250)
  else f[f.focus]=((f[f.focus] or '')..value):sub(1,type(limit)=='number' and limit or 512) end
end
local function backspace(value) return (value:gsub('[%z\1-\127\194-\244][\128-\191]*$','')) end
function W.install(RI)
  local U=RI._ui
  function RI:_openAccount(after) return W.open(self,after) end
  local draw=RI.draw;RI.draw=function(self,...) draw(self,...);W.draw(self) end
  local update=RI.update;RI.update=function(self,dt,...) W.tick(self);return update(self,dt,...) end
  local press=RI.mousepressed;RI.mousepressed=function(self,x,y,b,...)
    local f=self._accountOverlay;if not f then return press(self,x,y,b,...) end
    if b~=1 then return end;f.padActive=false
    for _,r in ipairs(f.rects) do if (r.pinned or U.inside(f.viewport,x,y)) and U.inside(r,x,y) then W.action(self,r.id);return end end
    inputMode(f,nil)
  end
  local key=RI.keypressed;RI.keypressed=function(self,k,...)
    local f=self._accountOverlay;if not f then return key(self,k,...) end
    if k=='escape' then if f.document then W.action(self,'back') else W.close(self) end
    elseif k=='tab' then W.navigate(self,love.keyboard.isDown('lshift','rshift') and -1 or 1)
    elseif f.focus then
      if k=='backspace' then local index=tonumber(f.focus:match('^repo(%d+)$'));if index then f.repositories[index]=backspace(f.repositories[index]) else f[f.focus]=backspace(f[f.focus] or '') end
      elseif k=='return' then inputMode(f,nil)
      elseif k=='v' and love.keyboard.isDown('lctrl','rctrl','lgui','rgui') then append(f,love.system.getClipboardText() or '') end
    elseif k=='down' then W.navigate(self,1)
    elseif k=='up' then W.navigate(self,-1)
    elseif k=='return' or k=='space' then local r=f.rects[f.padIndex or 1];if r then W.action(self,r.id) end end
  end
  local input=RI.textinput;RI.textinput=function(self,t,...) if self._accountOverlay then append(self._accountOverlay,t);return end;return input(self,t,...) end
  local wheel=RI.wheelmoved;RI.wheelmoved=function(self,dx,dy,...) if self._accountOverlay then W.scroll(self,dy);return end;if wheel then return wheel(self,dx,dy,...) end end
  local touch=RI.touchpressed;RI.touchpressed=function(self,id,x,y,...)
    local f=self._accountOverlay;if not f then return touch(self,id,x,y,...) end
    if not f.touch then f.touch={id=id,x=x,y=y,startY=y} end
  end
  local moved=RI.touchmoved;RI.touchmoved=function(self,id,x,y,...)
    local f=self._accountOverlay;if not f then if moved then return moved(self,id,x,y,...) end;return end
    local t=f.touch;if t and t.id==id then if math.abs(y-t.startY)>8 then t.scrolling=true end;if t.scrolling then W.scroll(self,(y-t.y)/45) end;t.y=y end
  end
  local release=RI.touchreleased;RI.touchreleased=function(self,id,x,y,...)
    local f=self._accountOverlay;if not f then if release then return release(self,id,x,y,...) end;return end
    local t=f.touch;if t and t.id==id then f.touch=nil;if not t.scrolling then self:mousepressed(x,y,1) end end
  end
  local pad=RI.gamepadpressed;RI.gamepadpressed=function(self,j,b,...)
    if not self._accountOverlay then return pad(self,j,b,...) end
    if b=='b' then if self._accountOverlay.document then W.action(self,'back') else W.close(self) end
    elseif b=='dpdown' then W.navigate(self,1) elseif b=='dpup' then W.navigate(self,-1)
    elseif b=='a' then local f=self._accountOverlay;local r=f.rects[f.padIndex or 1];if r then W.action(self,r.id) end end
  end
  for _,name in ipairs({'mousereleased','mousemoved'}) do local original=RI[name];RI[name]=function(self,...) if self._accountOverlay then return end;if original then return original(self,...) end end end
  local play=RI.play;RI.play=function(self,...) if self._accountOverlay then W.close(self) end;return play(self,...) end
end
return W
