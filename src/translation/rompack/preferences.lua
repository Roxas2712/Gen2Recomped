-- Adapted from Uni-Language Ascendant by Roxas2712 (2026), GPL-3.0.
-- Host integration; language profiles and cartridge inputs stay in the mod.
-- The fork replaces the entire mod directory on update. Its scoped storage
-- survives replacement, so mirror the tiny personal profile there as well.
return function(original)
 return function(mod)
  local path='baseroms/.uni-language-profile';local key='language-profile/v1.txt'
  local proxy=setmetatable({read=function(_,relative)
   local bytes=mod:read(relative)
   if relative==path then return bytes or mod.cache:read(key)end
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
