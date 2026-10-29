-- Copyright (c) 2026 Roxas2712. GPL-3.0; see src/translation/rompack/NOTICE.md.
-- Native ROM language packs. Discovery never loads a renderer or constructs Game.
local L = {}
local GAMES = {red=true,blue=true,yellow=true,gold=true,silver=true,crystal=true,
  firered=true,leafgreen=true,ruby=true,sapphire=true,emerald=true}
local ROOT = 'src/translation/rompack/'

function L.supports(version, format)
  return GAMES[version] == true and format == 'rom-language-v1'
end

function L.install(loader, record, api, engineCall)
  local version = api.gameVersion
  local installed = false
  local run = engineCall or function(fn, ...) return fn(...) end
  api.localization = {format='rom-language-v1'}
  function api.localization:install(options)
    options = options or {}
    assert(type(options)=='table' and (options.format or self.format)==self.format,
      'unsupported language-pack format')
    assert(L.supports(version,self.format), 'ROM language packs are unavailable for '..tostring(version))
    assert(not installed, 'a language pack is already installed for this mod session')
    installed = true
    -- Read host recipes only from the engine. A mod cannot shadow executable
    -- native helpers; all ordinary profile reads keep their existing sandbox.
    local proxy = setmetatable({languageManifest=record.manifest}, {__index=api})
    local recipes={}
    local function fingerprint(dir)
      local names=love.filesystem.getDirectoryItems(dir)
      table.sort(names)
      for _,name in ipairs(names) do
        local path=dir..'/'..name
        local info=love.filesystem.getInfo(path)
        if info and info.type=='directory' then fingerprint(path)
        elseif info and name:match('%.lua$') then
          recipes[#recipes+1]=path..':'..love.data.encode('string','hex',love.data.hash('sha256',assert(love.filesystem.read(path))))
        end
      end
    end
    fingerprint(ROOT:sub(1,-2))
    proxy.languageRecipe=table.concat(recipes,'\n')
    function proxy:read(path)
      if type(path)=='string' and path:sub(1,6)=='@host/' then
        local relative=path:sub(7)
        assert(relative:match('^[%w_/]+%.lua$') and not relative:find('..',1,true), 'invalid host recipe')
        return love.filesystem.read(ROOT..relative)
      end
      return api:read(path)
    end
    local result=run(function() return require('src.translation.rompack.main')(proxy) end)
    api.imports=proxy.imports
    return result
  end
  local supports=api.supports
  function api:supports(surface,name)
    if surface=='localization' then return L.supports(version,name) end
    return supports(self,surface,name)
  end
end
return L
