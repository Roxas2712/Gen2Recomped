-- Private RS presentation bridge. Reference modules retain their own license
-- and exact source bytes. Their require cache and RNG never enter the host's.
local Loader = {}
local ROOT = 'compat/gen1-rs/reference/'

function Loader.new(version, bindings)
  assert(version == 'ruby' or version == 'sapphire' or version == 'emerald', 'Native Hoenn version required')
  local loaded = {}
  bindings = bindings or {}
  local function load(name)
    if bindings[name] then return bindings[name] end
    if loaded[name] then return loaded[name] end
    if name == 'bit' or name == 'ffi' then return require(name) end
    if name == 'src.import.LuaWriter' then return require(name) end
    if name == 'src.import.CacheBlob' then
      return { deflate = function(bytes, level)
        return love.data.compress('string', 'zlib', bytes, level)
      end }
    end
    if name == 'src.import.gba.versions' then
      return { BUILD = version, SYMS = load('src.import.gba.syms').of(version) }
    end
    if name == 'src.ui.game3.rse.title_rse' and version ~= 'emerald' then
      return { MANIFEST = 'data/generated/gba/title/manifest.lua' }
    end
    assert(name:match('^src%.[%w_%.]+$'), 'Invalid RS module: '..tostring(name))
    local path = ROOT .. name:gsub('%.', '/') .. '.lua'
    local chunk = assert(love.filesystem.load(path), 'Missing pinned RS module: '..name)
    local env = setmetatable({ require = load, package = bindings.__package or package }, { __index = _G })
    setfenv(chunk, env)
    local result = chunk()
    loaded[name] = result
    return result
  end
  return load
end

return Loader
