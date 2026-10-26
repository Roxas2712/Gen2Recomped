package.path = "./?.lua;./?/init.lua;" .. package.path
local api = assert(tonumber(arg[1]))
local version = assert(arg[2])
local root = assert(arg[3])
local Version = require("src.core.GameVersion")
Version.set(version)
local Json = require("src.link.Json")
local encode = Json.encode
local manifests = 0
Json.encode = function(value, ...)
  if type(value) == "table" and value.entry == "main.lua" and value.api == 2 and value.id then
    local copy = {}
    for key, part in pairs(value) do
      copy[key] = part
    end
    copy.api = api
    manifests = manifests + 1
    return encode(copy, ...)
  end
  if type(value) == "table" and value.publicWarnings ~= nil then
    assert(manifests == 6, "not all actual mod manifests were parameterized")
    print("DEV_API_MODE_RESULT " .. encode({ api = api, version = Version.get(), manifests = manifests }))
  end
  return encode(value, ...)
end
dofile(root .. "/tests/engine/mod_api_require_attribution.lua")
