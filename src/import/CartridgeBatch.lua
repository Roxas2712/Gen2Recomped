-- Explicit or previously opted-in artwork batches. Custom designs are preserved.
local B={ORDER={},CONSENT=1}
local SaveData=require('src.core.SaveData')
local Sources=require('src.import.CartridgeSources')
local function scope() return require('src.storage.AccountStorage').scope() end
for _,version in ipairs(require('src.core.GameVersion').ORDER)do
 local source=Sources.get(version)
 if source and source.sha256 then B.ORDER[#B.ORDER+1]=version end
end
local catalogue={}
for _,version in ipairs(B.ORDER)do catalogue[#catalogue+1]=version..':'..Sources.get(version).sha256 end
B.KEY=table.concat(catalogue,'|')
function B.setAutomatic(self,enabled)
 local options=SaveData.loadOptions()
 options.launcherOriginalCartridges=enabled==true
 options.launcherOriginalCartridgesConsent=B.CONSENT
 if not SaveData.saveOptions(options)then return nil,'The cartridge preference could not be saved.'end
 self._settingsCache=nil;self._cartAutoChecked=nil;self._cartAutoPaused=nil
 if not enabled and self._cartBatch and self._cartBatch.automatic then B.cancel(self)end
 return true
end
function B.auto(self)
 if self._cartAutoPaused or not self.launcher or self._setupOverlay or self._cartDraft or self._cartDownload then return end
 if self._cartBatch and self._cartBatch.running then return end
 local options=self._settings and self:_settings()or SaveData.loadOptions()
 if options.launcherOriginalCartridges~=true or options.launcherOriginalCartridgesConsent~=B.CONSENT then return end
 local signature=tostring(scope())..'|'..B.KEY
 if self._cartAutoChecked==signature then return end
 if not require('src.import.CartridgeDownload').member()then return end
 self._cartAutoChecked=signature
 self._cartBatch={automatic=true,consent=true}
 B.start(self,true)
end

function B.available(version,design,exists)
  if type(design)~='table' or next(design)==nil then return true end
  local source=Sources.get(version)
  if design.originalSha256 and source and design.originalSha256==source.sha256 then
    return not (design.art and exists(design.art))
  end
  return false
end
function B.plan(designs,exists)
  designs=type(designs)=='table' and designs or {}
  local queue,skipped,bytes={},0,0
  for _,version in ipairs(B.ORDER) do
    if B.available(version,(designs or {})[version],exists) then queue[#queue+1]=version;bytes=bytes+(Sources.get(version).bytes or 0)
    else skipped=skipped+1 end
  end
  return queue,skipped,bytes
end
function B.start(self,confirmed)
  local f=self._cartBatch
  if not f or confirmed~=true or f.running then return end
  if not require('src.import.CartridgeDownload').member()then f.notice='Sign in with a confirmed account to download original cartridge images.';return end
  local options=SaveData.loadOptions()
  f.queue,f.skipped,f.bytes=B.plan(options.launcherCartDesigns,function(path) return love.filesystem.getInfo(path)~=nil end)
  f.total=#f.queue;f.done=0;f.failed={};f.running=true;f.owner=scope();f.notice=nil;f.cancelled=false
end
function B.cancel(self)
  local f=self._cartBatch;if not f then return end
  self._cartAutoPaused=true
  if f.job then f.job:cancel();f.job=nil end
  f.running=false;f.cancelled=true;f.current=nil
  f.notice='Stopped. Already applied cartridges are kept. Start again to load the remaining images.'
end
function B.tick(self)
  local f=self._cartBatch;if not f or not f.running then return end
  if scope()~=f.owner or not require('src.import.CartridgeDownload').member()then B.cancel(self);f.notice='The account changed. The batch stopped without editing another profile.';return end
  local function fail(version,why) f.failed[#f.failed+1]={version=version,reason=tostring(why)} end
  if f.job then
    local result=f.job:poll()
    if result then
      f.job=nil;local version=f.current;f.current=nil
      if result.kind~='done' then fail(version,result.error or 'Download cancelled.')
      else
        local options=SaveData.loadOptions();local designs=type(options.launcherCartDesigns)=='table' and options.launcherCartDesigns or {}
        if not B.available(version,designs[version],function(path) return love.filesystem.getInfo(path)~=nil end) then f.skipped=f.skipped+1
        else
          local ok,image,why=pcall(self._cartImageBytes,self,result.bytes)
          if not ok or not image then fail(version,ok and why or image)
          else
            local source=Sources.get(version)
            local path='launcher/cart_art/original_'..version..'_'..source.sha256:sub(1,16)..'.png'
            love.filesystem.createDirectory('launcher/cart_art')
            if not love.filesystem.write(path,image.bytes) then fail(version,'Could not save the image on this device.')
            else
              local style={};for k,v in pairs(designs[version] or {}) do style[k]=v end
              style.art=path;style.artMode='cartridge';style.artFit='contain';style.artZoom=1;style.artX=.5;style.artY=.5;style.originalSha256=source.sha256
              designs[version]=style;options.launcherCartDesigns=designs
              if SaveData.saveOptions(options) then f.done=f.done+1;self._settingsCache=nil;self._cartStyleCache=nil
              else fail(version,'The cartridge preference could not be saved.') end
            end
            if image.image and image.image.release then image.image:release() end
          end
        end
      end
    end
  end
  if not f.job then
    if #f.queue==0 then
      f.running=false;f.notice=require('src.translation.Service').launcherFormat('%d images applied · %d designs/already available skipped · %d failed.',f.done,f.skipped,#f.failed)
    else
      local version=table.remove(f.queue,1);f.current=version
      local job,why=require('src.import.CartridgeDownload').start(version,true);f.job=job
      if not job then fail(version,why);f.current=nil end
    end
  end
end
return B
