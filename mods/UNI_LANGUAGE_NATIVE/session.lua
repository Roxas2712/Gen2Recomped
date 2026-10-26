return function(mod,version,own)
 local Engine=own('session_engine.lua')
 local Lifecycle=require('src.core.SessionLifecycle')
 local Runtime=require('src.mods.Runtime')
 local prefs=own('preferences.lua')(mod)
 local locales=own('locales.lua');local labels=own('session_locales.lua')
 local manifest
 local catalog=own('catalog.lua');local requirements=own('rom_requirements.lua')
 local backupPath='baseroms/.uni-language-recovery-'..version..'.bin'
 -- Personal recovery belongs to the mod profile: retained on update, removed
 -- by uninstall. Compilation caches remain disposable and contain no saves.
 local recovery={}
 function recovery:read()return mod:read(backupPath)end
 function recovery:info()return mod:info(backupPath)end
 local function backupCall(method,bytes)
  local C=require('src.import.CacheFs');local previous=C.prefix;C.prefix=''
  local ok,result,err=pcall(C[method],mod.path..'/'..backupPath,bytes)
  C.prefix=previous
  if not ok then return nil,result end
  return result,err
 end
 function recovery:write(_,bytes)
  local ok,err=backupCall('write',bytes);if not ok then return nil,err end
  if self:read()~=bytes then return nil,'Recovery verification failed'end
  return true
 end
 function recovery:delete()
  local _,err=backupCall('remove');if self:info()then return nil,err or 'Recovery removal failed'end;return true
 end

 local self={version=version,uiLanguage=prefs:read('preferences/ui-language.txt') or 'en',page='home',index=1,opened=false}
 if not locales[self.uiLanguage]then self.uiLanguage='en'end
 mod.exports.sessionBoot=Lifecycle.__ulaLanguageTransition~=nil and Lifecycle.__ulaLanguageTransition.version==version
 local bus=Runtime.events
 local function live()return Runtime.events==bus and Runtime.wants('ula.session')end
 function self:text(key)
  local startup=mod.exports.startup
  if startup and locales[startup.uiLanguage]then self.uiLanguage=startup.uiLanguage end
  return (labels[self.uiLanguage] or labels.en)[key] or labels.en[key] or key
 end
 function self:choices()
  local base;for _,row in ipairs(requirements)do if row.game==version then base=row.base end end
  local by={en={id='en',name=locales.en.native,available=true,supported=true,sha1=base and base.sha1,revision=base and base.version,rom=base and base.name}}
  for _,id in ipairs({'de','pt-BR','es','fr','it','ja','ko','zh-Hans','zh-Hant'})do by[id]={id=id,name=locales[id].native,available=false,supported=false}end
  for _,entry in ipairs(catalog)do if entry.game==version then
   local row=by[entry.language];row.supported=true;row.importId=entry.sourceId or entry.id
   row.available=mod.imports:info(row.importId)~=nil
   for _,edition in ipairs(requirements)do if edition.game==version then
    for _,source in ipairs(edition.sources)do if source.language==entry.language then row.sha1=source.sha1;row.revision=source.version;row.rom=source.name end end
   end end
  end end
  local out={};for _,id in ipairs({'en','de','pt-BR','es','fr','it','ja','ko','zh-Hans','zh-Hant'})do out[#out+1]=by[id]end;return out
 end
 function self:menuLanguage(id)
  if not locales[id]then return nil,'unknown language'end
  -- Startup can finish after this service was constructed. Re-read its
  -- completed intro/notice/preferences before changing one field.
  prefs=own('preferences.lua')(mod)
  local ok,err=prefs:write('preferences/ui-language.txt',id);if not ok then return nil,err end
  self.uiLanguage=id;if mod.exports.startup then mod.exports.startup.uiLanguage=id end;return true
 end
 local function persist(id)
  prefs=own('preferences.lua')(mod)
  assert(prefs:write('preferences/'..version..'.txt',id))
  local S=require('src.core.SaveData');local opts=S.loadOptions()
  opts.modOptions=opts.modOptions or {};opts.modOptions[mod.id]=opts.modOptions[mod.id] or {};opts.modOptions[mod.id].language='auto'
  assert(S.saveOptions(opts))
 end
 function self:canSwitch()return Engine.inspect(self.game)end
 function self:close()
  self.opened=false
  local input=self.game and self.game.input
  if input and input.reset then input:reset()end
 end
 function self:request(id)
  if self.pending or self.picker then return nil,'busy'end
  if self.recoveryAvailable and recovery:info()then return nil,self:text('recovery')end
  local selected
  for _,row in ipairs(self:choices())do if row.id==id then selected=row end end
  if not selected or not selected.available then return nil,self:text(selected and selected.supported and 'needsRom' or 'unavailable')end
  if id~='en' then
   local marker=require('src.import.CacheFs').readAt(require('src.core.GameVersion').cachePrefix()..'rom-cache.complete')
   local expected=self:choices()[1].sha1
   if not marker or not expected or marker:sub(-40)~=expected then return nil,(locales[self.uiLanguage] or locales.en).wrongBase end
  end
  if id==mod.exports.language then self:close();return true,'unchanged'end
  local ok=Engine.inspect(self.game);if not ok then self.error=self:text('busy');return nil,self.error end
  local copied,snapshot=pcall(Engine.capture,self.game)
  if not copied then self.error=self:text('busy');mod.log:warn('Cannot snapshot language switch: %s',tostring(snapshot));return nil,self.error end
  self.snapshot=snapshot;self.pending=id;self.opened=true;self.loading=0;self.error=nil
  return true,'queued'
 end
 function self:perform()
  local target=self.pending;self.pending=nil
  local snapshot=self.snapshot;self.snapshot=nil
  local previous=mod.exports.language
  local record={format=1,snapshot=snapshot,language=previous,version=version,capturedAt=os.time()}
  local codec=own('cache_codec.lua')
  assert(recovery:write('live-switch-recovery.bin',codec.encode(record)))
  local transition={version=version,language=target}
  Lifecycle.__ulaLanguageTransition=transition
  local ok,fresh,exports=pcall(function()persist(target);return Engine.rebuild(self.game,snapshot)end)
  if not ok then
   local failure=tostring(fresh);transition.language=previous
   local current=Lifecycle.__ulaGameShell and Lifecycle.__ulaGameShell.current or self.game
   local restored,g,e=pcall(function()persist(previous);return Engine.rebuild(current,snapshot)end)
   Lifecycle.__ulaLanguageTransition=nil
   if restored then
    e.session.error=e.session:text('failed')..' '..failure;e.session.opened=true
    recovery:delete();e.session.recoveryAvailable=false;return nil,failure
   end
   error('Language recovery retained in mod profile: '..tostring(g)..'; original: '..failure)
  end
  Lifecycle.__ulaLanguageTransition=nil
  exports.session.lastSwitch={from=previous,to=target,restored=true}
  exports.session.recoveryAvailable=false
  recovery:delete()
  return true,fresh
 end
 function self:discardRecovery()
  local ok,err=recovery:delete();if not ok then return nil,err end
  self.recoveryAvailable=false;self.error=nil;self.page='home';self.index=1;return true
 end
 function self:recover()
  local bytes=recovery:read()
  local ok,value=pcall(function()return own('cache_codec.lua').decode(assert(bytes))end)
  if not ok or type(value)~='table' or value.format~=1 or value.version~=version or type(value.snapshot)~='table' or type(value.snapshot.save)~='table' or value.snapshot.generation~=require('src.core.GameVersion').generation() or value.snapshot.version~=version then return nil,'Invalid recovery record'end
  local target='en';for _,r in ipairs(self:choices())do if r.id==value.language and r.available then target=r.id end end
  -- Time spent outside the application must not count as played time.
  if type(value.capturedAt)=='number' and type(value.snapshot.sessionStartedAt)=='number'then
   value.snapshot.sessionStartedAt=value.snapshot.sessionStartedAt+math.max(0,os.time()-value.capturedAt)
  end
  self.snapshot=value.snapshot;self.pending=target;self.opened=true;self.loading=0;return true
 end
 function self:importBytes(bytes)
  if type(bytes)~='string' or #bytes>32*1024*1024 then return nil,self:text('wrongRom')end
  local md5=love.data.encode('string','hex',love.data.hash('string','md5',bytes))
  local allowed={};for _,row in ipairs(self:choices())do if row.importId then allowed[row.importId]=row end end
  for _,spec in ipairs(manifest.optional_imports)do
   local row=allowed[spec.id]
   local accepted=spec.md5==md5
   if type(spec.md5)=='table'then for _,digest in ipairs(spec.md5)do if digest==md5 then accepted=true end end end
   if row and spec.size==#bytes and accepted then
    local sha=love.data.encode('string','hex',love.data.hash('string','sha1',bytes))
    if sha~=row.sha1 then return nil,self:text('wrongRom')end
    local ok,why=require('src.mods.RequiredImports').importData(manifest,spec.id,bytes)
    if not ok then return nil,why end
    self.notice=self:text('imported')..' '..row.name;self.error=nil;return true,row.id
   end
  end
  return nil,self:text('wrongRom')
 end
 function self:importFile(path)
  local file,err=require('src.core.SaveData').openNative(path,'rb')
  if not file then return nil,err end
  local size=file:seek('end');file:seek('set',0)
  if not size or size>32*1024*1024 then file:close();return nil,self:text('wrongRom')end
  local bytes=file:read('*a');file:close();return self:importBytes(bytes)
 end
 function self:pick()
  if self.pending or self.picker then return nil,'busy'end
  local F=require('src.core.FilePicker');local H=require('src.core.HostPicker')
  if F.available()then
   self.picker=H.start(F.commands(self:text('addRom'),{label='Pokemon ROM',exts={'gb','gbc','gba'},tempName='ula_language_pick'}))
   if self.picker then self.notice=self:text('chooseRom');return true end
  end
  self.notice=self:text('dropRom');return nil,'picker unavailable'
 end
 function self:update()
  if self.picker then
   local done,path=require('src.core.HostPicker').poll(self.picker)
   if done=='done' then self.picker=nil;if path and path~=''then local ok,err=self:importFile(path);if not ok then self.error=err end end end
  end
  if self.pending then self.loading=self.loading+1;if self.loading>=2 then
   local ok,err=pcall(self.perform,self)
   if not ok then
    mod.log:warn('Language handoff failed: %s',tostring(err))
    local bridge=Lifecycle.__ulaGameShell;local g=bridge and bridge.current or self.game
    local session=g.mods and g.mods.exports.german_rom_source and g.mods.exports.german_rom_source.session or self
    session.pending=nil;session.opened=true;session.recoveryAvailable=recovery:info()~=nil
    session.error=session:text(session.recoveryAvailable and 'recovery' or 'failed')
   end
  end end
 end
 function self:open(game,fromMenu)
  game=game or self.game
  if fromMenu then
   local generation=require('src.core.GameVersion').generation()
   if generation<3 then
    local w=generation==1 and game.overworld or game.world
    local states=game.stack and game.stack.states
    if w and states then
     local found=false;for _,s in ipairs(states)do if s==w then found=true end;if s.isTextBox then return nil,'busy'end end
     if generation==2 then game.stack:clear()elseif found then while game.stack:top()~=w do game.stack:pop()end end
    end
   else
    require('src.ui.game3.start_menu').close(true)
    local bridge=mod.find and mod.find('ORIGAMI_ASCENDANT');local menu=bridge and bridge.exports.gen3 and bridge.exports.gen3.menu
    if menu and menu.active then while menu.active()do require('src.ui.game3.stack').pop()end end
   end
  end
  if not Engine.inspect(game)then return nil,self:text('busy')end
  if game.input and game.input.reset then game.input:reset()end
  self.opened=true;self.page='home';self.index=1;self.error=nil;return true
 end
 function self:install()
  mod.events:on('ula.session',function()end)
  own('session_menu.lua')(mod,self,own,live)
  mod.events:on('game.ready',function(payload)
   self.game=payload and payload.game or mod.game
   manifest={id=mod.id,path=mod.path,optional_imports=assert(self.game.mods.mods[mod.id]).manifest.optional_imports}
   if not mod.exports.sessionBoot and Lifecycle.__ulaGameShell and Lifecycle.__ulaGameShell.current~=self.game then Lifecycle.__ulaGameShell=nil end
   self:attach(self.game)
   self.recoveryAvailable=recovery:info()~=nil
   if self.recoveryAvailable and not mod.exports.sessionBoot then self.opened=true end
  end)
 end
 return self
end
