package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local Migration = require("src.core.SaveIdentity")
local oldGetenv, oldFilesystem = os.getenv, love.filesystem
local touches = 0
love.filesystem = setmetatable({}, { __index = function()
  touches = touches + 1
  error("isolated test installation must not probe legacy storage")
end })
os.getenv = function(name)
  if name == "POKEPORT_SKIP_LEGACY_MIGRATION" then return "1" end
  return oldGetenv(name)
end
local ok, count = pcall(Migration.migrateLegacy)
os.getenv, love.filesystem = oldGetenv, oldFilesystem
T.eq(ok, true, "isolated startup does not access legacy storage")
T.eq(count, 0, "isolated startup copies no saves")
T.eq(touches, 0, "no identity switch, read or write")
T.finish("portable fork test-installation isolation")
