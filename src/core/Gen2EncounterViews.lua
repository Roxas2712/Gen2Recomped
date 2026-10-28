-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- The Gold source vocabulary over the shared engine's real encounter rows.
-- Slot arrays remain native. This is a read view, never a second encounter
-- picker, RNG, clock or copy of the merged dataset. Source-shaped writes
-- are admitted only inside old-SDK callbacks and update these same rows.
local Version = require('src.core.GameVersion')
local Encounter = require('src.world.Encounter')
local Views = {}
local owners = setmetatable({}, { __mode = 'kv' })
local writers = setmetatable({}, { __mode = 'k' })

-- API 1/2 callbacks may still write source-shaped encounter rows. Keep
-- that permission local to the callback; ordinary readers remain read-only.
function Views.withLegacyWrites(data, callback, ...)
  if not Version.isGen2() or type(data) ~= 'table' then return callback(...) end
  writers[data] = (writers[data] or 0) + 1
  local function pack(...) return {n=select('#',...),...} end
  local result = pack(pcall(callback, ...))
  writers[data] = writers[data] - 1
  if not result[1] then error(result[2], 0) end
  return unpack(result, 2, result.n)
end

local function readonly()
  error('Gen2 encounter views are read-only; use the encounters registry', 2)
end

function Views.forData(data)
  if not Version.isGen2() or type(data) ~= 'table' then return nil end
  local cached = owners[data]
  if cached then return cached end
  local edition = Version.get()
  local function mayWrite()
    if Version.get() ~= edition or not writers[data] or writers[data] <= 0 then readonly() end
  end
  local function sourceWrite(native, kind, key, value)
    mayWrite()
    local field = ({slots='slots',rates='rate',ascendantBuckets='buckets',
      ascendantRollMax='bucketSpan'})[key]
    if kind == 'water' and key == 'rate' then field = 'rate' end
    if not field then error('unsupported legacy encounter field: '..tostring(key), 2) end
    if kind == 'water' then native[field] = value; return end
    if type(value) ~= 'table' then error('grass source fields require time bands', 2) end
    native.byTime = native.byTime or {}
    for _, tod in ipairs({'MORN','NITE'}) do
      local band = native.byTime[tod:lower()]
      if not band then
        band = {slots=native.slots,rate=native.rate,buckets=native.buckets,
          bucketSpan=native.bucketSpan}
        native.byTime[tod:lower()] = band
      end
      if value[tod] ~= nil then band[field] = value[tod] end
    end
    if value.DAY ~= nil then native[field] = value.DAY end
    -- A prior importer may carry an explicit DAY override as well.
    if native.byTime.day and value.DAY ~= nil then native.byTime.day[field] = value.DAY end
  end
  local function terrain(id, kind)
    if Version.get() ~= edition then return nil end
    local all = data.encounters or {}
    local row = all[id]
    if row == nil then
      local map = data.maps and data.maps[id]
      local source = type(map) == 'table' and map.sourceId
      if type(source) == 'string' and data.maps[source] == map then
        row = all[source]
      end
    end
    local value = type(row) == 'table' and row[kind]
    if type(value) == 'table' and type(value.slots) == 'table'
        and #value.slots > 0 then return value end
  end
  local function maps(kind)
    local rows = {}
    local function row(id)
      if type(id) ~= 'string' or not terrain(id, kind) then return nil end
      return setmetatable({}, {
        __index = function(_, key)
          local native = terrain(id, kind)
          if not native then return nil end
          if kind == 'water' then return native[key] end
          local field=({rates='rate',slots='slots',ascendantBuckets='buckets',
            ascendantRollMax='bucketSpan'})[key]
          if field then
            local out = {}
            for _, tod in ipairs({'MORN', 'DAY', 'NITE'}) do
              local band = Encounter.atTime(native, tod)
              out[tod] = band[field]
            end
            return next(out) and out or nil
          end
          return native[key]
        end,
        __newindex = function(_, key, value)
          local native = terrain(id, kind)
          if not native then error('encounter row no longer exists', 2) end
          sourceWrite(native, kind, key, value)
        end,
      })
    end
    -- Enumerate actual source and published map names, including aliases
    -- proven by a shared native record. No spelling guesses for authored maps.
    for id in pairs(data.encounters or {}) do rows[id] = row(id) end
    for id in pairs(data.maps or {}) do rows[id] = row(id) end
    return setmetatable(rows, { __index = function(_, id) return row(id) end })
  end
  local function fieldTable(get, keyOf)
    return setmetatable({}, {
      __index=function(_,key)local rows=get();return rows and rows[keyOf and keyOf(key)or key] end,
      __newindex=function(_,key,value)mayWrite();get(true)[keyOf and keyOf(key)or key]=value end,
    })
  end
  local function trees(create)
    if create then
      data.field=data.field or {};data.field.gen2TreeMons=data.field.gen2TreeMons or {maps={},sets={}}
    end
    return data.field and data.field.gen2TreeMons
  end
  local fishWrappers=setmetatable({}, {__mode='k'})
  local fish = setmetatable({}, {
    __index=function(_,id)
      local groups=data.field and data.field.fishGroups
      local native=groups and groups[id]
      if not native then return nil end
      local proxy=setmetatable({}, {
        __index=function(_,key)
          if key=='old' or key=='good' or key=='super' then return native.rods and native.rods[key] end
          return native[key]
        end,
        __newindex=function(_,key,value)
          mayWrite()
          if key~='old' and key~='good' and key~='super' then native[key]=value;return end
          native.rods=native.rods or {}
          for index,row in ipairs(value)do
            if row.day and row.nite then
              data.field.timeFishGroups=data.field.timeFishGroups or {}
              local group='legacy:'..tostring(id)..':'..key..':'..index
              data.field.timeFishGroups[group]={day=row.day,nite=row.nite}
              row.timeGroup=group
            end
          end
          native.rods[key]=value
        end,
      })
      fishWrappers[proxy]=native
      return proxy
    end,
    __newindex=function(_,id,value)
      mayWrite();data.field=data.field or {};data.field.fishGroups=data.field.fishGroups or {}
      data.field.fishGroups[id]=fishWrappers[value] or value
    end,
  })
  cached = { grass = maps('grass'), water = maps('water'),
    treeSets=fieldTable(function(create)local t=trees(create);return t and t.sets end),
    trees=fieldTable(function(create)local t=trees(create);return t and t.maps end,function(id)
      local map=data.maps and data.maps[id]
      return type(map)=='table' and map.label or id
    end),
    fishGroups=fish,
  }
  owners[data] = cached
  return cached
end

function Views.publish(data)
  if not Version.isGen2() or type(data) ~= 'table' then return false end
  -- Republish after a registry merge so enumeration includes added maps.
  owners[data] = nil
  data.gen2Encounters = Views.forData(data)
  data.gen2Maps = data.maps
  return true
end

return Views
