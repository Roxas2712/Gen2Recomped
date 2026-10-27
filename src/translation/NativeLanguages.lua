-- Copyright (c) 2026 Roxas2712. GPL-3.0; Uni-Language notices are retained.
-- Cartridge language selection is independent of machine translation.
local N={ID='german_rom_source',BUNDLE='mods/UNI_LANGUAGE_NATIVE'}
N.ORDER={'en','de','fr','it','es','pt-BR','ja','ko','zh-Hans','zh-Hant'}
N.NAMES={en='English',de='Deutsch',fr='Français',it='Italiano',es='Español',
 ['pt-BR']='Português (Brasil)',ja='日本語',ko='한국어',['zh-Hans']='简体中文',['zh-Hant']='繁體中文'}
function N.canonical(id)
 return ({pb='pt-BR',['pt-br']='pt-BR',zh='zh-Hans',['zh-TW']='zh-Hant',original='en'})[id] or id or 'en'
end
function N.requirement(version)
 for _,r in ipairs(require('mods.UNI_LANGUAGE_NATIVE.rom_requirements')) do if r.game==version then return r end end
end
-- Static preflight checks runtime code plus the current edition's data.
-- Other editions' address tables are never executed in this game session.
function N.sourceRelevant(relative,version)
 local profile=relative:match('^gb/profiles/([^/]+)/')
 if profile then return profile==version or profile:sub(1,#version+1)==version..'_' end
 local name=relative:match('^profiles/([^/]+)%.lua$')
 if name then
  return name==version or name:sub(1,#version+1)==version..'_'
   or version=='sapphire' and (name=='ruby' or name:sub(1,5)=='ruby_')
 end
 return true
end
function N.preferred(options,version)
 options=options or {}
 local chosen=type(options.nativeLanguages)=='table' and options.nativeLanguages[version]
 return N.canonical(chosen or options.nativeLanguageDefault or options.launcherLanguage)
end
function N.chosen(options,version)
 return type(options.nativeLanguages)=='table' and options.nativeLanguages[version] or 'en'
end
function N.manifest()
 -- Use the same winning installation and writable logical path as the loader.
 return require('src.mods.LauncherMods').manifest(N.ID)
end
function N.describe(version,language,manifest)
 language=N.canonical(language)
 local r=N.requirement(version)
 local state={game=version,language=language,supported=language=='en',ready=language=='en',requirement=r}
 if not r or language=='en' then return state end
 for _,entry in ipairs(require('mods.UNI_LANGUAGE_NATIVE.catalog')) do if entry.game==version and entry.language==language then
  state.supported=true;state.profile=entry;break
 end end
 if not state.supported then return state end
 for _,source in ipairs(r.sources) do if source.language==language then state.source=source;break end end
 manifest=manifest or N.manifest();state.manifest=manifest
 if not manifest then state.error='Built-in language profiles are unavailable.';return state end
 local specs={};local imports=require('src.mods.ModImports')
 for _,s in ipairs(imports.of(manifest)) do specs[s.id]=s end
 state.sourceEntry=specs[state.profile.sourceId or state.profile.id]
 state.sourceReady=state.sourceEntry and imports.have(manifest,state.sourceEntry) or false
 state.baseEntry=r.generation==3 and specs[version..'_en'] or nil
 state.baseReady=r.generation~=3 or state.baseEntry and imports.have(manifest,state.baseEntry) or false
 if language=='pt-BR' then
  local automatic=require('src.translation.PtbrPatch').describe(version,manifest)
  if automatic then
   state.automatic=true;state.patchRecipe=automatic.recipe
   state.baseEntry=automatic.baseEntry;state.baseReady=automatic.baseReady
   state.canPrepare=state.baseReady and not state.sourceReady
  end
 end
 state.ready=state.sourceReady and state.baseReady or false
 state.nextEntry=not state.sourceReady and state.sourceEntry or not state.baseReady and state.baseEntry or nil
 if state.automatic then state.nextEntry=not state.baseReady and state.baseEntry or nil end
 return state
end
function N.select(version,language)
 language=N.canonical(language)
 local s=N.describe(version,language)
 if not s.supported or not s.ready then return nil,'Import the required ROMs before selecting this language.' end
 local Save=require('src.core.SaveData');local options=Save.loadOptions()
 options.nativeLanguages=options.nativeLanguages or {};options.nativeLanguages[version]=language
 if language~='en' then options.mods=options.mods or {};options.mods[N.ID]=true end
 return Save.saveOptions(options)
end
function N.keepBase(version,bytes,sha1)
 local r=N.requirement(version)
 if not r then return true end
 local m=N.manifest();if not m then return nil,'Built-in language profiles are unavailable.' end
 local Imports=require('src.mods.ModImports')
 local id=version..'_en'
 if sha1~=r.base.sha1 then
  local found=false
  for _,recipe in ipairs(require('src.translation.PtbrPatch').recipes()) do if recipe.game==version and recipe.baseSha1==sha1 then id=recipe.baseImportId;found=true;break end end
  if not found then return nil,'The English base revision does not match the language profiles.' end
 end
 for _,entry in ipairs(Imports.of(m)) do if entry.id==id then return Imports.install(m,entry,bytes) end end
 return nil,'English base declaration is missing.'
end
return N
