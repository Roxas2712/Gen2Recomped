-- ModCompass provides public catalogue facts. The original GitHub manifest
-- and release remain the authority for IDs, versions and installable ZIPs.
local C={URL='https://pokexpert.de',FEED='https://pokexpert.de/api/launcher/index.json'}
local Index=require('src.mods.ModIndex')
local Update=require('src.mods.ModUpdate')
local Http=require('src.cloud.Http')
local Json=require('src.link.Json')
local SaveData=require('src.core.SaveData')
local Task=require('src.cloud.Task')
local Download=require('src.mods.ModDownload')
local Auth=require('src.cloud.RetroCloud')
local function get(url)
  local headers={Accept='application/json',['User-Agent']='RetroRecomped/1.0'}
  local status,body=Http.request('GET',url,{headers=headers})
  if status==401 and url==C.FEED and Auth.expire then Auth.expire() end
  if status~=200 or type(body)~='string' or #body>4*1024*1024 then
    return nil,'Catalogue request failed ('..tostring(status or 'offline')..').'
  end
  return body
end
local function cacheIndex(source,force)
  local cached=Index.readCache(source.feed)
  if not force and Index.cacheFresh(cached) then return cached end
  local body,why=get(source.feed)
  if not body and source.fallback then body,why=get(source.fallback) end
  local parsed,err
  if body then parsed,err=Index.parse(body) end
  if parsed then Index.writeCache(source.feed,parsed);return parsed end
  if cached then cached.stale=true;return cached end
  return nil,err or why
end
function C.resolve(entry,doc)
  if type(doc)~='table' or type(doc.id)~='string' or #doc.id>128 or not doc.id:match('^[%w_%-][%w_.%-]*$')
    or type(entry.github)~='string' or not entry.github:match('^[%w%-]+/[%w_.%-]+$') or entry.github:find('..',1,true)
    or type(doc.releases)~='table' then return nil end
  local prefix='https://github.com/'..entry.github..'/releases/download/'
  local releases={}
  local Semver=require('src.mods.Semver')
  for _,release in ipairs(doc.releases) do
    local zip=type(release)=='table' and release.zip
    if type(release.version)~='string' or not Semver.parse(release.version)
      or type(zip)~='table' or type(zip.url)~='string' or zip.url:sub(1,#prefix):lower()~=prefix:lower()
      or type(zip.name)~='string' or not zip.name:lower():match('%.zip$') then return nil end
    if zip.size~=nil and (not tonumber(zip.size) or tonumber(zip.size)<=0) then return nil end
    zip.size=tonumber(zip.size)
    releases[#releases+1]=release
  end
  table.sort(releases,function(a,b) return Semver.compare(a.version,b.version)>0 end)
  entry.id=doc.id
  if doc.api then entry.api=tonumber(doc.api) end
  if type(doc.game_version)=='string' then entry.game_version=doc.game_version end
  if type(doc.games)=='table' then entry.games=doc.games end
  entry.latest=Update.pickBest(releases)
  entry.releases=releases
  for _,field in ipairs({'dependencies','conflicts','permissions'}) do if type(doc[field])=='table' then entry[field]=doc[field] end end
  entry.update_check=entry.latest and entry.latest.zip and 'ok' or 'no installable release'
  entry._communityResolved=true
  C.catalogueRevision=(C.catalogueRevision or 0)+1
  return true
end
function C.describe(entry)
  local body=entry.description or entry.summary or ''
  if entry.github then body=body..'\n\nRepository: '..entry.github end
  if entry.thumbnailCredit then body=body..'\nPreview image: '..entry.thumbnailCredit end
  if entry.sourceChecked then body=body..'\nCatalogue checked: '..entry.sourceChecked end
  if entry.game_version then body=body..'\nEngine: '..entry.game_version end
  if entry.games and #entry.games>0 then body=body..'\nGames: '..table.concat(entry.games,', ') end
  if entry.permissions and #entry.permissions>0 then body=body..'\nPermissions: '..table.concat(entry.permissions,', ') end
  if entry.latest then
    body=body..'\n\nLATEST INSTALLABLE RELEASE · '..tostring(entry.latest.version)
    if entry.latest.zip and entry.latest.zip.size then body=body..string.format(' · %.1f MB',entry.latest.zip.size/1048576) end
    body=body..'\n'..Update.cleanBody(entry.latest.body or '',12000)
  end
  if entry.update_check and entry.update_check:match('^error:') then body=body..'\n\n'..entry.update_check end
  local status,note=C.compatibility(entry)
  return 'RETRORECOMPED · '..status..'\n'..note..'\n\n'..body
end
function C.compatibility(entry,game)
  local V=require('src.core.Version')
  if entry.api and (entry.api<1 or entry.api>V.modApi) then return 'INCOMPATIBLE','Requires a different mod API.' end
  if entry.game_version then
    local ok,matches,why=pcall(require('src.mods.Semver').satisfies,V.engine,entry.game_version)
    if not ok or why then return 'NOT VERIFIED','Engine requirements are not documented as a readable version range.' end
    if not matches then return 'INCOMPATIBLE','Requires engine '..tostring(entry.game_version)..'; this build is '..V.engine..'.' end
  end
  if game and entry.games and #entry.games>0 then
    local targets=require('src.mods.ModTargets').normalize(entry.games)
    if not require('src.mods.ModTargets').supports({games=targets},game) then return 'OTHER GAMES','This release does not declare support for the selected game.' end
  end
  if not entry._communityResolved or not entry.api or not entry.game_version then
    return 'NOT VERIFIED','Compatibility information is incomplete. Check the project notes before installing.'
  end
  return 'MANIFEST MATCH','Engine/API requirements match. This is a metadata check, not a completed gameplay test.'
end
function C.weekCompatible(entry)
  local version=require('src.core.Version')
  return entry and entry._communityResolved and entry.latest and entry.latest.zip and not entry.latest.prerelease
    and type(entry.api)=='number' and entry.api>=1 and entry.api<=version.modApi
    and type(entry.game_version)=='string' and require('src.mods.Semver').satisfies(version.engine,entry.game_version) or false
end
function C.videoUrl(video)
  return type(video)=='table' and type(video.id)=='string' and #video.id==11 and video.id:match('^[%w_%-]+$') and ('https://www.youtube.com/watch?v='..video.id) or nil
end
function C.enrich(self)
  local receipts=SaveData.loadOptions().modInstallSources or {}
  local byRepo={}
  for _,entry in ipairs(self.findIndex and self.findIndex.mods or {}) do
    if entry.github then byRepo[entry.github:lower()]=entry end
  end
  for _,mod in ipairs(self.mods or {}) do
    local receipt=receipts[mod.id]
    if receipt and receipt.version==mod.version and type(receipt.repo)=='string' then mod.github=receipt.repo end
    if receipt and receipt.version==mod.version then mod.packageHash=receipt.sha256 end
    local entry=mod.github and byRepo[mod.github:lower()]
    if entry then
      mod._originalDescription=mod._originalDescription or mod.description or ''
      mod.description=mod._originalDescription..'\n\nModCompass: '..entry.summary
      mod.catalogueUrl=entry.projectUrl
    end
  end
end
local function updateCacheKey(mod) return mod.github:lower()..'#'..mod.id end
function C.pumpUpdates(self)
  local task=self._communityUpdateJob
  if task then
    local result=task:poll()
    if result then
      self._communityUpdateJob=nil
      local mod=self._communityUpdating;self._communityUpdating=nil
      if mod then
        for _,row in ipairs(self.mods or {}) do
          if row.github and row.github:lower()==mod.github:lower() and row.updateCheck~=false then
            local releases,why
            if result.kind=='done' and result.first then releases,why=Update.parseReleases(result.first,row.id) end
            if releases then
              Update.writeCache(updateCacheKey(row),releases)
              local status,best=Update.statusFor(row.version,releases)
              self.modUpdateInfo[row.id]={status=status,best=best,latest=best and best.version,releases=releases,checkedAt=os.time()}
            else
              local info=self.modUpdateInfo[row.id] or {status='error'}
              info.err=tostring(result.error or result.second or why);self.modUpdateInfo[row.id]=info
            end
          end
        end
      end
    end
  end
  if not self._communityUpdateJob and self._communityUpdateQueue and #self._communityUpdateQueue>0 then
      local mod=table.remove(self._communityUpdateQueue,1);self._communityUpdating=mod
      local task,why=Task.new(function()
        local body,why=get(Update.apiReleasesUrl(mod.github))
        if not body then return nil,why end
        return body
      end)
      self._communityUpdateJob=task
      if not task then
        self.modUpdateInfo[mod.id]={status='error',err=tostring(why)}
        self.modNotice={ok=false,text='Repository check unavailable: '..tostring(why)}
      end
  end
end
function C.backgroundUpdates()
  local owner=C._updateOwner
  if not owner then return end
  local ok,why=pcall(C.pumpUpdates,owner)
  if not ok then
    if owner._communityUpdateJob then owner._communityUpdateJob:cancel() end
    owner._communityUpdateJob=nil;owner._communityUpdateQueue={}
    owner.modNotice={ok=false,text='Repository update check stopped: '..tostring(why)}
  end
  if not owner._communityUpdateJob and #(owner._communityUpdateQueue or {})==0 then C._updateOwner=nil end
end
function C.install(RI)
  local U=RI._ui
  local refresh=RI._refreshMods
  RI._refreshMods=function(self,...)
    refresh(self,...);C.enrich(self);self:_syncModUpdateInfo(false)
  end
  local details=RI._findShowDetails
  RI._findShowDetails=function(self,entry,...)
    if not entry.catalogueId then return details(self,entry,...) end
    self._findDetails={title=entry.title or entry.id,body=C.describe(entry),scroll=0,communityEntry=entry}
  end
  local sources=RI._refreshFindSources
  RI._refreshFindSources=function(self,...)
    sources(self,...)
    local opts=self:_settings()
    if opts.modCompassEnabled~=false then
      local found=false
      for _,source in ipairs(self.findSources or {}) do if source.feed==C.FEED then found=true end end
      if not found then table.insert(self.findSources,1,{feed=C.FEED,base=C.URL..'/',label='ModCompass · pokexpert.de'}) end
    end
  end
  local remove=RI._removeIndex
  RI._removeIndex=function(self,feed,...)
    if feed==C.FEED then
      local opts=SaveData.loadOptions();opts.modCompassEnabled=false;SaveData.saveOptions(opts)
      self._settingsCache=nil;self.findLoaded=false;return
    end
    return remove(self,feed,...)
  end
  function RI:_refreshFind(force)
    if self._communityFindJob then self._communityFindJob:cancel();self._communityFindJob=nil end
    if self._communityResolveJob then self._communityResolveJob:cancel();self._communityResolveJob=nil end
    if not Auth.signedIn() then
      self._findNeedsLogin=true;self.findLoaded=true;self.findIndex={mods={},categories={}}
      self._communityResolveQueue={};self._communityQueued={}
      self.findNotice={ok=false,text='Sign in to browse and install new online mods. Local play, manual imports and updates to installed mods work without an account.'}
      return
    end
    self._findNeedsLogin=nil
    self:_refreshFindSources()
    self._communityQueued={};self._communityResolveQueue={};self._communityResolving=nil
    self.findLoaded=true
    self.findIndex=self.findIndex or {mods={},categories={}}
    self.findNotice={ok=true,text='Loading ModCompass and your mod indexes...'}
    local sourceList=self.findSources
    local task,why=Task.new(function()
      local result={mods={},categories={}}
      local seen,categories={},{}
      local errors={}
      for _,source in ipairs(sourceList) do
        local index,err=cacheIndex(source,force)
        if index then
          if source.feed==C.FEED then result.week=index.week end
          for _,entry in ipairs(index.mods or {}) do
            if not seen[entry.id] then
              seen[entry.id]=true;entry._source=source.label;entry._base=source.base
              if entry.catalogueId then entry.summary=Update.previewLine(entry.summary,220) end
              result.mods[#result.mods+1]=entry
            end
          end
          for _,category in ipairs(Index.categoriesIn(index)) do
            if not categories[category] then categories[category]=true;result.categories[#result.categories+1]=category end
          end
          result.stale=result.stale or index.stale
        else errors[#errors+1]=(source.label or source.feed)..': '..tostring(err) end
      end
      return result,#errors>0 and table.concat(errors,' · ') or nil
    end)
    self._communityFindJob=task
    if not task then self.findNotice={ok=false,text=tostring(why)} end
  end
  local confirm=RI._findConfirmInstall
  RI._findConfirmInstall=function(self,entry,...)
    if not Auth.signedIn() then self.findNotice={ok=false,text='Sign in or register to install. This links this device to your ModCompass account. A confirmed email is required; the launcher does not require a second factor.'};if self._openAccount then self:_openAccount() end;return end
    if not entry.catalogueId then return confirm(self,entry,...) end
    if self._communityLatestJob or self._communityDownload then
      self.findNotice={ok=false,text='A release check or download is already running.'};return
    end
    self._findDetails=nil;self._communityConfirmPending=entry
    self.findNotice={ok=true,text='ModCompass is checking the newest installable ZIP...'}
    self._communityLatestJob=Task.new(function()
      local url=entry.resolveUrl..'/latest'
      if url:sub(1,#C.URL+19)~=C.URL..'/api/launcher/mods/' then return nil,'Invalid catalogue endpoint.' end
      local body,why=get(url);if not body then return nil,why end
      local ok,doc=pcall(Json.decode,body);return ok and doc or nil,'Invalid release response.'
    end)
    if not self._communityLatestJob then self._communityConfirmPending=nil;self.findNotice={ok=false,text='Background release checks are unavailable in this build.'} end
  end
  local function notice(self,text,ok)
    self.findNotice={text=text,ok=ok};self.modNotice={text=text,ok=ok}
  end
  function RI:_communityStartDownload(id,release,title,repo)
    local guestUpdate=false
    if not Auth.signedIn() then
      local permitted,why=require('src.mods.ModAccess').checkUpdate(id,release,repo)
      if not permitted then notice(self,why,false);return end
      guestUpdate=true
    end
    if self._profileApplying or self._profileRecoveryBlocked then notice(self,'Complete or recover the cloud mod profile first.',false);return end
    if self._communityDownload then notice(self,'A mod is already downloading.',false);return end
    local job,why=Download.start(release)
    if not job then notice(self,tostring(why),false);return end
    self._communityDownload={job=job,id=id,release=release,title=title or id,repo=repo,phase='download',bytes=0,guestUpdate=guestUpdate}
    notice(self,'Downloading '..(title or id)..' inside RetroRecomped...',true)
  end
  function RI:_findInstall(entry)
    local release,why=Index.releaseFor(entry)
    if not release then notice(self,tostring(why),false);return end
    self:_communityStartDownload(entry.id,release,entry.title,entry.github)
  end
  function RI:_confirmModUpdate(id,release)
    local repo
    for _,mod in ipairs(self.mods or {}) do if mod.id==id then repo=mod.github end end
    self:_communityStartDownload(id,release,id,repo)
  end
  function RI:_installModVersion(id,release)
    self._modVersions=nil;self._modReleaseNotes=nil;return self:_confirmModUpdate(id,release)
  end
  function RI:_communityCancelDownload()
    local state=self._communityDownload
    if state then
      state.job:cancel();self._communityDownload=nil
      notice(self,'Download cancelled. Installed mods are unchanged.',true)
    end
  end
  local play=RI.play
  RI.play=function(self,...)
    self:_communityCancelDownload()
    for _,field in ipairs({'_communityLatestJob','_communityFindJob','_communityResolveJob'}) do
      if self[field] then self[field]:cancel();self[field]=nil end
    end
    return play(self,...)
  end
  -- Resolve only cards actually visible, rather than querying every repo in
  -- the catalogue. Search and scrolling naturally select the next cards.
  local thumb=RI._findThumb
  RI._findThumb=function(self,entry,...)
    if not Auth.signedIn() then return nil end
    if entry.catalogueId and not entry._communityResolved and entry.resolveUrl
      and entry.resolveUrl:sub(1,#C.URL+19)==C.URL..'/api/launcher/mods/' then
      self._communityResolveQueue=self._communityResolveQueue or {}
      self._communityQueued=self._communityQueued or {}
      if not self._communityQueued[entry.catalogueId] then
        self._communityQueued[entry.catalogueId]=true
        self._communityResolveQueue[#self._communityResolveQueue+1]=entry
      end
    end
    if entry.catalogueId then
      self._communityImages=self._communityImages or {}
      local imageKey=entry.catalogueId..':'..tostring(entry.thumbnail or '')
      local cached=self._communityImages[imageKey]
      if cached~=nil then return cached or nil end
      self._communityImageJobs=self._communityImageJobs or {}
      local active=0;for _ in pairs(self._communityImageJobs) do active=active+1 end
      if not self._communityImageJobs[imageKey] and active<3 then
        local job=require('src.import.CartridgeDownload').preview(entry.thumbnail)
        if job then self._communityImageJobs[imageKey]=job
        else self._communityImages[imageKey]=false end
      end
      return nil
    end
    return thumb(self,entry,...)
  end
  local function resolveEntry(entry)
    local options=SaveData.loadOptions()
    local cached=options.modCompassReleaseCache and options.modCompassReleaseCache[entry.catalogueId]
    if cached and os.time()-(tonumber(cached.at) or 0)<Update.CACHE_TTL then return cached.doc end
    local body,why=get(entry.resolveUrl)
    if not body then return nil,why end
    local ok,doc=pcall(Json.decode,body)
    if not ok or type(doc)~='table' then return nil,'Invalid repository response.' end
    options=SaveData.loadOptions();options.modCompassReleaseCache=options.modCompassReleaseCache or {}
    options.modCompassReleaseCache[entry.catalogueId]={at=os.time(),doc=doc}
    SaveData.saveOptions(options)
    return doc
  end
  -- Replace the old synchronous automatic checks with real background I/O.
  function RI:_syncModUpdateInfo(force)
    if force and self._communityUpdateJob then self._communityUpdateJob:cancel();self._communityUpdateJob=nil;self._communityUpdating=nil end
    if C._updateOwner and C._updateOwner~=self then
      if C._updateOwner._communityUpdateJob then C._updateOwner._communityUpdateJob:cancel() end
      C._updateOwner._communityUpdateQueue={}
    end
    C._updateOwner=self
    self.modUpdateInfo=self.modUpdateInfo or {}
    self._communityUpdateQueue={}
    local queued={}
    if self._communityUpdateJob and self._communityUpdating then queued[self._communityUpdating.github:lower()]=true end
    for _,mod in ipairs(self.mods or {}) do
      if mod.github and mod.updateCheck~=false and mod.github:match('^[%w_.%-]+/[%w_.%-]+$') then
        local cached=Update.readCache(updateCacheKey(mod))
        if cached then
          local status,best=Update.statusFor(mod.version,cached.releases)
          self.modUpdateInfo[mod.id]={status=status,best=best,latest=best and best.version,releases=cached.releases,checkedAt=cached.checkedAt}
        end
        if (force or not Update.cacheFresh(cached)) and not queued[mod.github:lower()] then
          queued[mod.github:lower()]=true;self._communityUpdateQueue[#self._communityUpdateQueue+1]=mod
        end
      end
    end
  end
  local function paintLinks(self,x,y,w)
    local s=self._s
    local h=34*s
    self._communityLinks={}
    local first=self:_chipButton(x,y,'MY ACCOUNT',{h=h,w=math.min(w*.49,200*s),kind='accent'})
    first.action='account';self._communityLinks[#self._communityLinks+1]=first
    local second=self:_chipButton(x+math.min(w*.49,200*s)+10*s,y,'DEVELOPER PROFILE',{h=h,w=math.min(w*.47,230*s)})
    second.action='developer';self._communityLinks[#self._communityLinks+1]=second
    local used=h+12*s
    local state=self._communityDownload
    self._communityCancelRect=nil
    if state then
      local total=tonumber(state.release.zip.size)
      local bytes=state.bytes or 0
      local label=state.phase=='install' and ('Installing '..state.title..'...')
        or ('Downloading '..state.title..' · '..string.format('%.1f',bytes/1048576)..' MB'..(total and (' / '..string.format('%.1f',total/1048576)..' MB') or ''))
      love.graphics.setFont(self.hintFont);U.col(RI.palette().link)
      love.graphics.printf(label,x,y+used,math.max(60,w-110*s),'left')
      if state.phase=='download' then self._communityCancelRect=self:_chipButton(x+w-100*s,y+used,'CANCEL',{w=100*s,h=30*s}) end
      local bar=y+used+40*s
      U.col(RI.palette().cardBorder,.35);love.graphics.rectangle('fill',x,bar,w,5*s,2*s,2*s)
      U.col(RI.palette().link);love.graphics.rectangle('fill',x,bar,w*(state.phase=='install' and 1 or total and math.min(1,bytes/total) or .1),5*s,2*s,2*s)
      used=used+62*s
    end
    return used
  end
  for _,method in ipairs({'_drawFindPanel','_drawModsPanel'}) do
    local original=RI[method]
    RI[method]=function(self,x,y,w,h,...)
      local used=paintLinks(self,x,y,w)
      self._communityGateRect=nil
      if method=='_drawFindPanel' and self._findNeedsLogin and Auth.signedIn() then self:_refreshFind(true) end
      local week=require('src.import.LauncherPresentation').week(self)
      self._communityWeekRect=nil
      if week then
        for _,entry in ipairs(self.findIndex.mods or {}) do if entry.catalogueId==week.catalogue_id then
          if not entry._communityResolved then self:_findThumb(entry) end
          if C.weekCompatible(entry) then
            local r=self:_chipButton(x,y+used,'MOD OF THE WEEK · '..entry.title,{w=w,h=48*self._s,kind='accent'})
            r.entry=entry;self._communityWeekRect=r;used=used+60*self._s
          end
          break
        end end
      end
      return used+original(self,x,y+used,w,h-used,...)
    end
  end
  local press=RI._sbMousepressed
  RI._sbMousepressed=function(self,x,y,...)
    if self.section=='mods' then
      if self._communityGateRect and U.inside(self._communityGateRect,x,y) then self:_openDeveloper('browse');return true end
      if self._communityWeekRect and U.inside(self._communityWeekRect,x,y) then self:_findShowDetails(self._communityWeekRect.entry);return true end
      if self._communityCancelRect and U.inside(self._communityCancelRect,x,y) then self:_communityCancelDownload();return true end
      for _,rect in ipairs(self._communityLinks or {}) do
        if U.inside(rect,x,y) then if rect.action=='developer' then self:_openDeveloper('developer') elseif rect.action=='account' then self:_openAccount() else love.system.openURL(rect.url) end;return true end
      end
    end
    return press(self,x,y,...)
  end
  local update=RI.update
  RI.update=function(self,dt,...)
    if not Auth.signedIn() then
      if self._communityFindJob or self._communityResolveJob or self.findIndex and #(self.findIndex.mods or {})>0 then self:_refreshFind() end
      if self._communityLatestJob then self._communityLatestJob:cancel();self._communityLatestJob=nil;self._communityConfirmPending=nil end
      for id,job in pairs(self._communityImageJobs or {}) do if job.cancel then job:cancel() end;self._communityImageJobs[id]=nil end
      local download=self._communityDownload
      if download and (download.phase=='install' or not download.guestUpdate) then
        local permitted=require('src.mods.ModAccess').checkUpdate(download.id,download.release,download.repo)
        if not permitted then
          if download.phase=='install' and download.path then love.filesystem.remove(download.path) end
          self:_communityCancelDownload()
        else download.guestUpdate=true end
      end
    end
    require('src.import.LauncherPresentation').update(self)
    Download.reap()
    require('src.import.CartridgeDownload').reap()
    for id,job in pairs(self._communityImageJobs or {}) do
      local result=job:poll()
      if result then
        self._communityImageJobs[id]=nil
        local image=false
        if result.kind=='done' then
          local ok,value=pcall(function()
            if not require('src.import.ImageBounds').allowed(result.bytes,2048) then return false end
            local pixels=love.image.newImageData(love.filesystem.newFileData(result.bytes,'preview.png'))
            if pixels:getWidth()>2048 or pixels:getHeight()>2048 then return false end
            local value=love.graphics.newImage(pixels);value:setFilter('linear','linear');return value
          end)
          if ok then image=value end
        end
        self._communityImages[id]=image
      end
    end
    if self._launcherSequence then return update(self,dt,...) end
    local download=self._communityDownload
    if download then
      if download.phase=='install' then
        local installed,version,mismatch=require('src.mods.LauncherMods').installFromRelease(download.id,download.release,download.path)
        self._communityDownload=nil
        if installed then
          if download.repo then
            local options=SaveData.loadOptions();options.modInstallSources=options.modInstallSources or {}
            options.modInstallSources[download.id]={repo=download.repo,version=version,tag=download.release.tag,sha256=download.digest}
            SaveData.saveOptions(options)
          end
          self:_refreshMods();notice(self,mismatch or ('Installed '..download.title..' '..tostring(version)..'. Enable it in Installed mods.'),not mismatch)
        else notice(self,'Install failed: '..tostring(version),false) end
      else
        local result=download.job:poll()
        if result.kind=='done' then download.phase='install';download.path=result.path;download.bytes=result.bytes;download.digest=result.digest
        elseif result.kind=='progress' then download.bytes=result.bytes
        else self._communityDownload=nil;notice(self,tostring(result.error or 'Download cancelled.'),false) end
      end
    end
    local function pump(key,done)
      local task=self[key]
      if task then
        local result=task:poll()
        if result then self[key]=nil;done(result) end
      end
    end
    pump('_communityLatestJob',function(result)
      local entry=self._communityConfirmPending;self._communityConfirmPending=nil
      if entry and result.kind=='done' and C.resolve(entry,result.first) then
        self._findDetails=nil;confirm(self,entry)
      else notice(self,'Could not resolve the latest ZIP: '..tostring(result.error or result.second),false) end
    end)
    pump('_communityFindJob',function(result)
      if result.kind=='done' and result.first then
        self.findIndex=result.first;self.findCategory=nil
        self.findNotice=result.second and {ok=false,text=result.second} or {ok=true,text='ModCompass · '..#result.first.mods..' mods. Releases are checked from the original repositories.'}
        C.enrich(self)
      else self.findNotice={ok=false,text=tostring(result.error or result.second)} end
    end)
    pump('_communityResolveJob',function(result)
      local entry=self._communityResolving;self._communityResolving=nil
      if entry then
        if result.kind~='done' or not C.resolve(entry,result.first) then
          entry._communityResolved=true;entry.update_check='error: '..tostring(result.error or result.second or 'Repository unavailable')
        end
      end
    end)
    if Auth.signedIn() and not self._communityResolveJob and self.section=='mods' and self._communityResolveQueue and #self._communityResolveQueue>0 then
      local entry=table.remove(self._communityResolveQueue,1)
      self._communityResolving=entry
      self._communityResolveJob=Task.new(function() return resolveEntry(entry) end)
    end
    C.backgroundUpdates()
    if self.section=='mods' and not self.findLoaded then self:_ensureFind() end
    return update(self,dt,...)
  end
end
return C
