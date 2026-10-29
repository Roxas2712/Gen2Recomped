package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local Identity = require("src.compat.gen1.MapIdentity")
local Names = require("src.compat.gen1.MapNames")
local Version = require("src.core.GameVersion")
local Catalog = require("src.import.gba.map_catalog")
local prior = Version.get()
for _, edition in ipairs({ "firered", "leafgreen", "emerald", "ruby", "sapphire" }) do
  Version.set(edition)
  local maps, nativeKeys = {}, {}
  for _, row in ipairs(Names[edition]) do
    local key = ("NATIVE_%d_%d"):format(row[1], row[2])
    maps[key] = { id = key, group = row[1], number = row[2], untouched = {} }
    nativeKeys[row[3]] = key
  end
  local binding = Identity.bind(maps, edition)
  -- Differential oracle is the original multi-step runtime resolver. Include
  -- native aliases and live retirement, not only catalog names.
  local function oldResolve(id)
    local native,def=binding:nativeId(id)
    if not native then
      local canonical=binding:legacyId(id)
      if canonical then native,def=binding:nativeId(canonical) end
    end
    if native then return native,def,binding:legacyId(native) end
  end
  local function equivalent(id)
    local a,b,c=oldResolve(id);local x,y,z=binding:resolve(id)
    T.eq(x,a,"combined resolution preserves native key")
    if a then
      T.eq(y,b,"combined resolution borrows exact definition")
      T.eq(z,c,"combined resolution preserves canonical name")
    end
  end
  for _, row in ipairs(Names[edition]) do
    local aliases={row[3],row[4],row[5],nativeKeys[row[3]],row[1]..":"..row[2]}
    for i=1,5 do if aliases[i]~=nil then equivalent(aliases[i])end end
    local key, def = binding:nativeId(row[3])
    T.eq(key, nativeKeys[row[3]], "original name reaches actual native record")
    T.eq(def, maps[key], "definition is borrowed with its exact identity")
    T.eq(binding:legacyId(key), row[3], "native name returns original name")
    if Version.get() == edition then
      T.eq(Catalog.resolve(row[4]), row[3], "original mod import resolves pret alias")
    else
      T.eq(Catalog.isKnown(row[3]), false, "unavailable host edition has no active catalog")
    end
    T.eq(def.id, key, "native id was never rewritten")
  end
  local independent=Identity.bind(maps,edition)
  local originalMethod=binding.nativeId
  binding.nativeId=function()return 'MODIFIED' end
  T.eq(independent:nativeId(Names[edition][1][3]),nativeKeys[Names[edition][1][3]],'bindings retain independent methods')
  binding.nativeId=originalMethod
  local first = Names[edition][1]
  local key = nativeKeys[first[3]]
  local def = maps[key]
  -- A native key may itself look like another map's legacy name. Preserve
  -- legacy precedence, then its native-alias fallback when the slot retires.
  maps[first[3]]=maps[nativeKeys[Names[edition][2][3]]]
  equivalent(first[3])
  maps[key] = nil
  equivalent(first[3]);equivalent(key)
  maps[first[3]]=nil
  equivalent(first[3])
  T.eq(binding:nativeId(first[3]), nil, "removed native record retires its binding")
  maps[key] = { id = key, group = first[1], number = first[2] }
  equivalent(first[3]);equivalent(key)
  T.eq(binding:nativeId(first[3]), nil, "replacement cannot inherit prior binding")
  maps[key] = def
  local duplicate = { id = "OTHER", group = def.group, number = def.number }
  maps.OTHER = duplicate
  local ambiguous = Identity.bind(maps, edition)
  T.eq(ambiguous:nativeId(first[3]), nil, "ambiguous slot cannot choose a different room")
  maps.OTHER = def
  local aliases = Identity.bind(maps, edition)
  T.eq(aliases:nativeId(first[3]), key, "same-object aliases prefer actual def.id")
  T.eq(aliases:legacyId("OTHER"), first[3], "same-object alias has same legacy identity")
  local resolved,borrowed,canonical=aliases:resolve("OTHER")
  T.eq(resolved,key,"combined native alias chooses preferred key")
  T.eq(borrowed,def,"combined native alias preserves identity")
  T.eq(canonical,first[3],"combined native alias returns canonical name")
  T.eq(ambiguous:resolve(first[3]),nil,"combined resolver refuses ambiguous slot")
  def.id='OTHER'
  T.eq(Identity.bind(maps,edition):nativeId(first[3]),'OTHER','same-frame preferred alias changes are observed')
  def.id=key
  T.eq(Identity.bind(maps,edition):nativeId(first[3]),key,'same-frame identity restoration is observed')
  maps.OTHER=duplicate
  T.eq(Identity.bind(maps,edition):nativeId(first[3]),nil,'same-frame added ambiguity is observed')
  maps.OTHER=nil
  T.eq(Identity.bind(maps,edition):nativeId(first[3]),key,'same-frame alias deletion removes ambiguity')
  def.group = 255
  equivalent(first[3]);equivalent(key)
  T.eq(aliases:nativeId(first[3]), nil, "changed slot retires prior binding")
  T.eq(binding:nativeId("invented"), nil, "unknown mod map is not guessed")
  T.eq(binding:legacyId("invented"), nil, "unknown native map is not guessed")
end
do
  local maps={ROOM={id='ROOM',group=3,number=0}}
  local binding=Identity.bind(maps,'firered')
  local weak=setmetatable({maps,binding},{__mode='v'})
  maps,binding=nil,nil
  collectgarbage('collect');collectgarbage('collect')
  T.eq(weak[1],nil,'private index does not retain released map tables')
  T.eq(weak[2],nil,'private index does not retain released bindings')
end
Version.set("gold")
T.eq(Catalog.isKnown("FR_PALLET_TOWN"), false, "other generations do not acquire Gen3 maps")
T.eq(Identity.lookup("firered", -1, 0), nil, "negative group is rejected")
T.eq(Identity.lookup("firered", 3.5, 0), nil, "fractional group is rejected")
T.eq(Identity.lookup("firered", 3, 256), nil, "out of range map number is rejected")
Version.set(prior)
T.finish("Gen1 native map identity compatibility")
