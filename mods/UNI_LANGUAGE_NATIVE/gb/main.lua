-- GB/GBC front end. Profiles contain addresses and layout recipes only.
return function(mod,version,own,language)
 local selected,info
 for _,entry in ipairs(own('catalog.lua')) do
  if entry.game==version and entry.language==language then
   local candidate=mod.imports:info(entry.id)
   if candidate then
    assert(not selected,'Multiple language ROMs installed for this game; keep one active import.')
    selected,info=entry,candidate
   end
  end
 end
 if not selected then mod.exports.status='needs_import';mod.log:warn('Select a supported language ROM in MODS > ROM Language Source > Imports.');return end
 local root=selected.root
 local profile=own(selected.profile)
 local id=selected.id
 assert(info.md5==profile.md5 and info.size==profile.size,'ROM/profile mismatch')
 local S=require('src.core.SaveSerializer')
 local function hash(s) return love.data.encode('string','hex',love.data.hash('string','sha256',s)) end
 local paths={'main.lua','session.lua','session_engine.lua','session_menu.lua','session_locales.lua','catalog.lua','cache_codec.lua','compiler.lua','gb/main.lua','gb/runtime/asian_layout.lua','gb/runtime/asian_input.lua','gb/runtime/asian_arguments.lua','gb/runtime/asian_marquee.lua','gb/compile.lua','gb/overlay.lua','gb/adapters/gen1.lua','gb/adapters/gen2.lua','gb/shared/dex_units.lua','gb/shared/official_mon_names.lua',root..'profile.lua',root..'assets.lua'}
 local gen=require('src.core.GameVersion').generation()==2 and 'gen2' or 'gen1'
 local runtime=selected.runtime
 paths[#paths+1]=runtime
 paths[#paths+1]=selected.adapter
 if selected.shared then
  paths[#paths+1]=selected.shared..'dex_units.lua'
  paths[#paths+1]=selected.shared..'official_mon_names.lua'
  paths[#paths+1]=selected.metrics or selected.shared..gen..'/dex_metrics.lua'
 end
 paths[#paths+1]='gb/shared/'..gen..'/dex_metrics.lua'
 for _,cat in ipairs(profile.catalogs) do paths[#paths+1]=root..cat end
 local recipe={'gb-compiler-v1',profile.sha1,version,selected.language}
 table.sort(paths)
 for _,p in ipairs(paths) do recipe[#recipe+1]=p..':'..hash(assert(mod:read(p))) end
 local key=hash(table.concat(recipe,'\n'))
 local files,report=own('compiler.lua')(mod,key,function()
  local rom=assert(mod.imports:read(id,0,info.size))
  assert(#rom==info.size and love.data.encode('string','hex',love.data.hash('string','sha1',rom))==profile.sha1,'ROM checksum mismatch')
  local compiled=own('gb/compile.lua')(rom,profile,root,own)
  compiled.report.language=selected.language
  return compiled
 end)
 local virtual='rom-language/'..key
 own('gb/overlay.lua')(mod,version,virtual,files)
 local proxy={path=virtual,edition=version,language=selected.language,exports=mod.exports,shared={}}
 local decoded={}
 function proxy:read(relative)
  local value=files[relative]
  if not value then return end
  if relative:match('%.lua$') then
   if not decoded[relative] then
    decoded[relative]=S.encode(assert(S.decode(value,{maxBytes=16*1024*1024,maxNodes=500000,maxDepth=40})))
   end
   return decoded[relative]
  end
  return value
 end
 function proxy:readLocal(relative) return self:read(relative) end
 function proxy:info(relative) return files[relative] and {type='file',size=#files[relative]} end
 proxy.assets={}
 function proxy.assets:info(relative) return proxy:info(relative) end
 function proxy.assets:path(relative) return virtual..'/'..relative end
 setmetatable(proxy,{__index=mod})
 if selected.shared then
 proxy.shared.dexUnits=own(selected.shared..'dex_units.lua')
 proxy.shared.dexMetrics=proxy.shared.dexUnits.normalizeCatalog(own(selected.metrics or selected.shared..gen..'/dex_metrics.lua'))
 proxy.shared.monNames=own(selected.shared..'official_mon_names.lua')
 if gen=='gen2' then
  local ok,specials=pcall(require,'src.script.gen2.Specials')
  if ok then proxy.shared.monNames.installGen2ReturnCompatibility(specials) end
 end
 elseif language=='pt-BR' and gen=='gen2' then
  proxy.shared.dexMetrics=own('gb/shared/dex_units.lua').normalizeCatalog(own('gb/shared/gen2/dex_metrics.lua'))
 end
 own(selected.adapter).apply(proxy,version)
 proxy.shared.asianArguments=own('gb/runtime/asian_arguments.lua')
 own(runtime)(proxy)
 own('gb/runtime/asian_layout.lua')(proxy,profile.encoding)
 if profile.encoding=='korean-gen2' or profile.encoding=='japanese-gen2' then own('gb/runtime/asian_marquee.lua')(require('src.render.Font').__ulaEuropeanStrings.active);own('gb/runtime/asian_input.lua').install(proxy,require('src.render.Font').__ulaEuropeanStrings) end
 mod.exports.status='active';mod.exports.language=selected.language;mod.exports.cacheKey=key
 mod.exports.coverage=report;mod.exports.assets=files
 mod.log:info('ROM language %s: %s, %d dialogue entries, %d graphics (%s).',selected.language,version,report.dialogue,report.assets,report.cacheHit and 'cached' or 'compiled')
end
