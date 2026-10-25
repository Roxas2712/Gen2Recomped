local W={}
local Auth=require('src.cloud.RetroCloud')
local Developer=require('src.cloud.DeveloperProjects')
local Task=require('src.cloud.Task')
local function job(self,purpose,fn)
  local f=self._developerOverlay
  if f.job then return end
  local task,why=Task.new(fn);f.job=task;f.purpose=purpose;f.notice=task and 'Connecting to your ModCompass account...' or tostring(why)
end
function W.open(self,mode)
  if not Auth.signedIn() then return self:_openAccount(mode=='browse' and 'browse' or 'developer') end
  self._developerOverlay={mode=mode or 'developer',repository='',rects={},scroll=0,padIndex=2,page=1}
  job(self,'list',function() return Developer.list(1) end)
end
function W.close(self)
  local f=self._developerOverlay;if f and f.job then f.job:cancel() end
  self._developerOverlay=nil
  if love.keyboard and love.keyboard.setTextInput then love.keyboard.setTextInput(false) end
end
function W.coverBytes(self,bytes)
  local f=self._developerOverlay
  if not f or not f.profile or not f.profile.verified then return nil,'Select a verified repository first.' end
  if type(bytes)~='string' or #bytes>2*1024*1024 or not require('src.import.ImageBounds').allowed(bytes,2048) then f.notice='Use a PNG, JPEG or WebP up to 2048 pixels and 2 MB.';return nil,f.notice end
  local ok,image=pcall(function()
    local pixels=love.image.newImageData(love.filesystem.newFileData(bytes,'mod-cover.png'))
    if pixels:getWidth()<64 or pixels:getHeight()<64 then error('Use at least 64 pixels per side.') end
    local image=love.graphics.newImage(pixels);image:setFilter('linear','linear');return image
  end)
  if not ok then f.notice=tostring(image);return nil,f.notice end
  f.coverImage=image;f.coverBytes=bytes;f.coverRepository=f.profile.id;f.coverRights=false
  f.coverCredit=f.coverCredit or f.profile.repository;f.coverAlt=f.coverAlt or (f.profile.repository..' mod preview')
  f.notice='Cover loaded locally. Review the preview and image rights before uploading.';return true
end
function W.action(self,id)
  local f=self._developerOverlay;if not f then return end
  if id=='close' then W.close(self);return end
  f.focus=id=='repository' or id=='coverCredit' or id=='coverAlt'
  if f.focus then f.field=id end
  if love.keyboard and love.keyboard.setTextInput then love.keyboard.setTextInput(f.focus) end
  if f.focus then return end
  if f.job then return end
  if id=='refresh' then local page=f.page;job(self,'list',function() return Developer.list(page) end)
  elseif id=='previous' or id=='next' then
    local page=id=='previous' and math.max(1,f.page-1) or f.nextPage
    if page then job(self,'list',function() return Developer.list(page) end) end
  elseif id:match('^select:') then
    f.profile=f.projects[tonumber(id:sub(8))];f.repository=f.profile.repository
    f.coverImage=nil;f.coverBytes=nil;f.coverRights=false;f.coverCredit=nil;f.coverAlt=nil
  elseif id=='chooseCover' then
    local path=self._ui.chooseFileByExt({'png','jpg','jpeg','webp'},'mod cover image')
    if not path then f.notice='Drop a PNG, JPEG or WebP onto this developer window to preview your cover.';return end
    local file=io.open(path,'rb');if not file then f.notice='The image could not be read.';return end
    local bytes=file:read(2*1024*1024+1);file:close();W.coverBytes(self,bytes)
  elseif id=='coverRights' then f.coverRights=not f.coverRights
  elseif id=='uploadCover' then
    if not f.profile or f.coverRepository~=f.profile.id or not f.coverBytes then f.notice='Select a verified repository and choose its cover first.';return end
    if not f.coverRights then f.notice='Confirm that you may publish this image first.';return end
    local profile,bytes,credit,alt=f.profile,f.coverBytes,f.coverCredit,f.coverAlt
    job(self,'cover',function() return Developer.uploadCover(profile,bytes,credit,alt,true) end)
  elseif id=='rights' then f.rights=not f.rights
  elseif id=='agreement' then
    job(self,'policy',require('src.cloud.NativeAccount').policy)
  elseif id=='agreementBack' then f.agreement=nil;f.scroll=0
  elseif id=='save' then
    if not f.rights then f.notice='Read the developer confirmation and confirm your rights before linking a project.';return end
    if not f.policy then job(self,'policy',require('src.cloud.NativeAccount').policy);return end
    local value,version=f.repository,f.policy.version;job(self,'profile',function() return Developer.prepare(value,version) end)
  elseif id=='verify' and f.profile then local id=f.profile.id;job(self,'profile',function() return Developer.verify(id) end)
  elseif id=='github' then local url=Developer.proofUrl(f.profile);if url then love.system.openURL(url) end
  elseif id=='copy' and f.profile and f.profile.proof then love.system.setClipboardText(f.profile.proof);f.notice='Proof copied. Add it as .modcompass-developer.json in this repository.'
  elseif id=='browse' then W.close(self);self.findLoaded=false;self:_refreshFind(true) end
end
function W.tick(self)
  local f=self._developerOverlay;if not f then return end
  if f.job then
    local result=f.job:poll()
    if result then
      local purpose=f.purpose;f.job=nil
      if result.kind~='done' or not result.first then f.notice=tostring(result.error or result.second or 'Account unavailable.')
      elseif purpose=='list' then
        f.projects=result.first.repositories;f.page=result.first.page;f.nextPage=result.first.next_page;f.total=result.first.total;f.notice=nil
      elseif purpose=='policy' then f.policy=result.first;f.agreement=true;f.scroll=0
      elseif purpose=='cover' then
        if f.profile then f.profile.cover=result.first end
        f.coverRights=false;f.notice='Cover submitted · '..tostring(result.first.status)..'. It appears on the public mod card after review.'
      else
        f.profile=result.first;f.repository=result.first.repository or ''
        local found=false;for i,p in ipairs(f.projects or {}) do if p.id==f.profile.id then f.projects[i]=f.profile;found=true end end
        if not found then f.projects=f.projects or {};f.projects[#f.projects+1]=f.profile end
        f.notice=result.first.verified and 'Repository linked. Catalogue publication is reviewed separately.' or 'Proof prepared for this repository.'
      end
    end
  end
end
function W.navigate(self,step)
  local f=self._developerOverlay;if not f or #f.rects==0 then return end
  f.focus=false
  if love.keyboard and love.keyboard.setTextInput then love.keyboard.setTextInput(false) end
  f.padIndex=((f.padIndex or 2)-1+step)%#f.rects+1
  f.padActive=true
  local r=f.rects[f.padIndex];local v=f.viewport
  if v and not r.pinned then
    if r.y<v.y then f.scroll=math.max(0,f.scroll+r.y-v.y)
    elseif r.y+r.height>v.y+v.height then f.scroll=math.min(f.maxScroll or 0,f.scroll+r.y+r.height-v.y-v.height) end
  end
end
function W.scroll(self,dy)
  local f=self._developerOverlay;if not f then return end
  f.scroll=math.max(0,math.min(f.maxScroll or 0,(f.scroll or 0)-dy*45));f.padActive=false
end
function W.draw(self)
  local f=self._developerOverlay;if not f then return end
  local g=love.graphics;local ww,hh=g.getDimensions();local s=math.max(.65,math.min(ww/1050,hh/720,1.25))
  local width=math.min(800*s,ww-28*s);local height=math.min(650*s,hh-28*s);local x,y=(ww-width)/2,(hh-height)/2
  local U=self._ui;local p=self.palette()
  f.rects={};f.input=nil
  g.push('all');g.setCanvas();g.origin();g.setShader();g.setScissor();g.setBlendMode('alpha')
  g.setColor(.015,.025,.05,.92);g.rectangle('fill',0,0,ww,hh)
  g.setColor(.06,.09,.14,1);g.rectangle('fill',x,y,width,height,14*s,14*s)
  local function text(value,tx,ty,w,big)
    g.setFont(big and self.stateFont or self.hintFont);U.col(big and p.ink or p.detail);g.printf(value,tx,ty,w,'left')
  end
  local function button(label,bx,by,bw,id)
    local r=self:_chipButton(bx,by,label,{w=bw,h=38*s,kind='accent'});r.id=id;f.rects[#f.rects+1]=r;return r
  end
  text(f.mode=='browse' and 'MODCOMPASS · YOUR MOD LIBRARY' or 'RETRORECOMPED · MOD DEVELOPER',x+24*s,y+20*s,width-150*s,true)
  button('CLOSE',x+width-108*s,y+18*s,84*s,'close')
  local v={x=x+18*s,y=y+76*s,width=width-36*s,height=height-94*s};f.viewport=v
  local top=v.y-(f.scroll or 0)
  local function paragraph(value,big,gap)
    local font=big and self.stateFont or self.hintFont
    local _,lines=font:getWrap(value,width-48*s)
    text(value,x+24*s,top,width-48*s,big)
    top=top+math.max(1,#lines)*font:getHeight()+(gap or 18)*s
  end
  local function row(label,id)
    local _,lines=self.hintFont:getWrap(label,width-72*s)
    local h=math.max(38*s,#lines*self.hintFont:getHeight()+20*s)
    local r=self:_chipButton(x+24*s,top,'',{w=width-48*s,h=h,kind='accent'});r.id=id;f.rects[#f.rects+1]=r
    text(label,x+36*s,top+10*s,width-72*s);top=top+h+12*s
  end
  f.rects[1].pinned=true
  g.setScissor(v.x,v.y,v.width,v.height)
  paragraph('One account. Your saves, mod profile and developer projects across devices.')
  if f.agreement and f.policy then
    paragraph(f.policy.developer.title,true);paragraph(f.policy.developer.text);paragraph('Version '..f.policy.version);row('BACK TO MY REPOSITORIES','agreementBack')
  elseif f.mode=='browse' then
    paragraph('Connected as '..tostring(Auth.account()),true)
    row('OPEN MOD BROWSER','browse')
  else
    paragraph('Connected as '..tostring(Auth.account()))
    paragraph('MY PROJECTS · '..tostring(f.total or #(f.projects or {})),true)
    for i,project in ipairs(f.projects or {}) do row(project.repository..(project.verified and ' · LINKED' or ' · NEEDS PROOF'),'select:'..i) end
    if f.page>1 then row('PREVIOUS PROJECTS','previous') end
    if f.nextPage then row('MORE PROJECTS','next') end
    paragraph('ADD / SELECT A PUBLIC GITHUB REPOSITORY',false,10)
    f.input={x=x+24*s,y=top,width=width-48*s,height=46*s,id='repository'}
    f.rects[#f.rects+1]=f.input
    U.col(p.cardBlue);g.rectangle('fill',f.input.x,top,f.input.width,f.input.height,6*s,6*s)
    text((f.repository~='' and f.repository or 'author/my-mod')..(f.focus and ' |' or ''),x+34*s,top+12*s,width-68*s);top=top+58*s
    row('READ DEVELOPER CONFIRMATION','agreement')
    row((f.rights and '[x] ' or '[ ] ')..'I confirm my rights to submit this project','rights')
    button('PREPARE LINK',x+24*s,top,(width-60*s)/2,'save');button('REFRESH STATUS',x+36*s+(width-60*s)/2,top,(width-60*s)/2,'refresh');top=top+58*s
    if f.profile and f.profile.verified then
      paragraph('REPOSITORY LINKED',true)
      paragraph('Catalogue review: '..tostring(f.profile.review_status or 'pending review')..'. Linking a repository does not publish it automatically.')
      paragraph('MY MOD CARD COVER',true)
      if f.profile.cover then paragraph('Cover status: '..tostring(f.profile.cover.status)) end
      row('CHOOSE COVER IMAGE · PNG / JPEG / WEBP','chooseCover')
      if f.coverImage then
        local iw,ih=f.coverImage:getDimensions();local ph=170*s;local fit=math.min((width-48*s)/iw,ph/ih)
        g.setColor(1,1,1,1);g.draw(f.coverImage,x+width/2-iw*fit/2,top,0,fit,fit);top=top+ih*fit+18*s
        paragraph('Image credit and description',false,8)
        row('CREDIT · '..tostring(f.coverCredit or '')..(f.focus and f.field=='coverCredit' and ' |' or ''),'coverCredit')
        row('DESCRIPTION · '..tostring(f.coverAlt or '')..(f.focus and f.field=='coverAlt' and ' |' or ''),'coverAlt')
        paragraph('I hold the necessary rights and allow ModCompass and RetroRecomped to show this cover publicly for my mod. The image will be uploaded and reviewed separately.')
        row((f.coverRights and '[x] ' or '[ ] ')..'I confirm these image rights','coverRights')
        row('UPLOAD COVER FOR REVIEW','uploadCover')
      end
    elseif f.profile and f.profile.proof then
      paragraph('1 · Commit the prepared file on GitHub.  2 · Return here and verify.')
      row('1 · OPEN PREPARED GITHUB FILE >','github')
      row('2 · VERIFY REPOSITORY','verify');row('COPY FILE CONTENT','copy')
    end
  end
  paragraph(f.notice or '')
  f.maxScroll=math.max(0,top+(f.scroll or 0)-v.y-v.height)
  f.scroll=math.min(f.scroll or 0,f.maxScroll)
  local selected=f.padActive and f.rects[f.padIndex or 2]
  if selected and not selected.pinned then
    U.col(p.link);g.setLineWidth(2*s);g.rectangle('line',selected.x-3*s,selected.y-3*s,selected.width+6*s,selected.height+6*s,6*s,6*s)
  end
  g.setScissor()
  if selected and selected.pinned then
    U.col(p.link);g.setLineWidth(2*s);g.rectangle('line',selected.x-3*s,selected.y-3*s,selected.width+6*s,selected.height+6*s,6*s,6*s)
  end
  if f.maxScroll>0 then
    U.col(p.cardBlue);g.rectangle('fill',x+width-12*s,v.y,3*s,v.height,2*s,2*s)
    U.col(p.link);local th=math.max(20*s,v.height*v.height/(v.height+f.maxScroll))
    g.rectangle('fill',x+width-12*s,v.y+(v.height-th)*f.scroll/f.maxScroll,3*s,th,2*s,2*s)
  end
  g.pop()
end
function W.install(RI)
  local U=RI._ui
  function RI:_openDeveloper(mode) return W.open(self,mode) end
  local draw=RI.draw;RI.draw=function(self,...) draw(self,...);W.draw(self) end
  local update=RI.update;RI.update=function(self,dt,...) W.tick(self);return update(self,dt,...) end
  local press=RI.mousepressed
  RI.mousepressed=function(self,x,y,button,...)
    local f=self._developerOverlay
    if not f then return press(self,x,y,button,...) end
    if button~=1 then return end
    f.padActive=false
    for _,r in ipairs(f.rects) do if (r.pinned or U.inside(f.viewport,x,y)) and U.inside(r,x,y) then W.action(self,r.id);return end end
    f.focus=false;if love.keyboard and love.keyboard.setTextInput then love.keyboard.setTextInput(false) end
  end
  local key=RI.keypressed
  RI.keypressed=function(self,k,...)
    local f=self._developerOverlay;if not f then return key(self,k,...) end
    if k=='escape' then W.close(self)
    elseif k=='tab' then W.navigate(self,love.keyboard and love.keyboard.isDown('lshift','rshift') and -1 or 1)
    elseif f.focus then
      local field=f.field or 'repository';local limit=field=='repository' and 250 or field=='coverCredit' and 160 or 300
      if k=='backspace' then
        local value=f[field] or '';local start=value:match('()[%z\1-\127\194-\244][\128-\191]*$');f[field]=start and value:sub(1,start-1) or ''
        if field=='repository' then f.profile=nil end
      elseif k=='return' then f.focus=false;if field=='repository' then W.action(self,'save') end
      elseif k=='v' and love.keyboard and love.keyboard.isDown('lctrl','rctrl','lgui','rgui') then f[field]=(love.system.getClipboardText() or ''):sub(1,limit):gsub('[\r\n]','');if field=='repository' then f.profile=nil end end
    elseif k=='down' then W.navigate(self,1)
    elseif k=='up' then W.navigate(self,-1)
    elseif k=='return' or k=='space' then local r=f.rects[f.padIndex or 2];if r then W.action(self,r.id) end end
  end
  local input=RI.textinput;RI.textinput=function(self,t,...)
    local f=self._developerOverlay;if not f then return input(self,t,...) end
    if f.focus then
      local field=f.field or 'repository';local limit=field=='repository' and 250 or field=='coverCredit' and 160 or 300
      local value=field=='repository' and t:gsub('[^%w%p ]','') or t:gsub('[%z\1-\31\127]','')
      if #(f[field] or '')+#value<=limit then f[field]=(f[field] or '')..value end
      if field=='repository' then f.profile=nil end
    end
  end
  local drop=RI.filedropped;RI.filedropped=function(self,file,...)
    if not self._developerOverlay then return drop(self,file,...) end
    local ok,bytes=pcall(function()file:open('r');local data=file:read(2*1024*1024+1);file:close();return data end)
    if ok then W.coverBytes(self,bytes) else self._developerOverlay.notice='The cover image could not be read.' end
  end
  local touch=RI.touchpressed;RI.touchpressed=function(self,id,x,y,...)
    local f=self._developerOverlay;if not f then return touch(self,id,x,y,...) end
    if not f.touch then f.touch={id=id,x=x,y=y,startY=y} end
  end
  local moved=RI.touchmoved;RI.touchmoved=function(self,id,x,y,...)
    local f=self._developerOverlay;if not f then if moved then return moved(self,id,x,y,...) end;return end
    local t=f.touch;if not t or t.id~=id then return end
    if math.abs(y-t.startY)>8 then t.scrolling=true end
    if t.scrolling then W.scroll(self,(y-t.y)/45) end;t.x=x;t.y=y
  end
  local released=RI.touchreleased;RI.touchreleased=function(self,id,x,y,...)
    local f=self._developerOverlay;if not f then if released then return released(self,id,x,y,...) end;return end
    local t=f.touch;if not t or t.id~=id then return end
    f.touch=nil;if not t.scrolling then return self:mousepressed(x,y,1) end
  end
  local pad=RI.gamepadpressed
  RI.gamepadpressed=function(self,joystick,button,...)
    local f=self._developerOverlay;if not f then return pad(self,joystick,button,...) end
    if button=='b' then W.close(self)
    elseif button=='dpdown' then W.navigate(self,1)
    elseif button=='dpup' then W.navigate(self,-1)
    elseif button=='a' then local r=f.rects[f.padIndex or 2];if r then W.action(self,r.id) end end
  end
  local wheel=RI.wheelmoved;RI.wheelmoved=function(self,dx,dy,...) if self._developerOverlay then return W.scroll(self,dy) end;if wheel then return wheel(self,dx,dy,...) end end
  for _,method in ipairs({'mousereleased'}) do
    local original=RI[method];RI[method]=function(self,...) if self._developerOverlay then return end;if original then return original(self,...) end end
  end
  local play=RI.play;RI.play=function(self,...) if self._developerOverlay then W.close(self) end;return play(self,...) end
end
return W
