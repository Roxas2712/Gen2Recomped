-- Loaded as a real mod. The observer and pixel decoder use public data only.
local mod = ...
local r = assert(mod.renderData)
mod.exports.supports = function(v) return r:supportsAnimation(v) end
mod.exports.read = function(id, target) return r:animatedTileset(1, id, target) end
mod.exports.base = function(id, target) return r:tileset(1, id, target) end
function mod.exports.layer(graphics, mid, layer)
  local function bank(id, split)
    if id < split then return graphics.primary, id end
    return graphics.secondary, id - split
  end
  local meta, localId = bank(mid, graphics.layout.metatilesInPrimary)
  local pixels = {}
  for i = 1, 256 do pixels[i] = string.char(0, 0, 0, 0) end
  for quadrant = 0, 3 do
    local at = localId * 16 + ((layer - 1) * 4 + quadrant) * 2 + 1
    local word = meta.metatileEntriesLE16:byte(at) + meta.metatileEntriesLE16:byte(at + 1) * 256
    local tiles, tileId = bank(word % 1024, graphics.layout.tilesInPrimary)
    local palId = math.floor(word / 4096)
    local palettes = palId < graphics.layout.palettesInPrimary and graphics.primary or graphics.secondary
    local palette = palettes.palettes[palId + 1]
    for y = 0, 7 do
      for x = 0, 7 do
        local sx = math.floor(word / 1024) % 2 == 1 and 7 - x or x
        local sy = math.floor(word / 2048) % 2 == 1 and 7 - y or y
        local b = tiles.tiles4bpp:byte(tileId * 32 + sy * 4 + math.floor(sx / 2) + 1)
        local color = sx % 2 == 0 and b % 16 or math.floor(b / 16)
        if color ~= 0 then
          local rgb = palette[color + 1]
          pixels[(math.floor(quadrant / 2) * 8 + y) * 16 + quadrant % 2 * 8 + x + 1] =
            string.char(rgb[1], rgb[2], rgb[3], 255)
        end
      end
    end
  end
  return table.concat(pixels)
end
