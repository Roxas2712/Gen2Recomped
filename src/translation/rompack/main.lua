-- Adapted from Uni-Language Ascendant by Roxas2712 (2026), GPL-3.0.
-- Host integration; language profiles and cartridge inputs stay in the mod.
return function(mod)
 local function source(file,...)
  if file=='host.lua' then return require('src.translation.rompack.identity') end
  return assert(loadstring(assert(mod:read(file)),'@rom_language/'..file))(...)
 end
 local function own(file,...)
  if file=='preferences.lua'then return source('@host/preferences.lua')(source(file))end
  return source(file,...)
 end
 local V=require('src.core.GameVersion');local version=V.get()
 mod.exports.host='Gen2Recomped'
 local supported={red=true,blue=true,yellow=true,gold=true,silver=true,crystal=true,firered=true,leafgreen=true,ruby=true,sapphire=true,emerald=true}
 if not supported[version]then
  mod.exports.status='unsupported_host_game';mod.log:warn('Uni-Language: this host adapter has no profile for %s',version);return
 end
 mod.imports=require('src.translation.rompack.imports')(mod,own)
 mod.exports.localizationBackend='native-rom-language-v1'
 local Runtime=require('src.mods.Runtime');local bus=Runtime.events
 mod.events:on('ula.fork.active',function()end)
 local function live()return Runtime.events==bus and Runtime.wants('ula.fork.active')end
 -- Do not let a separately selected machine translation alter the baseline
 -- before a cartridge-derived language profile is installed. Scope this to
 -- this mod's live session, and leave saved launcher options untouched.
 local Service=require('src.translation.Service')
 if Service.__ulaStartup and Service.__ulaStartup.dispose then Service.__ulaStartup.dispose()end
 Service.romLanguageOwner={bus=bus,active=live}
 local assets=own('@host/assets.lua')(mod,own)
 local ui=own('@host/ui_layout.lua').install(live)
 own('@host/classic_item_box.lua').install(live)
 if version=='emerald'then own('@host/type_badges.lua').install(live)end
 if version=='firered'or version=='leafgreen'or version=='emerald'then own('@host/gen3_summary.lua').install(live)end
 own('@host/title.lua').install(live)
 local asianInput=own('@host/asian_input.lua').install(mod,own)
 local asianText=own('@host/asian_text.lua').install(mod,live)
 local metricDisplay=V.generation()==3 and own('@host/display.lua').install(mod)
 local gifts=V.generation()==2 and own('@host/gifts.lua').install(mod,own,version,live)
 local asianLayout=V.generation()==2 and own('@host/asian_layout.lua').install(mod,live)
 local Merge=require('src.mods.Merge');local baseline,game
 local roots={'text','strings','pokemon','moves','items','trainers','statuses','font','field','landmarks','type_chart','constants','mapSections','map_tilesets','tokens','scenes','scripts','map_scripts'}
 local current,compiled='en',nil
 local prefs=own('preferences.lua')(mod)
 local function restore()
  for _,name in ipairs(roots)do game.data[name]=Merge.deepCopy(baseline[name])end
 end
 local function install(id)
  restore()
  local result
  if id~='en'then
   local entry
   for _,row in ipairs(own('catalog.lua'))do if row.game==version and row.language==id and mod.imports:info(row.sourceId or row.id)then entry=row;break end end
   assert(entry,'Missing language ROM for '..version..' / '..id)
   local expected
   for _,row in ipairs(own('rom_requirements.lua'))do if row.game==version then expected=row.base.sha1 end end
   local C=require('src.import.CacheFs');local previous=C.prefix;C.prefix=''
   local called,marker=pcall(C.read,V.cachePrefix()..'rom-cache.complete');C.prefix=previous
   -- This host deliberately shares Crystal's extraction between US rev 0
   -- and rev 1, and stamps BOTH imports with the rev-1 canonical digest.
   -- Only these two known identities are equivalent for this adapter.
   assert(called and own('host.lua').acceptsForkBase(version,expected,marker),'Import the exact supported English base ROM first')
   result=V.generation()==3 and own('@host/gba.lua').compile(mod,entry,own,game.data) or own('@host/compile.lua')(mod,entry,own)
   local path=assert(V.info().manifest)
   local manifest=require('src.link.Json').decode(assert(love.filesystem.read(path)))
   result.report.applied=V.generation()==3 and own('@host/gba.lua').apply(game.data,result.catalogs,own,result) or own('@host/gb.lua').apply(game.data,result.catalogs,manifest.symbols,own('@host/asian_text.lua'))
   if V.generation()==3 then for code,choices in pairs(result.catalogs.gender or{})do
    game.data.tokens['ULA_GENDER_'..code]=function(g)return choices[g.save.player.gender=='female'and'female'or'male']end
   end end
  end
  own('@host/ui_text.lua').apply(game.data,id)
  own('@host/pc_labels.lua').apply(game.data.strings,result and result.catalogs.fork_pc_labels)
  if V.generation()==2 then own('@host/world_palettes.lua').apply(game.data,own('@host/gbc_roof_colors.lua'))end
  if V.generation()==2 then own('@host/ui_layout.lua').hud(game.data.font)end
  assets:set(game.data,result)
  ui:set(id)
  local Unicode=require('src.translation.UnicodeFont');Unicode.configure('original')
  if result and (result.profile.encoding=='japanese-gen2' or result.profile.encoding=='korean-gen2')then
   Unicode.path=mod.path..'/fonts/ascendant-'..(id=='ko' and 'kr' or 'jp')..'.otf'
  elseif id=='en'then
   -- Saved custom names survive a language change. Read them with the
   -- bundled fallback whenever the corresponding source is still imported.
   for _,lang in ipairs({'ko','ja'})do if mod.imports:info(version..'_'..lang)then Unicode.path=mod.path..'/fonts/ascendant-'..(lang=='ko' and 'kr' or 'jp')..'.otf';break end end
  end
  require('src.core.Strings').load(game.data)
  asianInput:set(id,result and result.profile)
  asianText:set(id)
  if asianLayout then asianLayout:set(id)end
  if gifts then gifts:set(result and result.catalogs.mon_names)end
  if metricDisplay then metricDisplay:set(id)end
  if V.generation()==3 then require('src.pokemon.Stats').setNatures(game.data.constants.natures)end
  Service.catalog=game.data.strings or {};Service.engineKeys={}
  for key in pairs(Service.catalog)do Service.engineKeys[key]=true end
  require('src.render.Font').load(game.data)
  if game.overworld and game.overworld.map then
   require('src.world.MapLoader').invalidateAll()
   game.overworld.map.renderer=require('src.render.TileRenderer').new(game.overworld.map,game.data)
  end
  compiled=result
  mod.exports.status=id=='en' and 'english' or 'active';mod.exports.language=id
  mod.exports.coverage=result and result.report or nil;mod.exports.assets=result and result.files or nil
  if result then result.report.routedAssets=assets.routed;result.report.unroutedAssets=assets.unrouted;result.report.titleBindings=assets.titleBindings end
  return true
 end
 local function apply(id,persist)
  local previous=current
  -- First-run setup and the in-game menu write the same profile. Re-read it
  -- before changing one preference so a later switch cannot erase intro/UI
  -- settings saved after this service was constructed.
  prefs=own('preferences.lua')(mod)
  local saved=prefs:read('preferences/'..version..'.txt')
  local ok,err=xpcall(function()
   install(id)
   if persist then
    assert(prefs:write('preferences/'..version..'.txt',id))
    if mod.exports.sessionBoot then
     assert(require('src.translation.NativeLanguages').select(version,id))
     for _,options in ipairs({game.options,game.save and game.save.options}) do if options then
      options.nativeLanguages=options.nativeLanguages or {};options.nativeLanguages[version]=id
     end end
    end
   end
  end,debug.traceback)
  if not ok then
   if persist then pcall(prefs.write,prefs,'preferences/'..version..'.txt',saved or previous)end
   local recovered,recoveryError=pcall(install,previous)
   if not recovered then
    restore();ui:set('en');assets:set(game.data,nil);require('src.core.Strings').load(game.data)
    asianInput:set('en');if metricDisplay then metricDisplay:set('en')end
    asianText:set('en')
    if asianLayout then asianLayout:set('en')end
    if gifts then gifts:set(nil)end
    if V.generation()==3 then require('src.pokemon.Stats').setNatures(game.data.constants.natures)end
    require('src.render.Font').load(game.data);current='en';mod.exports.status='english';mod.exports.language='en'
   end
   mod.log:warn('Language switch failed: %s',tostring(err))
   return nil,tostring(err)..(not recovered and '\n'..tostring(recoveryError) or '')
  end
  current=id;return true
 end
 local session=own('@host/session.lua')(mod,version,own,apply);mod.exports.session=session
 local initial
 mod.events:on('game.ready',function(payload)
  game=payload.game or payload;session.game=game
  baseline={};for _,name in ipairs(roots)do baseline[name]=Merge.deepCopy(game.data[name])end
  mod.exports.baseTextSha256=love.data.encode('string','hex',love.data.hash('string','sha256',require('src.core.SaveSerializer').encode(baseline.text)))
  local ok,why=apply(initial or 'en',false)
  if not ok then session.error=why;session.opened=true end
  session:attach(game)
 end)
 initial=own('startup.lua')(mod,version,own)
 if mod.exports.sessionBoot then
  local options=require('src.core.SaveData').loadOptions()
  if options.nativeLanguages and options.nativeLanguages[version] then
   initial=require('src.translation.NativeLanguages').chosen(options,version)
  end
 end
 Service.__ulaStartup=mod.exports.startup
 mod.exports.hostChangeLanguage=function(id)
  local ok,why=apply(id,false)
  if not ok then prefs:write('preferences/'..version..'.txt',current)end
  return ok,why
 end
end
