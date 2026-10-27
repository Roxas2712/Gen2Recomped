-- Cartridge Studio. Designs are application preferences, separate from ROMs,
-- mods and save slots. Custom artwork is decoded as pixels and stored as PNG.
local Designer = {}
local Strings = require('src.core.Strings')
local SaveData = require('src.core.SaveData')
local Sidebar = require('src.import.LauncherSidebar')
local Library = require('src.import.LauncherLibrary')
local Hardware = require('src.import.LauncherHardware')
local Sources = require('src.import.CartridgeSources')

Designer.SHELLS = {{126,211,225},{166,135,218},{231,178,92},{228,100,101},{103,165,238},{100,201,148},{214,217,224},{61,68,84}}
Designer.LABELS = {{32,52,65},{48,35,69},{65,47,28},{68,30,39},{24,39,71},{21,54,43},{54,58,67},{18,21,29}}
Designer.PATTERNS = {'orbit','bolt','pixels'}

local function rgb(value)
  if type(value)~='table' then return nil end
  local out={}
  for i=1,3 do
    local n=tonumber(value[i])
    if not n or n~=n then return nil end
    out[i]=math.max(0,math.min(255,math.floor(n)))
  end
  return out
end

function Designer.normalize(value)
  if type(value)~='table' then return {} end
  local name=tostring(value.name or ''):gsub('[%c]',''):sub(1,48)
  local ok,utf8=pcall(require,'utf8')
  if ok then while #name>0 and not utf8.len(name) do name=name:sub(1,-2) end end
  local pattern='orbit'
  for _,p in ipairs(Designer.PATTERNS) do if value.pattern==p then pattern=p end end
  local art=type(value.art)=='string' and value.art:match('^launcher/cart_art/[%w_%-]+%.png$') and value.art or nil
  local function bounded(n,lo,hi,fallback)
    n=tonumber(n);if not n or n~=n then return fallback end
    return math.max(lo,math.min(hi,n))
  end
  return {name=name,shell=rgb(value.shell),label=rgb(value.label),pattern=pattern,art=art,
    originalSha256=type(value.originalSha256)=='string' and #value.originalSha256==64 and value.originalSha256:match('^[a-f0-9]+$') and value.originalSha256 or nil,
    artMode=value.artMode=='cartridge' and 'cartridge' or 'label',
    artFit=value.artFit=='cover' and 'cover' or 'contain',artZoom=bounded(value.artZoom,1,3,1),
    artX=bounded(value.artX,0,1,.5),artY=bounded(value.artY,0,1,.5)}
end

local function same(a,b)
  return a and b and a[1]==b[1] and a[2]==b[2] and a[3]==b[3]
end

function Designer.install(RI)
  local U,paint=RI._ui,Library.paint
  local tool={id='cartDesign',label='Cartridge Studio',note='Design your own shell, label and artwork.'}
  Sidebar.TOOLS[#Sidebar.TOOLS+1]=tool
  local batchTool={id='cartBatch',label='Original cartridge collection',note='Load and apply all available originals in one batch.'}
  Sidebar.TOOLS[#Sidebar.TOOLS+1]=batchTool
  function RI:_openCartBatch()
    self._cartDraft=nil
    self.section='tools';self.settingsOpen=false;self.toolFlow={tool=batchTool,label=batchTool.label}
    self._cartBatch=self._cartBatch or {};self.pageScroll=0
    local options=SaveData.loadOptions();self._cartBatch.consent=self._cartBatch.consent or options.launcherOriginalCartridgesConsent==require('src.import.CartridgeBatch').CONSENT
  end

  function RI:_cartStyle(version)
    if self._cartDraft and self._cartDraft.version==version then
      local draft=self._cartDraft.style
      draft.image=self._cartDraft.image
      return draft
    end
    local opts=self:_settings()
    local saved=type(opts.launcherCartDesigns)=='table' and opts.launcherCartDesigns[version]
    self._cartStyleCache=self._cartStyleCache or {}
    local cache=self._cartStyleCache[version]
    if cache and cache.saved==saved then return cache.style end
    local style=Designer.normalize(saved)
    if style.art and love.filesystem.getInfo(style.art) then
      local ok,image=pcall(love.graphics.newImage,style.art)
      if ok then style.image=image;image:setFilter('linear','linear') end
    end
    self._cartStyleCache[version]={saved=saved,style=style}
    return style
  end

  function RI:_openCartDesigner(version)
    local style=Designer.normalize(self:_cartStyle(version))
    local shell,name=Library.edition(version)
    style.shell=style.shell or shell
    style.label=style.label or {27,39,53}
    if style.name=='' then style.name=name end
    self._cartDraft={version=version,style=style,image=self:_cartStyle(version).image}
    self.section='tools';self.settingsOpen=false
    self.toolFlow={tool=tool,label=tool.label,version=version}
    self.pageScroll=0;self._cartNameFocus=false
  end

  function RI:_cartImageBytes(bytes)
    if type(bytes)~='string' or #bytes>8*1024*1024 then return nil,'Use an image smaller than 8 MB.' end
    if not require('src.import.ImageBounds').allowed(bytes,2048) then return nil,'Use a supported image up to 2048 × 2048 pixels.' end
    local ok,data=pcall(function()
      return love.image.newImageData(love.filesystem.newFileData(bytes,'label.png'))
    end)
    if not ok then return nil,'This file could not be decoded as an image.' end
    if data:getWidth()>2048 or data:getHeight()>2048 then return nil,'Use artwork up to 2048 x 2048 pixels.' end
    local png=data:encode('png'):getString()
    local image=love.graphics.newImage(data);image:setFilter('linear','linear')
    return {bytes=png,image=image}
  end

  function RI:_cartImportImage()
    local draft=self._cartDraft
    if not draft then return end
    local path=U.chooseFileByExt({'png','jpg','jpeg'},'cartridge label image')
    if not path then draft.notice=Strings('Drop a PNG or JPEG onto the studio to use your own label.');return end
    local file=io.open(path,'rb')
    if not file then draft.notice=Strings('The selected image could not be read.');return end
    local bytes=file:read(8*1024*1024+1);file:close()
    local image,why=self:_cartImageBytes(bytes)
    if not image then draft.notice=Strings(why);return end
    draft.image,draft.png=image.image,image.bytes
    draft.style.originalSha256=nil
    if draft.referenceOpened or draft.originalOnly then draft.style.artMode='cartridge' end
    draft.notice=Strings('Artwork loaded. Save the design to keep it.')
  end

  function RI:_cartDownloadOriginal()
    local d=self._cartDraft
    if not d or self._cartDownload then return end
    local job,why=require('src.import.CartridgeDownload').start(d.version,d.originalConsent==true)
    if not job then d.notice=why;return end
    self._cartDownload={job=job,draft=d};d.notice='Downloading the original cartridge image...'
  end
  local function cancelDownload(self)
    if self._cartDownload then self._cartDownload.job:cancel();self._cartDownload=nil end
  end
  local update=RI.update
  RI.update=function(self,dt,...)
    local D=require('src.import.CartridgeDownload');D.reap()
    local batch=require('src.import.CartridgeBatch');batch.tick(self);batch.auto(self)
    local pending=self._cartDownload
    if pending then
      if self._cartDraft~=pending.draft then cancelDownload(self)
      else
        local result=pending.job:poll()
        if result then
          self._cartDownload=nil
          local d=pending.draft
          if result.kind=='done' then
            local ok,image,why=pcall(self._cartImageBytes,self,result.bytes)
            if ok and image then d.image=image.image;d.png=image.bytes;d.style.artMode='cartridge';d.style.originalSha256=Sources.get(d.version).sha256;d.originalConsent=nil
              d.notice='Original image loaded. Save the design to use it in your library.'
            else d.notice=tostring(ok and why or image) end
          else d.notice='Direct download is unavailable. The image host may require browser verification. Open the image source in your browser, save the full-size image, then import it here. '..tostring(result.error or '') end
        end
      end
    end
    return update(self,dt,...)
  end

  function RI:_cartSaveDesign()
    local draft=self._cartDraft
    if not draft then return false end
    local design=Designer.normalize(draft.style)
    if draft.png then
      love.filesystem.createDirectory('launcher/cart_art')
      local path=('launcher/cart_art/%s_%s.png'):format(draft.version,tostring(os.time())..'_'..tostring(math.random(100000,999999)))
      local ok=love.filesystem.write(path,draft.png)
      if not ok then draft.notice=Strings('The artwork could not be saved.');return false end
      design.art=path
    end
    -- Always reload: other launcher tools may have updated options meanwhile.
    local opts=SaveData.loadOptions()
    opts.launcherCartDesigns=type(opts.launcherCartDesigns)=='table' and opts.launcherCartDesigns or {}
    opts.launcherCartDesigns[draft.version]=design
    if not SaveData.saveOptions(opts) then draft.notice=Strings('The design could not be saved.');return false end
    self._settingsCache=nil;self._cartStyleCache=nil
    draft.style=design;draft.png=nil
    draft.notice=Strings('Design saved. It is now used in your library and at launch.')
    return true
  end

  local run=RI._sbRunTool
  RI._sbRunTool=function(self,selected,version,...)
    if selected.id=='cartBatch' then return self:_openCartBatch() end
    if selected.id=='cartDesign' then return self:_openCartDesigner(version) end
    return run(self,selected,version,...)
  end

  local tools=RI._sbTools
  RI._sbTools=function(self,x,y,w,h)
    if self.toolFlow and self.toolFlow.tool.id=='cartBatch' and self._cartBatch then
      local f=self._cartBatch;local s,p,g=self._s,RI.palette(),love.graphics
      local yy=y;self._cartBatchControls={};local function L(value)return require('src.translation.Service').launcherLookup(value)end
      local function paragraph(value)
        value=L(value);g.setFont(self.hintFont);U.col(p.detail);g.printf(value,x,yy,w,'left')
        local _,lines=self.hintFont:getWrap(value,w);yy=yy+#lines*self.hintFont:getHeight()+18*s
      end
      local function button(id,label)
        local r=self:_chipButton(x,yy,label,{w=w,h=44*s,kind='accent'});r.id=id;self._cartBatchControls[#self._cartBatchControls+1]=r;yy=yy+56*s
      end
      paint.label(self,'ALL ORIGINAL CARTRIDGES',x,yy,p.link);yy=yy+38*s
      paragraph('Load the original cartridge photographs in one batch. Original PNG quality, served by ModCompass. Existing artwork and custom designs are preserved. A confirmed member account is required. No ROM is downloaded.')
      button('automatic',SaveData.loadOptions().launcherOriginalCartridges and '[x] AUTOMATICALLY LOAD MISSING ORIGINALS' or '[ ] AUTOMATICALLY LOAD MISSING ORIGINALS')
      paragraph('Sources: Bulbagarden Archives · TheMalevolentOne / UnethicalVoxel. Cartridge artwork belongs to its respective rights holders, including Nintendo, Game Freak and Creatures. The source claims fair use; downloading grants no reuse licence. Review your permitted use. Images remain on this device.')
      if f.running then
        paragraph(require('src.translation.Service').launcherFormat('%d / %d applied · now loading %s',f.done or 0,f.total or 0,f.current and require('src.translation.Service').editionName(f.current)or L('next cartridge')))
        local progress=((f.total or 0)-#(f.queue or {})-(f.job and 1 or 0))/math.max(1,f.total or 1)
        U.col(p.link,.25);g.rectangle('fill',x,yy,w,8*s,4*s,4*s);U.col(p.link);g.rectangle('fill',x,yy,w*progress,8*s,4*s,4*s);yy=yy+26*s
        button('cancel','STOP BATCH · KEEP COMPLETED IMAGES')
      else
        button('consent',f.consent and '[x] I HAVE CHECKED MY PERMITTED USE' or '[ ] I HAVE CHECKED MY PERMITTED USE')
        if f.consent then button('start','LOAD & APPLY ALL MISSING ORIGINALS') end
      end
      if f.notice then paragraph(f.notice) end
      for _,failed in ipairs(f.failed or {}) do paragraph(failed.version..': '..failed.reason) end
      button('library','BACK TO LIBRARY')
      return yy-y
    end
    local d=self._cartDraft
    if not (self.toolFlow and self.toolFlow.tool.id=='cartDesign' and self.toolFlow.version and d) then
      return tools(self,x,y,w,h)
    end
    local g,s,p=love.graphics,self._s,RI.palette()
    self._cartControls={}
    if d.originalOnly then
      local function control(id,label,yy,kind)
        local r=self:_chipButton(x,yy,label,{w=w,h=42*s,kind=kind})
        r.id=id;self._cartControls[#self._cartControls+1]=r
      end
      local yy=y
      paint.label(self,'ORIGINAL CARTRIDGE ARTWORK',x,yy,p.link);yy=yy+30*s
      local ph=230*s
      paint.surface(x,yy,w,ph,16*s,p.link,false)
      Hardware.cartridge(self,d.version,x+w/2,yy+ph/2,w-48*s,ph-30*s,-.08,{customLabel=true})
      yy=yy+ph+18*s
      local source=Sources.get(d.version)
      local rights='Original '..d.style.name..' cartridge photograph. Source: '..source.publisher..'; contributor: '..tostring(source.credit or 'see source')..'. Download served by '..source.delivery..' at '..tostring(source.width or '?')..' × '..tostring(source.height or '?')..' pixels. Artwork belongs to its respective rights holders, including Nintendo, Game Freak and Creatures. Check the source terms and your permitted use. Downloading grants no reuse licence. The image stays on this device.'
      g.setFont(self.hintFont);U.col(p.detail);g.printf(rights,x,yy,w,'left')
      local _,lines=self.hintFont:getWrap(rights,w);yy=yy+#lines*self.hintFont:getHeight()+16*s
      control('source','VIEW IMAGE SOURCE ↗',yy);self._cartControls[#self._cartControls].value=source.page;yy=yy+52*s
      control('consent',d.originalConsent and '[x] I HAVE CHECKED MY PERMITTED USE' or '[ ] I HAVE CHECKED MY PERMITTED USE',yy);yy=yy+52*s
      if self._cartDownload then control('cancelDownload','CANCEL DOWNLOAD',yy);yy=yy+52*s
      elseif d.originalConsent then
        control('downloadOriginal','CONFIRM & DOWNLOAD ORIGINAL',yy,'accent');yy=yy+52*s
        control('browserDownload','DOWNLOAD IN BROWSER ↗',yy);self._cartControls[#self._cartControls].value=source.image;yy=yy+52*s
      end
      control('image','IMPORT DOWNLOADED IMAGE',yy);yy=yy+52*s
      if d.image then control('save','USE THIS CARTRIDGE IN MY LIBRARY',yy,'accent');yy=yy+52*s end
      if d.notice then
        g.setFont(self.hintFont);U.col(p.link);g.printf(d.notice,x,yy,w,'left')
        local _,noticeLines=self.hintFont:getWrap(d.notice,w);yy=yy+#noticeLines*self.hintFont:getHeight()+16*s
      end
      return yy-y+16*s
    end
    local wide=w>=680*s
    local previewW=wide and w*0.42 or w
    local previewH=wide and 460*s or 280*s
    paint.surface(x,y,previewW,previewH,16*s,p.link,false)
    paint.label(self,'YOUR CUSTOM CARTRIDGE',x+22*s,y+22*s,p.link)
    Hardware.cartridge(self,d.version,x+previewW/2,y+previewH*0.53,previewW-64*s,previewH-110*s,-0.16,{customLabel=true})
    paint.text(self,self.hintFont,Strings('Live preview / saved per game'),x+22*s,y+previewH-35*s,previewW-44*s,p.warning)
    local ex=wide and x+previewW+24*s or x
    local ey=wide and y or y+previewH+20*s
    local ew=wide and w-previewW-24*s or w
    local top=ey
    local function control(id,value,rect) rect.id=id;rect.value=value;self._cartControls[#self._cartControls+1]=rect end
    paint.label(self,'LABEL TEXT',ex,ey);ey=ey+26*s
    local name={x=ex,y=ey,width=ew,height=42*s}
    paint.surface(ex,ey,ew,42*s,8*s,p.link,self._cartNameFocus)
    paint.text(self,self.stateFont,d.style.name..(self._cartNameFocus and '|' or ''),ex+14*s,ey+11*s,ew-28*s)
    control('name',nil,name);ey=ey+66*s
    local function swatches(title,id,values,current)
      paint.label(self,title,ex,ey);ey=ey+27*s
      local size=math.min(34*s,(ew-7*7*s-92*s)/8)
      for i,c in ipairs(values) do
        local sx=ex+(i-1)*(size+7*s)
        U.col(c);g.rectangle('fill',sx,ey,size,size,7*s,7*s)
        if same(c,current) then U.col(p.ink);g.setLineWidth(2*s);g.rectangle('line',sx-2*s,ey-2*s,size+4*s,size+4*s,8*s,8*s);g.setLineWidth(1) end
        control(id,c,{x=sx,y=ey,width=size,height=size})
      end
      local hx=ex+ew-84*s
      local r={x=hx,y=ey,width=84*s,height=size}
      paint.surface(hx,ey,r.width,r.height,6*s,p.link,self._cartColorFocus==id)
      local value=self._cartColorFocus==id and (d.hex or '')..'|' or ('%02X%02X%02X'):format(current[1],current[2],current[3])
      paint.text(self,self.warningFont,'#'..value,hx+5*s,ey+(size-self.warningFont:getHeight())/2,76*s,p.detail)
      control(id..'Hex',id,r)
      ey=ey+size+26*s
    end
    swatches('SHELL COLOR','shell',Designer.SHELLS,d.style.shell)
    swatches('LABEL COLOR','label',Designer.LABELS,d.style.label)
    paint.label(self,'LABEL EMBLEM',ex,ey);ey=ey+26*s
    local bw=(ew-16*s)/3
    for i,id in ipairs(Designer.PATTERNS) do
      local r=self:_chipButton(ex+(i-1)*(bw+8*s),ey,id:upper(),{w=bw,h=34*s,kind=d.style.pattern==id and not d.image and 'accent' or 'neutral'})
      control('pattern',id,r)
    end
    ey=ey+54*s
    local reference=Sources.get(d.version)
    if reference then
      local download=self:_glassyButton(ex,ey,ew,42*s,self._cartDownload and 'CANCEL ARTWORK DOWNLOAD' or 'DOWNLOAD ORIGINAL CARTRIDGE IMAGE',self.hintFont,true)
      control(self._cartDownload and 'cancelDownload' or 'original',nil,download);ey=ey+54*s
      if d.showOriginalConsent then
        local rights='Source: '..reference.publisher..' · '..tostring(reference.credit or 'see source')..'. Served by '..reference.delivery..'. Original image bytes; no added compression. Artwork belongs to its respective rights holders, including Nintendo, Game Freak and Creatures. Downloading does not grant a reuse licence. The image is stored only on this device.'
        g.setFont(self.hintFont);U.col(p.detail);g.printf(rights,ex,ey,ew,'left')
        local _,lines=self.hintFont:getWrap(rights,ew);ey=ey+#lines*self.hintFont:getHeight()+14*s
        control('consent',nil,self:_chipButton(ex,ey,d.originalConsent and '[x] I HAVE CHECKED MY PERMITTED USE' or '[ ] I HAVE CHECKED MY PERMITTED USE',{w=ew,h=38*s}));ey=ey+48*s
        if d.originalConsent then control('downloadOriginal',nil,self:_chipButton(ex,ey,'CONFIRM & DOWNLOAD',{w=ew,h=42*s,kind='accent'}));ey=ey+54*s end
      end
      local source=self:_glassyButton(ex,ey,ew,38*s,'Original cartridge: image source ↗',self.hintFont,true)
      control('source',reference.page,source);ey=ey+50*s
      local help=Strings('View the source, or download directly above after confirming the rights notice.')
      paint.text(self,self.hintFont,help,ex,ey,ew,p.detail)
      local _,lines=self.hintFont:getWrap(help,ew);ey=ey+#lines*self.hintFont:getHeight()+14*s
    end
    local upload=self:_glassyButton(ex,ey,ew,38*s,'Import your own cartridge image',self.hintFont,true)
    control('image',nil,upload);ey=ey+52*s
    paint.text(self,self.hintFont,Strings('Use your own PNG/JPEG, or choose the original image above. Artwork stays on this device.'),ex,ey,ew,p.detail)
    local _,helpLines=self.hintFont:getWrap(Strings('Use your own PNG/JPEG, or choose the original image above. Artwork stays on this device.'),ew)
    ey=ey+#helpLines*self.hintFont:getHeight()+14*s
    if d.image then
      local half=(ew-10*s)/2
      control('artMode','label',self:_chipButton(ex,ey,'LABEL ART',{w=half,h=34*s,kind=d.style.artMode~='cartridge' and 'accent' or 'neutral'}))
      control('artMode','cartridge',self:_chipButton(ex+half+10*s,ey,'WHOLE CARTRIDGE',{w=half,h=34*s,kind=d.style.artMode=='cartridge' and 'accent' or 'neutral'}));ey=ey+44*s
      local bw=(ew-20*s)/3
      control('artFit',d.style.artFit=='cover' and 'contain' or 'cover',self:_chipButton(ex,ey,d.style.artFit=='cover' and 'FILL / CROP' or 'FIT IMAGE',{w=bw,h=34*s}))
      control('zoom',-.15,self:_chipButton(ex+bw+10*s,ey,'ZOOM −',{w=bw,h=34*s}))
      control('zoom',.15,self:_chipButton(ex+2*(bw+10*s),ey,'ZOOM +',{w=bw,h=34*s}));ey=ey+44*s
      local pw=(ew-30*s)/4
      for i,v in ipairs({{'←','artX',-.1},{'→','artX',.1},{'↑','artY',-.1},{'↓','artY',.1}}) do
        control('pan',v,self:_chipButton(ex+(i-1)*(pw+10*s),ey,v[1],{w=pw,h=34*s}))
      end
      ey=ey+48*s
    end
    local save=self:_chipButton(ex,ey,'SAVE DESIGN',{w=(ew-10*s)*0.62,h=42*s,kind='accent'})
    local reset=self:_chipButton(ex+(ew-10*s)*0.62+10*s,ey,'RESET',{w=(ew-10*s)*0.38,h=42*s})
    control('save',nil,save);control('reset',nil,reset);ey=ey+56*s
    if d.notice then
      g.setFont(self.hintFont);U.col(p.link);local _,lines=self.hintFont:getWrap(d.notice,ew)
      g.printf(d.notice,ex,ey,ew,'left');ey=ey+#lines*self.hintFont:getHeight()+12*s
    end
    return math.max(previewH,ey-y,ey-top)+16*s
  end

  local mouse=RI._sbMousepressed
  RI._sbMousepressed=function(self,x,y)
    if self.section=='tools' and self.toolFlow and self.toolFlow.tool.id=='cartBatch' and self._cartBatch then
      for _,r in ipairs(self._cartBatchControls or {}) do if U.inside(r,x,y) then
        local f=self._cartBatch
        if r.id=='consent' then f.consent=not f.consent
        elseif r.id=='automatic' then
          local batch=require('src.import.CartridgeBatch');local enabled=SaveData.loadOptions().launcherOriginalCartridges~=true
          if enabled and not f.consent then f.notice='Confirm the artwork source and rights notice first.'
          else local ok,why=batch.setAutomatic(self,enabled);if not ok then f.notice=why end end
        elseif r.id=='start' then require('src.import.CartridgeBatch').start(self,f.consent)
        elseif r.id=='cancel' then require('src.import.CartridgeBatch').cancel(self)
        elseif r.id=='library' then self:_sbGo('games') end
        return true
      end end
    end
    if self.section=='games' then
      if U.inside(self._sb and self._sb.cartBatch,x,y) then self:_openCartBatch();return true end
      for _,r in ipairs(self._sb and self._sb.cartArt or {}) do
        if U.inside(r,x,y) then self:_openCartDesigner(r.version);self._cartDraft.originalOnly=true;return true end
      end
    end
    local quick=self._sb and self._sb.designCart
    if quick and self.section=='games' and U.inside(quick,x,y) then
      self:_openCartDesigner(quick.version)
      self._cartDraft.originalOnly=Sources.get(quick.version)~=nil
      return true
    end
    if self.section=='tools' and self.toolFlow and self.toolFlow.tool.id=='cartDesign' and self._cartDraft then
      for _,r in ipairs(self._cartControls or {}) do
        if U.inside(r,x,y) then
          local d=self._cartDraft
          self._cartNameFocus=r.id=='name'
          self._cartColorFocus=(r.id=='shellHex' or r.id=='labelHex') and r.value or nil
          if self._cartColorFocus then d.hex='' end
          if self._cartNameFocus or self._cartColorFocus then self:_armTextInput() else self:_disarmTextInput() end
          if r.id=='shell' or r.id=='label' then d.style[r.id]=r.value
          elseif r.id=='pattern' then d.style.pattern=r.value;d.style.art=nil;d.image=nil;d.png=nil
          elseif r.id=='image' then self:_cartImportImage()
          elseif r.id=='original' then d.showOriginalConsent=not d.showOriginalConsent;d.originalConsent=false
          elseif r.id=='consent' then d.originalConsent=not d.originalConsent
          elseif r.id=='downloadOriginal' then self:_cartDownloadOriginal()
          elseif r.id=='cancelDownload' then cancelDownload(self);d.notice='Artwork download cancelled.'
          elseif r.id=='browserDownload' and d.originalConsent then
            love.system.openURL(r.value);d.referenceOpened=true
            d.notice='Save the full-size image in your browser, then choose Import downloaded image here.'
          elseif r.id=='source' then
            love.system.openURL(r.value);d.referenceOpened=true
            d.notice=Strings('Save the full-size image from the source page, then choose Import your own cartridge image. Images are not freely licensed merely because they can be downloaded.')
          elseif r.id=='artMode' or r.id=='artFit' then d.style[r.id]=r.value
          elseif r.id=='zoom' then d.style.artZoom=math.max(1,math.min(3,(d.style.artZoom or 1)+r.value))
          elseif r.id=='pan' then d.style[r.value[2]]=math.max(0,math.min(1,(d.style[r.value[2]] or .5)+r.value[3]))
          elseif r.id=='save' then self:_cartSaveDesign()
          elseif r.id=='reset' then
            local shell,name=Library.edition(d.version)
            d.style={name=name,shell=shell,label={27,39,53},pattern='orbit'};d.image=nil;d.png=nil
            d.notice=Strings('Default restored in the preview. Save to apply it.')
          end
          return true
        end
      end
    end
    if self._cartNameFocus or self._cartColorFocus then self._cartNameFocus=false;self._cartColorFocus=nil;self:_disarmTextInput() end
    return mouse(self,x,y)
  end

  local text=RI.textinput
  RI.textinput=function(self,value,...)
    if self._cartColorFocus and self._cartDraft then
      self._cartDraft.hex=((self._cartDraft.hex or '')..value:gsub('[^%x]','')):sub(1,6):upper();return
    end
    if self._cartNameFocus and self._cartDraft then
      self._cartDraft.style.name=Designer.normalize({name=self._cartDraft.style.name..value}).name
      return
    end
    return text(self,value,...)
  end
  local key=RI.keypressed
  RI.keypressed=function(self,value,...)
    if self._cartColorFocus and self._cartDraft then
      local d=self._cartDraft
      if value=='backspace' then d.hex=(d.hex or ''):sub(1,-2)
      elseif value=='return' then
        if #(d.hex or '')==6 then
          d.style[self._cartColorFocus]={tonumber(d.hex:sub(1,2),16),tonumber(d.hex:sub(3,4),16),tonumber(d.hex:sub(5,6),16)}
          self._cartColorFocus=nil;self:_disarmTextInput()
        else d.notice=Strings('Enter a six-digit RGB color, for example 7ED3E1.') end
      elseif value=='escape' then self._cartColorFocus=nil;self:_disarmTextInput() end
      return
    end
    if self._cartNameFocus and self._cartDraft then
      if value=='backspace' then
        local str=self._cartDraft.style.name
        local off=require('utf8').offset(str,-1)
        self._cartDraft.style.name=off and str:sub(1,off-1) or ''
      elseif value=='return' or value=='escape' then self._cartNameFocus=false;self:_disarmTextInput() end
      return
    end
    return key(self,value,...)
  end
  local back=RI._sbBack
  RI._sbBack=function(self,...)
    cancelDownload(self)
    if self._cartDraft then self._cartDraft=nil;self._cartNameFocus=false;self._cartColorFocus=nil;self:_disarmTextInput() end
    return back(self,...)
  end
  local go=RI._sbGo
  RI._sbGo=function(self,...)
    cancelDownload(self)
    self._cartDraft=nil;self._cartNameFocus=false;self._cartColorFocus=nil
    return go(self,...)
  end
  local drop=RI.filedropped
  RI.filedropped=function(self,file,...)
    if self._cartDraft and self.section=='tools' then
      local ok,bytes=pcall(function() file:open('r');local b=file:read(8*1024*1024+1);file:close();return b end)
      local image,why=self:_cartImageBytes(ok and bytes or nil)
      if image then self._cartDraft.image=image.image;self._cartDraft.png=image.bytes
        self._cartDraft.style.originalSha256=nil
        if self._cartDraft.referenceOpened then self._cartDraft.style.artMode='cartridge' end
        self._cartDraft.notice=Strings('Artwork loaded. Save the design to keep it.')
      else self._cartDraft.notice=Strings(why) end
      return
    end
    if drop then return drop(self,file,...) end
  end
end

return Designer
