-- Gen-2 held definitions are a projection of two native item attributes.
-- Keep their fold separate from items, then apply it after all item writes.
local Merge = require("src.mods.Merge")
local Names = require("src.battle.HeldItemRead")
local M = {}
local previous = setmetatable({}, { __mode = "k" })
local explicit = setmetatable({}, { __mode = "k" })

local function finite(value, seen)
  if type(value) == "number" then
    assert(value == value and math.abs(value) < math.huge, "invalid content: non-finite number")
  elseif type(value) == "table" and value ~= Merge.DELETE then
    seen = seen or {}
    assert(not seen[value], "invalid content: cyclic content")
    seen[value] = true
    for key, part in pairs(value) do
      finite(key, seen)
      finite(part, seen)
    end
    seen[value] = nil
  end
end

local function identifier(id)
  assert(type(id) == "string" and id ~= "", "invalid content: registry id is required")
end

function M.record(def)
  if type(def) ~= "table" or def.heldEffect == nil then
    return nil
  end
  return { heldEffect = Names.goldPublic(def.heldEffect), heldParameter = def.heldParam or 0 }
end

function M.changed(def)
  return explicit[def] == true
end

function M.prepare(loader, data)
  local undo = previous[data] or {}
  for i = #undo, 1, -1 do
    local entry = undo[i]
    local def = entry.def
    if def.heldEffect == entry.effect and def.heldParam == entry.parameter then
      def.heldEffect, def.heldParam = entry.beforeEffect, entry.beforeParameter
    end
    explicit[def] = nil
  end
  if data then
    previous[data] = nil
  end
  local base = {}
  if loader:_generation() == 2 then
    for id, def in pairs(data and data.items or {}) do
      base[id] = M.record(def)
    end
  end
  loader._heldItemBase = base
  loader.content.held_items.base = function()
    return base
  end
end

function M.apply(loader, data)
  if not data or loader:_generation() ~= 2 then
    return
  end
  local registry, undo = loader.content.held_items, {}
  for _, id in ipairs(registry.order) do
    local def = data.items and data.items[id]
    if registry.ops[id] and type(def) == "table" then
      local row = registry:get(id)
      local effect = row and Names.goldNative(row.heldEffect) or nil
      local parameter = row and (row.heldParameter or 0) or nil
      undo[#undo + 1] = {
        def = def,
        beforeEffect = def.heldEffect,
        beforeParameter = def.heldParam,
        effect = effect,
        parameter = parameter,
      }
      def.heldEffect, def.heldParam = effect, parameter
      explicit[def] = true
    end
  end
  previous[data] = undo
end

-- Native unsupported writes follow the reference's reported-drop policy.
-- Unified APIs refuse them and return detached definition records.
function M.api(loader, mod, native, generation, unified)
  local available = generation == 2 and loader._heldItemBase ~= nil
  local reason = not available and "unsupported: held_items has no native target in this dataset" or nil
  local warned = false
  local out = {
    available = available,
    supports = function()
      return available, reason
    end,
  }
  out.get = function(_, id)
    if not available then
      return nil, reason
    end
    if unified then
      identifier(id)
    end
    local value = native:get(id)
    return unified and Merge.deepCopy(value) or value
  end
  out.has = function(_, id)
    return out:get(id) ~= nil
  end
  out.each = function()
    if not available then
      return function() end
    end
    local nextRow = native:each()
    return function()
      local id, value = nextRow()
      if id ~= nil then
        return id, unified and Merge.deepCopy(value) or value
      end
    end
  end
  for _, verb in ipairs({ "register", "override", "patch", "remove" }) do
    out[verb] = function(_, id, value)
      if not available then
        if unified then
          return nil, reason
        end
        if not warned then
          require("src.core.Logger").warn("[%s] %s", mod.manifest.id, reason)
          warned = true
        end
        return nil
      end
      if unified then
        identifier(id)
        finite(value)
        value = Merge.deepCopy(value)
      end
      local result = native[verb](native, id, value)
      return unified and out:get(id) or result
    end
  end
  return out
end

return M
