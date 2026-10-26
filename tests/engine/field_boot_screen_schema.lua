package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local Schemas = require("src.mods.Schemas")
local Merge = require("src.mods.Merge")
local data = T.fixtures.fresh()
local schema = Schemas.REGISTRIES.field
local ok, errors = Schemas.check(schema,"field","boot",data.field.boot,"override")
T.check(ok,"engine-seeded boot record validates: "..table.concat(errors or {},"; "))
for _,id in ipairs{"startMenu","options","bag","party","trainerCard"} do
  local boot = Merge.deepCopy(data.field.boot)
  boot.screens[id] = "CustomScreen"
  T.check(Schemas.check(schema,"field","boot",boot,"override"),id.." accepts a replacement screen id")
  boot.screens[id] = 42
  local valid = Schemas.check(schema,"field","boot",boot,"override")
  T.check(not valid,id.." still rejects a non-string screen id")
end
local boot = Merge.deepCopy(data.field.boot)
boot.screens.partyMenuTypo = "PartyMenu"
T.check(not Schemas.check(schema,"field","boot",boot,"override"),"unknown nested screen fields remain rejected")
T.finish("field_boot_screen_schema")
