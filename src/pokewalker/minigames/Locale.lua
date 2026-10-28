-- Contributions by Roxas2712. Minigames follow the launcher, not a ROM's language.
local Service=require('src.translation.Service')
return function(source,...)
 return Service.launcherFormat(source,...)
end
