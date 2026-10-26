-- Adapted from Uni-Language Ascendant by Roxas2712 (2026), GPL-3.0.
-- Host integration; language profiles and cartridge inputs stay in the mod.
-- The fork replaces the entire mod directory on update. Its scoped storage
-- survives replacement, so mirror the tiny personal profile there as well.
return function(original)
 return function(mod)
  local path='baseroms/.uni-language-profile';local key='language-profile/v1.txt'
  local proxy=setmetatable({path=mod.languageManifest and mod.languageManifest.path or mod.path,read=function(_,relative)
   local bytes=mod:read(relative)
   if relative==path then
    local saved=bytes or mod.cache:read(key)
    if not saved and mod.exports.sessionBoot then
     local o=require('src.core.SaveData').loadOptions()
     local id=require('src.translation.NativeLanguages').canonical(o.launcherLanguage)
     return 'ULA1\npreferences/notice.txt=accepted\npreferences/ascendant-intro-v1.txt=seen\npreferences/ui-language.txt='..id..'\n'
    end
    return saved
   end
   return bytes
  end},{__index=mod})
  local prefs=original(proxy)
  local function mirror()
   local bytes=mod:read(path) or mod.cache:read(key)
   if bytes then return mod.cache:write(key,bytes)end
   return true
  end
  for _,method in ipairs({'write','reset'})do
   local base=prefs[method]
   prefs[method]=function(self,...)
    local ok,err=base(self,...);if not ok then return nil,err end
    return mirror()
   end
  end
  local ok,err=mirror();if not ok then mod.log:warn('Could not retain language preferences across host updates: %s',tostring(err))end
  return prefs
 end
end
