package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local F = require("tests.terrain_animation.fixture")
local Copy = require("src.mods.Merge").deepCopy
local Renderer = require("src.render.TileRenderer")
for _, version in ipairs({ "emerald", "firered" }) do
  local f = F.new(version, 2)
  local s, e = f.state, f.exports
  local original = { P = f.records.P, S = f.records.S, T = f.records.T }
  local function reset()
    for key, value in pairs(original) do f.records[key] = Copy(value) end
  end
  local function rejected(change)
    reset()
    change(f.records.P, f.records.S)
    local ok, value, err = pcall(e.read, s.mapId)
    T.eq(ok, true, "invalid animation source cannot throw")
    T.eq(value, nil, "invalid animation source cannot become plausible graphics")
    T.eq(err, "terrain animation data unavailable", "explicit source error")
  end
  rejected(function(p) p.animations = nil end)
  rejected(function(p) p.animations = "missing" end)
  rejected(function(p) p.animations = setmetatable({}, {}) end)
  rejected(function(p) p.animations = setmetatable(p.animations, { __metatable = false }) end)
  rejected(function(p) p.animations[3] = p.animations[1] end)
  rejected(function(p) p.animations.extra = true end)
  rejected(function(p) p.animations[1] = false end)
  rejected(function(p) p.animations[1] = setmetatable(p.animations[1], {}) end)
  rejected(function(p) p.animations[1] = setmetatable(p.animations[1], { __metatable = false }) end)
  rejected(function(p) p.metatileCount = p.metatileCount + 1 end)
  rejected(function(p, q) q.metatileCount = nil end)
  rejected(function(p, q) q.animations = nil end)
  for _, bad in ipairs({ -1, false, "1", 0.5, math.huge, 0/0 }) do
    rejected(function(p) p.animations[1].tile = bad end)
    rejected(function(p) p.animations[1].count = bad end)
    rejected(function(p) p.animations[1].step = bad end)
  end
  rejected(function(p) p.animations[1].count = 0 end)
  rejected(function(p) p.animations[1].step = 0 end)
  rejected(function(p) p.animations[1].step = 65536 end)
  rejected(function(p) p.animations[1].tile = s.split end)
  rejected(function(p) p.animations[1].count = s.split + 1 end)
  rejected(function(p, q) q.animations[1].tile = 1024 - s.split end)
  rejected(function(p) p.animations[1].frames = nil end)
  rejected(function(p) p.animations[1].frames = { F.bytes(1, 1) } end)
  rejected(function(p) p.animations[1].frames[2] = false end)
  rejected(function(p) p.animations[1].frames[2] = "short" end)
  rejected(function(p) p.animations[1].frames = setmetatable(p.animations[1].frames, {}) end)
  rejected(function(p)
    for i = 1, 257 do p.animations[1].frames[i] = F.bytes(1, 1) end
  end)
  rejected(function(p)
    for i = 2, 65 do p.animations[i] = p.animations[1] end
  end)
  rejected(function(p, q)
    for i = 2, 33 do p.animations[i] = p.animations[1]; q.animations[i] = q.animations[1] end
  end)
  rejected(function(p)
    local frames = {}
    for i = 1, 129 do frames[i] = F.bytes(1, 512) end
    p.animations = { { tile = 0, count = 512, frames = frames, step = 16 } }
  end)
  reset()
  package.loaded["src.render.TileRenderer"] = nil
  local value, err = e.read(s.mapId)
  T.eq(value, nil, "missing clock declines")
  T.eq(err, "terrain clock unavailable", "missing clock reason")
  T.eq(package.loaded["src.render.TileRenderer"], nil, "observation never loads a renderer")
  package.loaded["src.render.TileRenderer"] = Renderer
  local clock = Renderer.animFrame
  for _, bad in ipairs({ -1, false, "1", 0.5, math.huge, 0/0, 9007199254740992 }) do
    Renderer.animFrame = function() return bad end
    local absent, reason = e.read(s.mapId)
    T.eq(absent, nil, "invalid clock declines")
    T.eq(reason, "terrain clock unavailable", "invalid clock reason")
  end
  Renderer.animFrame = clock
  -- The current native renderer caps an oversized LCM at 16 and uses the
  -- shortest declared cadence for the whole pair. Preserve that exact policy.
  reset()
  f.records.P.animations[1].frames = {}
  f.records.S.animations[1].frames = {}
  for i = 1, 5 do f.records.P.animations[1].frames[i] = F.bytes(i, 1) end
  for i = 1, 7 do f.records.S.animations[1].frames[i] = F.bytes(i, 2) end
  T.eq(assert(e.read(s.mapId)).animation.frames, 16, "native cycle cap retained")
  reset()
  f.records.P.animations[1].step = nil
  f.records.S.animations = {}
  T.eq(assert(e.read(s.mapId)).animation.step, 16, "native missing-step default retained")
  reset()
  f.records.P.animations, f.records.S.animations = {}, {}
  local still = assert(e.read(s.mapId))
  T.eq(still.animation.frames, 1, "explicitly static source is supported")
  T.eq(still.primary.tiles4bpp, f.records.P.tiles, "static graphics are not rewritten")
  -- A destination beyond compressed base bytes is valid native VRAM content.
  f.records.P.animations = { { tile = 3, count = 1, step = 8,
    frames = { F.bytes(1, 1), F.bytes(2, 1) } } }
  local extended = assert(e.read(s.mapId))
  T.eq(#extended.primary.tiles4bpp, 128, "animation destination extends short base bank")
  T.eq(extended.primary.tiles4bpp:sub(65, 96), string.rep("\0", 32), "undefined gap is zero pixels like native decoder")
  T.eq(extended.primary.tiles4bpp:sub(97), F.bytes(1, 1), "unreferenced animated slots retain native frame zero")
  -- Overlapping imported/mod runs follow the native last-run-wins order.
  f.records.P.animations[2] = { tile = 3, count = 1, step = 8,
    frames = { F.bytes(8, 1), F.bytes(9, 1) } }
  T.eq(assert(e.read(s.mapId)).primary.tiles4bpp:sub(97), F.bytes(8, 1), "native overlap precedence")
  reset()
  f.records.P.tiles = string.rep("P", (s.split + 2) * 32)
  local longPrimary = assert(e.read(s.mapId))
  T.eq(longPrimary.primary.tiles4bpp:sub(s.split * 32 + 1), string.rep("P", 64),
    "unused primary tail must never receive a secondary-bank override")
  f.run.release()
end
for _, version in ipairs({ "red", "gold" }) do
  local f = F.new(version, 2)
  T.eq(f.exports.supports(1), false, "non-Gen3 negotiation remains false")
  local value, err = f.exports.read(f.state.mapId)
  T.eq(value, nil, "non-Gen3 observation declines")
  T.eq(err, "unsupported generation", "generation refusal reason")
  f.run.release()
end
T.finish("Animated terrain bounds, fallback and invalid sources")
