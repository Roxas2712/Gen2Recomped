-- Built-in Uni-Language entry, GPL-3.0; see LICENSE.MD and SOURCE.json.
return function(mod)
 -- Language data is established at boot from the exact imported package.
 -- This adapter owns no transient gameplay state outside native save memory.
 if mod.suspend then mod.suspend:register({schema=1,capture=function()return {}end,restore=function()return true end})end
 if not mod:supports('localization','rom-language-v1') then mod.exports.status='unavailable';return end
 local options=require('src.core.SaveData').loadOptions()
 local target=require('src.translation.Languages').resolve(options,mod.gameVersion)
 if target~='original' and not (options.nativeLanguages and options.nativeLanguages[mod.gameVersion]) then
  mod.exports.status='machine_translation';return
 end
 mod.exports.sessionBoot=true
 return mod.localization:install({format='rom-language-v1'})
end
