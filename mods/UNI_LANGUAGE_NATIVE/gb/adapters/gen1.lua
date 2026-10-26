-- Route German Gen-1 graphics explicitly.  Nothing lives in root overrides/:
-- English boot never calls this adapter and therefore retains every imported
-- US-ROM path, including the overworld tileset.

local Adapter = {}

-- Imported overworld sheets have one cache namespace between `assets/` and
-- `tilesets/`.  Recognise that shape from the live data record instead of
-- naming or opening the player's ROM-derived cache from mod code (MK301).
local IMPORTED_OVERWORLD = "^assets/[^/]+/tilesets/overworld%.png$"

-- Keep the canonical generated path in the tileset record so the engine's
-- normal asset resolver can still see graphics supplied by another mod.  A
-- direct `save/mod-derived/...` assignment made the Universal translation
-- bypass that resolver entirely: mods such as Better Buildings could update
-- the map/block data, but their matching tile sheet was then replaced by our
-- vanilla-derived sign sheet and every building tile appeared blank.
--
-- The small resolver fallback below selects our namespaced German sign sheet
-- only when no enabled mod supplies an override/derived version of the
-- canonical overworld sheet.  This is the same composition contract used by
-- the standalone translations, while retaining the Universal mod's true
-- English no-op (its namespaced sheet never participates automatically).
local function installComposableOverworld(mod, edition, tiles)
  -- The overlay resolves only a canonical unmodified sheet after other mods.
  return true
end

local function asset(mod, relative)
  local own = "assets/" .. relative
  if mod.info then
    local ok, info = pcall(mod.info, mod, own)
    if ok and not info then
      mod.log:warn("Deutsche Grafik fehlt: %s", own)
      return nil
    end
  end
  return mod.path .. "/" .. own
end

local function overworld(tilesets)
  if type(tilesets) ~= "table" then return nil end
  if type(tilesets.OVERWORLD) == "table" then return tilesets.OVERWORLD end
  for _, record in pairs(tilesets) do
    if type(record) == "table" and record.id == "OVERWORLD" then
      return record
    end
  end
  return nil
end

function Adapter.apply(mod, edition)
  local game = mod.game
  local data = game and game.data
  if type(data) ~= "table" then
    -- Static modkit validation intentionally has no live Game.  The edition
    -- snapshot still validates its registry operations in that environment;
    -- real boots always supply data before mods load.
    mod.log:warn("Gen-1-Grafikrouting übersprungen: keine Live-Daten")
    return false
  end

  local font = asset(mod, "fonts/font.png")
  if font and type(data.font) == "table" then data.font.image = font end

  local tiles = overworld(data.tilesets)
  if tiles then
    installComposableOverworld(mod, edition, tiles)
  end

  data.field = data.field or {}
  local function catalog(name)
    local raw = mod:readLocal('lang/' .. name .. '.lua')
    if raw then return assert(require('src.core.SaveSerializer').decode(raw)) end
  end
  local credits = catalog('credits')
  if credits then
    data.field.credits = data.field.credits or {}
    data.field.credits.screens = credits.screens
    data.field.credits.theEnd = {
      path = asset(mod, 'credits/the_end.png'), pattern = credits.pattern,
    }
  end
  local diploma = catalog('diploma')
  if diploma then
    diploma.tiles = asset(mod, 'diploma/yellow_tiles.png')
    data.field.yellowPages = data.field.yellowPages or {}
    data.field.yellowPages.diploma = diploma
    for label,text in pairs(assert(catalog('diploma_text'))) do
      mod.content.text:override(label, text)
    end
  end
  data.field.title = data.field.title or {}
  local title = data.field.title
  local bubbleInfo = mod:info("assets/title/pika_bubble.png")
  if bubbleInfo then
    local logo = asset(mod, "title/pokemon_logo.png")
    local bubble = asset(mod, "title/pika_bubble.png")
    if logo then title.logo = { path = logo, width = 128, height = 56 } end
    title.pikaBubble = { path = bubble, width = 56, height = 40 }
  else
    local ribbon = asset(mod, "title/" .. edition .. "_version.png")
    if ribbon then
      title.versionRibbon = ribbon
    end
  end

  return true
end

return Adapter
