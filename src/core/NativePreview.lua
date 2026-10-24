-- Activated only by the generated preview payload, never by a normal build.
local M = {}
function M.activate(identity)
  assert(type(identity)=="string" and identity:match("^Gen2Recomp%-NativePreview%-%d+%-%d+$"),"invalid preview identity")
  assert(not M.identity or M.identity==identity,"preview identity changed")
  if M.identity then return end
  M.identity=identity
  local getenv=os.getenv
  local flags={POKEPORT_NO_MODS="1",POKEPORT_NO_DISCORD="1",POKEPORT_NO_BOOT_REPORT="1",
    POKEPORT_NOTIFY_ONLY_UPDATES="1",POKEPORT_IDENTITY=identity}
  os.getenv=function(key)if flags[key]then return flags[key]end;return getenv(key)end
  _G.POKEPORT_NOTIFY_ONLY_UPDATES=true
end
function M.prepare()
  local fs=love.filesystem
  assert(M.identity and fs.getIdentity()==M.identity,"preview profile mismatch")
  local setIdentity=fs.setIdentity
  fs.setIdentity=function(identity,...)
    assert(identity==M.identity,"preview rejected identity switch")
    return setIdentity(identity,...)
  end
  -- Disable the legacy migration itself, before any normal startup can run.
  require("src.core.SaveIdentity").migrateLegacy=function()return 0 end
  assert(require("src.core.SaveData").portableBaseDir()==nil,"extract preview into a separate folder without portable.txt")
  assert(require("src.import.CacheFs").root()==nil,"preview requires its own default data folder")
end
return M
