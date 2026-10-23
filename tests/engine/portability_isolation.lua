package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local Migration = require("src.core.SaveIdentity")
local Save = require("src.core.SaveData")
local oldGetenv, oldFilesystem = os.getenv, love.filesystem
local touches = 0
love.filesystem = setmetatable({}, {
  __index = function()
    touches = touches + 1
    error("isolated test installation must not probe legacy storage")
  end,
})
os.getenv = function(name)
  if name == "POKEPORT_SKIP_LEGACY_MIGRATION" or name == "POKEPORT_ISOLATED_TESTING" then
    return "1"
  end
  return oldGetenv(name)
end
local ok, count = pcall(Migration.migrateLegacy)
local locationsOk, locations = pcall(Save.otherLocations)
local foreignOk, foreign = pcall(Save._foreignSlots, "red")
os.getenv, love.filesystem = oldGetenv, oldFilesystem
T.eq(ok, true, "isolated startup does not access legacy storage")
T.eq(count, 0, "isolated startup copies no saves")
T.eq(touches, 0, "no identity switch, read or write")
T.eq(locationsOk, true, "isolated discovery never probes other roots")
T.eq(locations and #locations, 0, "isolated discovery returns no foreign locations")
T.eq(foreignOk, true, "foreign-slot discovery performs no filesystem access")
T.eq(foreign and #foreign, 0, "foreign progress is excluded from test launcher")
T.eq(touches, 0, "no foreign identity or save probes")
T.finish("portable fork test-installation isolation")
