-- Materialize the native Gen3 animation frame on detached source graphics.
-- No graphics resources, file IO, engine cache or animation clock is created.
local Tiles = require("src.render.Gen3Tiles")
local M = {}
local function integer(v, lo, hi)
  return type(v) == "number" and v == math.floor(v) and v >= lo and v <= hi
end
local function dense(t, maximum)
  if type(t) ~= "table" or getmetatable(t) ~= nil or #t > maximum then return false end
  local n = 0
  for k in pairs(t) do
    if not integer(k, 1, #t) then return false end
    n = n + 1
  end
  return n == #t
end
local function validate(pair, layout)
  local runs, bytes = 0, 0
  for _, name in ipairs({ "primary", "secondary" }) do
    local record = pair[name]
    if not dense(record.animations, 64) then return false end
    if record.metatileCount ~= #record.metatiles / 16 then return false end
    local limit = name == "primary" and layout.tilesInPrimary or 1024 - layout.tilesInPrimary
    for _, a in ipairs(record.animations) do
      if type(a) ~= "table" or getmetatable(a) ~= nil or not integer(a.tile, 0, limit - 1)
        or not integer(a.count, 1, limit) or a.tile + a.count > limit
        or (a.step ~= nil and not integer(a.step, 1, 65535))
        or not dense(a.frames, 256) or #a.frames < 2 then
        return false
      end
      runs = runs + 1
      if runs > 64 then return false end
      for _, frame in ipairs(a.frames) do
        if type(frame) ~= "string" or #frame ~= a.count * 32 then return false end
        bytes = bytes + #frame
        if bytes > 2097152 then return false end
      end
    end
  end
  return true
end
local function palettes(bank)
  local bytes = {}
  for _, p in ipairs(bank.palettes) do
    for _, rgb in ipairs(p) do bytes[#bytes + 1] = string.char(rgb[1], rgb[2], rgb[3]) end
  end
  return table.concat(bytes)
end
function M.materialize(out, pair, ticks)
  if not integer(ticks, 0, 9007199254740991) then return nil, "terrain clock unavailable" end
  if not validate(pair, out.layout) then return nil, "terrain animation data unavailable" end
  -- A new private decoder, never the native renderer's shared decoder.
  -- Reuse its cadence, 16-frame cap, run precedence and source-bank rules.
  local tiles = Tiles.new(pair, out.layout)
  local movers = tiles:animatedMetatiles()
  local frames = #movers > 0 and tiles:animFrameCount() or 1
  local step = tiles:animStep()
  local frame = math.floor(ticks / step) % frames
  tiles:setAnimFrame(frame)
  local overrides = tiles.tileOverride or {}
  for _, name in ipairs({ "primary", "secondary" }) do
    local bank = out[name]
    local offset = name == "primary" and 0 or out.layout.tilesInPrimary
    local limit = name == "primary" and out.layout.tilesInPrimary or 1024 - offset
    local last, chunks = #bank.tiles4bpp / 32, {}
    for index in pairs(overrides) do
      if index >= offset and index < offset + limit then last = math.max(last, index - offset + 1) end
    end
    for index = 0, last - 1 do
      chunks[#chunks + 1] = (index < limit and overrides[offset + index])
        or bank.tiles4bpp:sub(index * 32 + 1, index * 32 + 32)
      if #chunks[#chunks] ~= 32 then chunks[#chunks] = string.rep("\0", 32) end
    end
    bank.tiles4bpp = table.concat(chunks)
    bank.paletteRGB8 = palettes(bank)
  end
  out.graphicsState = "animated-source"
  out.animation = { ticks = ticks, frame = frame, frames = frames, step = step }
  M.rekey(out)
  return out
end
function M.rekey(out, prefix)
  -- A bounded, exact content token, not a hash/revision or engine resource.
  -- Ignore ticks: a stable picture must not invalidate on every clock tick.
  local key = { prefix or "gen3-animated-source-v1" }
  local function append(s) key[#key + 1] = #s .. ":" .. s end
  append(out.id)
  for _, field in ipairs({ "tilesInPrimary", "metatilesInPrimary", "palettesInPrimary", "metatileLayers" }) do
    append(tostring(out.layout[field]))
  end
  for _, name in ipairs({ "primary", "secondary" }) do
    local bank = out[name]
    for _, field in ipairs({ "tiles4bpp", "metatileEntriesLE16", "layerTypes", "paletteRGB8" }) do
      append(bank[field])
    end
  end
  out.contentKey = table.concat(key)
end
return M
