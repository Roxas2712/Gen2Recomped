package.path = "./?.lua;./?/init.lua;" .. package.path
local T, V = require("tests.modkit"), require("src.core.GameVersion")
local Copy, Json = require("src.mods.Merge").deepCopy, require("src.link.Json")
local old = V.get()
V.set("gold")
local function data()
  local d = T.fixtures.fresh()
  d.items.LEFTOVERS = { id = "LEFTOVERS", name = "LEFTOVERS", price = 100, heldEffect = 3, heldParam = 0 }
  d.items.BERRY = { id = "BERRY", name = "BERRY", price = 50, heldEffect = 1, heldParam = 10 }
  return d
end
-- A native Data:load recreates engine registration inputs before a new
-- loader. Retain only item objects here to stress held-write retirement.
local function reloadInputs(d)
  local fresh = T.fixtures.fresh()
  for root in pairs(require("src.mods.Builtins").namespaceRoots()) do
    if root ~= "items" then
      d[root] = fresh[root]
    end
  end
end
local function loadNone(d)
  reloadInputs(d)
  return T.sdk.loadNone({ data = d })
end
local function load(d, source, api, format)
  reloadInputs(d)
  local files = {
    ["mods/probe/manifest.json"] = Json.encode({
      id = "probe",
      name = "probe",
      version = "1",
      api = api,
      games = { "gen2" },
      content_format = format,
      entry = "main.lua",
    }),
    ["mods/probe/main.lua"] = "local mod=...; mod.exports.api=mod; " .. source,
  }
  return T.sdk.loadMods({ "mods/probe" }, { data = d, fs = T.sdk.memfs(files), dev = false })
end
for _, mode in ipairs({ { 1, "native" }, { 2, "native" }, { 2, "unified" }, { 3, "unified" } }) do
  local api, format = unpack(mode)
  local d, before = data()
  before = Copy(d.items)
  local none = loadNone(d)
  T.same(d.items, before, "no-mod load preserves every native item attribute")
  T.eq(rawget(d, "heldItems"), nil, "virtual registry adds no generated-data namespace")
  none.release()
  local r = load(
    d,
    'mod.content.held_items:override("LEFTOVERS", {heldEffect="HELD_BERRY", heldParameter=7})',
    api,
    format
  )
  T.eq(#r.errors, 0, "held writer loads")
  T.eq(d.items.LEFTOVERS.heldEffect, 1, "only public held name converts to native effect")
  T.eq(d.items.LEFTOVERS.heldParam, 7, "native parameter written")
  T.eq(d.items.LEFTOVERS.price, 100, "other attributes preserved")
  local h = r.loader.exports.probe.api.content.held_items
  T.raises(function()
    h:patch("LEFTOVERS", { heldParameter = 8 })
  end, "frozen", "late writes cannot alter frozen content")
  if format == "unified" then
    local record = h:get("LEFTOVERS")
    record.heldParameter = 111
    for _, row in h:each() do
      row.heldEffect = "HELD_NONE"
    end
    T.eq(h:get("LEFTOVERS").heldParameter, 7, "get is detached")
    T.eq(d.items.LEFTOVERS.heldEffect, 1, "enumeration is detached from native effects")
    T.raises(function()
      h:get(nil)
    end, "registry id", "unified read validates its ID")
    local invalid = { heldEffect = "HELD_BERRY" }
    invalid.loop = invalid
    T.raises(function()
      h:override("LEFTOVERS", invalid)
    end, "cyclic", "cyclic definitions refused before write")
  end
  if format == "unified" then
    local items = r.loader.exports.probe.api.content.items
    -- Index checks happen before the freeze guard; neither failure may write.
    local _, reason = items:register("CONFLICT", { id = "CONFLICT", name = "CONFLICT", price = 1, index = 0 })
    T.check(type(reason) == "string" and reason:find("reserved", 1, true), "new item cannot claim NONE index")
  end
  r.release()
  local clean = loadNone(d)
  T.same(d.items, before, "reloading same dataset without mod restores only held writes")
  clean.release()
  local removed = load(d, 'mod.content.held_items:remove("LEFTOVERS")', api, format)
  T.eq(d.items.LEFTOVERS.heldEffect, nil, "remove clears native effect")
  T.eq(d.items.LEFTOVERS.heldParam, nil, "remove clears native parameter")
  removed.release()
  clean = loadNone(d)
  T.same(d.items, before, "tombstone reload restores native definition")
  clean.release()
  if format == "unified" then
    d.items.BERRY.index = 240
    local rejected = load(
      d,
      'local ok, reason=mod.content.items:register("CONFLICT", {id="CONFLICT", name="CONFLICT", price=1, index=240}); mod.exports.refusal=reason; assert(not ok)',
      api,
      format
    )
    T.eq(#rejected.errors, 0, "unsupported index is reported without corrupting the entry")
    T.check(
      rejected.loader.exports.probe.refusal:find("already assigned", 1, true),
      "occupied native index refused"
    )
    T.eq(d.items.CONFLICT, nil, "collision cannot create native item")
    rejected.release()
    d.items.BERRY.index = nil
  end
  if api >= 2 then
    for _, bad in ipairs({
      "heldParameter=-1",
      "heldParameter=256",
      "heldParameter=0.5",
      'heldParameter="7"',
      "heldParameter=0/0",
      "heldParameter=math.huge",
      "heldEffect=4",
      "heldEffect={}",
    }) do
      local failed = load(
        d,
        'mod.content.held_items:override("LEFTOVERS", {heldEffect="HELD_BERRY", heldParameter=7}); '
          .. 'mod.content.held_items:patch("BERRY", {'
          .. bad
          .. "})",
        api,
        format
      )
      T.check(#failed.errors > 0, "invalid definition rejected: " .. bad)
      T.same(d.items, before, "entry validation rolls back all of its held writes")
      T.eq(failed.loader.exports.probe, nil, "failed entry exports retired")
      failed.release()
    end
  end
end
V.set(old)
T.finish("held_items authority, reload, freeze and transactional rollback")
