-- Route German Gen-2 graphics through edition-local file paths.  These are
-- ordinary Data/Game leaves, not automatic root overrides, so an English
-- boot never selects them and no live cache swap is needed.

local Adapter = {}

-- Gen 2 still spells its yes/no menus out as three separate immediate-mode
-- calls (`Chrome.box`, then `Chrome.print`, then `Chrome.cursor`) at a number
-- of screens.  The cartridge's English 6-tile box is one tile too narrow for
-- the translated NEIN.  Waiting until the matching YES print lets us
-- distinguish an actual choice from an unrelated 6x5 window; redrawing the
-- wider border happens in the same frame before either label is painted, so
-- there is no visible intermediate state.
local function installChoiceGeometry()
  local Font = require("src.render.Font")
  local ChoiceBox = require("src.ui.ChoiceBox")
  local Chrome = require("src.ui.gen2.Chrome")

  local function germanRuntimeActive()
    local pt=Font.__ulaPtbrGen2
    if pt and pt.active and pt.active() then return true end
    local gold = Font.__deutschGoldActive
    if type(gold) == "function" and gold() then return true end
    local silver = Font.__deutschSilverActive
    return type(silver) == "function" and silver() or false
  end

  local function geometry(tx, tw)
    -- A wrapper may survive a dev hot-unload, but an English catalog must
    -- remain byte-for-byte on the engine geometry.
    if not germanRuntimeActive() then return tx, tw, 0 end
    -- Font.width runs through the edition's active Font.encode wrapper, so
    -- this measures the final JA/NEIN glyph stream rather than the raw key.
    local widest = math.max(Font.width("YES"), Font.width("NO"))
    local required = math.min(Chrome.SCREEN_W or 20,
      math.max(tw, math.ceil(widest / 8) + 4))
    local nextTx = tx
    if tx + tw >= (Chrome.SCREEN_W or 20) then
      nextTx = math.max(0, tx + tw - required)
    end
    return nextTx, required, nextTx - tx
  end

  -- TextBox-backed questions (and BoxMenu's release question) use the shared
  -- Gen-1/Gen-2 ChoiceBox class rather than Chrome directly.
  if not ChoiceBox.__translationGermanGen2DynamicGeometry then
    local patch = {
      originalNew = ChoiceBox.new,
      geometry = geometry,
    }
    ChoiceBox.__translationGermanGen2DynamicGeometry = patch
    ChoiceBox.new = function(game, onChoose, opts)
      local choice = patch.originalNew(game, onChoose, opts)
      choice.tx, choice.tw = patch.geometry(choice.tx, choice.tw)
      return choice
    end
  end

  if Chrome.__translationGermanDynamicChoiceGeometry then return end

  local patch = {
    originalBox = Chrome.box,
    originalPrint = Chrome.print,
    originalCursor = Chrome.cursor,
    geometry = geometry,
    pending = nil,
  }
  Chrome.__translationGermanDynamicChoiceGeometry = patch

  Chrome.box = function(tx, ty, tw, th)
    patch.pending = nil
    local result = patch.originalBox(tx, ty, tw, th)
    if tw == 6 and th == 5 then
      patch.pending = { tx = tx, ty = ty, tw = tw, th = th }
    end
    return result
  end

  Chrome.print = function(text, tx, ty)
    local choice = patch.pending
    if choice and not choice.expanded
        and text == "YES"
        and tx == choice.tx + 2 and ty == choice.ty + 1 then
      choice.nextTx, choice.nextTw, choice.delta = patch.geometry(
        choice.tx, choice.tw)
      choice.expanded = choice.nextTw > choice.tw
      if choice.expanded then
        patch.originalBox(choice.nextTx, choice.ty,
          choice.nextTw, choice.th)
      end
      return patch.originalPrint(text, tx + (choice.delta or 0), ty)
    end
    if choice and choice.expanded
        and text == "NO"
        and tx == choice.tx + 2 and ty == choice.ty + 3 then
      return patch.originalPrint(text, tx + choice.delta, ty)
    end
    patch.pending = nil
    return patch.originalPrint(text, tx, ty)
  end

  Chrome.cursor = function(tx, ty, hollow)
    local choice = patch.pending
    if choice and choice.expanded
        and tx == choice.tx + 1
        and (ty == choice.ty + 1 or ty == choice.ty + 3) then
      patch.pending = nil
      return patch.originalCursor(tx + choice.delta, ty, hollow)
    end
    patch.pending = nil
    return patch.originalCursor(tx, ty, hollow)
  end
end

-- German Gen-2 cartridges store Pokedex measurements directly as decimetres
-- and hectograms, while the imported US records contain packed feet/inches
-- and tenths of a pound.  Keep the US records intact for game mechanics and
-- scope the separate official metric catalog to the two entry render paths:
-- the styled screen gets the German cartridge rows/coordinates, while the
-- asset-free fallback uses the same values in a compact textual form.
local function installMetricPokedexLayout(mod)
  local ok, PokedexMenu = pcall(require, "src.ui.gen2.PokedexMenu")
  if not ok or type(PokedexMenu) ~= "table"
      or type(PokedexMenu.drawEntryBody) ~= "function"
      or type(PokedexMenu.drawPlain) ~= "function"
      or type(PokedexMenu.text) ~= "function"
      or type(PokedexMenu.tile) ~= "function" then
    -- Older engine builds may not expose the styled Gen-2 Pokedex yet.  Asset
    -- routing and the rest of the translation must remain usable there.
    return false
  end
  if PokedexMenu.__translationGermanMetricLayout then return true end

  local Font = require("src.render.Font")
  local Chrome = require("src.ui.gen2.Chrome")
  local unpackValues = unpack or table.unpack
  local dexUnits = mod and mod.shared and mod.shared.dexUnits
  local dexMetrics = mod and mod.shared and mod.shared.dexMetrics

  local function germanRuntimeActive()
    local gold = Font.__deutschGoldActive
    if type(gold) == "function" and gold() then return true end
    -- Crystal deliberately shares Silver's runtime hook and active sentinel.
    local silver = Font.__deutschSilverActive
    return type(silver) == "function" and silver() or false
  end

  local function metric(entry)
    if type(entry) ~= "table" then return nil end
    -- The imported US Gen-2 words are already formatted imperial display
    -- digits (`204` means 2'04", not 20.4 m).  They are also used by Heavy
    -- Ball mechanics, so never reinterpret or overwrite them.  The localized
    -- screen reads its own lossless dm/hg catalog from German Gold instead.
    local values = type(dexMetrics) == "table"
      and dexMetrics[entry.id] or nil
    if type(values) == "table"
        and tonumber(values.heightM) and tonumber(values.weightKg) then
      return values
    end
    -- Explicit metric fields remain a safe extension point for future
    -- generations; unlike `height`/`weight`, their unit is unambiguous.
    if type(dexUnits) == "table" and type(dexUnits.normalize) == "function"
        and (entry.heightM ~= nil or entry.heightDm ~= nil) then
      local okMetric, normalized = pcall(dexUnits.normalize, entry)
      if okMetric then return normalized end
    end
    return nil
  end

  local function decimal(value, width)
    value = tonumber(value)
    if not value or value == 0 then return nil end
    -- The German G/S/C PrintNum routine prints a period.  Force that result
    -- even if the host process happens to use a comma LC_NUMERIC locale.
    return (("%" .. width .. ".1f"):format(value)):gsub(",", ".")
  end

  local function heightLine(entry, caught)
    local values = caught and metric(entry)
    local value = values and decimal(values.heightM, 4)
    return value and ("GR. " .. value .. "m") or "GR.  ???m"
  end

  local function weightLine(entry, caught)
    local values = caught and metric(entry)
    local value = values and decimal(values.weightKg, 5)
    -- The value begins immediately after GEW, exactly like the cartridge's
    -- hlcoord 12,9 PrintNum.  Small values supply their own leading spaces.
    return value and ("GEW" .. value .. "kg") or "GEW  ???kg"
  end

  local function trace(err)
    if debug and type(debug.traceback) == "function" then
      return debug.traceback(tostring(err), 2)
    end
    return tostring(err)
  end

  local function scoped(holder, key, context, fn, ...)
    local previous = holder[key]
    holder[key] = context
    local args = { n = select("#", ...), ... }
    local results
    local okCall, err = xpcall(function()
      local function pack(...)
        return { n = select("#", ...), ... }
      end
      results = pack(fn(unpackValues(args, 1, args.n)))
    end, trace)
    holder[key] = previous
    if not okCall then error(err, 0) end
    return unpackValues(results, 1, results.n)
  end

  local patch = {
    active = germanRuntimeActive,
    originalDrawEntryBody = PokedexMenu.drawEntryBody,
    originalDrawPlain = PokedexMenu.drawPlain,
    originalText = PokedexMenu.text,
    originalTile = PokedexMenu.tile,
    originalChromePrint = Chrome.print,
    styledContext = "__translationGermanMetricEntry",
    plainContext = nil,
  }
  PokedexMenu.__translationGermanMetricLayout = patch

  PokedexMenu.drawEntryBody = function(self, row, entry, ...)
    if not patch.active() then
      return patch.originalDrawEntryBody(self, row, entry, ...)
    end
    return scoped(self, patch.styledContext, {
      entry = entry,
      caught = row and row.caught == true,
    }, patch.originalDrawEntryBody, self, row, entry, ...)
  end

  PokedexMenu.text = function(self, text, tx, ty)
    local context = self and self[patch.styledContext]
    if context and (ty == 7 or ty == 9) then
      -- The English function emits each label, number half and unit in
      -- separate calls.  Replace the first call on each row with the complete
      -- German row and suppress the remaining imperial fragments.
      if tx == 9 then
        local line = ty == 7
          and heightLine(context.entry, context.caught)
          or weightLine(context.entry, context.caught)
        return patch.originalText(self, line, 9, ty)
      end
      return
    end
    return patch.originalText(self, text, tx, ty)
  end

  PokedexMenu.tile = function(self, id, tx, ty)
    local context = self and self[patch.styledContext]
    if context and ty == 7 and (id == 0x5e or id == 0x5f) then
      -- The localized dex sheet retains these two English foot/inch glyphs;
      -- the German cartridge never draws them on its metric entry screen.
      return
    end
    return patch.originalTile(self, id, tx, ty)
  end

  PokedexMenu.drawPlain = function(self, ...)
    if not patch.active() or not self or self.view ~= "entry" then
      return patch.originalDrawPlain(self, ...)
    end
    local row = type(self.current) == "function" and self:current() or nil
    local entry = row and self.dex and self.dex.entries
      and self.dex.entries[row.species]
    return scoped(patch, "plainContext", {
      entry = entry,
      caught = row and row.caught == true,
    }, patch.originalDrawPlain, self, ...)
  end

  Chrome.print = function(text, tx, ty, ...)
    local context = patch.plainContext
    if context and tx == 1 then
      if ty == 1 and context.entry then
        text = "Nr." .. tostring(text)
      elseif ty == 5 then
        text = heightLine(context.entry, context.caught)
      elseif ty == 7 then
        text = weightLine(context.entry, context.caught)
      end
    end
    return patch.originalChromePrint(text, tx, ty, ...)
  end

  return true
end

local function asset(mod, relative)
  local own = "assets/" .. relative
  local assets = mod.assets
  if type(assets) == "table" and type(assets.info) == "function" then
    local ok, info = pcall(assets.info, assets, own)
    if ok and not info then return nil end
  end
  if type(assets) == "table" and type(assets.path) == "function" then
    return assets:path(own)
  end
  return mod.path .. "/" .. own
end

local function route(container, key, mod, relative)
  if type(container) ~= "table" then return false end
  local path = asset(mod, relative)
  if not path then return false end
  container[key] = path
  return true
end

local function basename(path)
  return type(path) == "string" and path:match("([^/]+)%.png$") or nil
end

function Adapter.apply(mod, edition)
  local game = mod.game
  local data = game and game.data
  if type(data) ~= "table" then
    mod.log:warn("Gen-2-Grafikrouting übersprungen: keine Live-Daten")
    return false
  end

  installChoiceGeometry()
  installMetricPokedexLayout(mod)

  local font = data.font
  route(font, "image", mod, "fonts/font.png")
  route(font, "imageBattleExtra", mod, "fonts/font_battle_extra.png")
  if game.fontData ~= font and type(game.fontData) == "table" then
    route(game.fontData, "image", mod, "fonts/font.png")
    route(game.fontData, "imageBattleExtra", mod,
      "fonts/font_battle_extra.png")
  end

  local title = game.titleData
  if edition == "crystal" then
    -- Crystal's title is a different renderer/layout from Gold/Silver.  Its
    -- static logo contains the localized KRISTALL-EDITION wordmark; never
    -- feed the 128x48 Gold/Silver title sheets into these fields.
    route(title, "screen", mod, "title/crystal_screen.png")
    route(title, "screenGray", mod, "title/crystal_screen_gray.png")
    route(title, "image", mod, "title/crystal_logo.png")
    route(title, "wordmark", mod, "title/crystal_wordmark.png")
  else
    route(title, "screen", mod, "title/title_screen.png")
    route(title, "screenGray", mod, "title/title_screen_gray.png")
    route(title, "image", mod, "title/pokemon_logo.png")
    route(title, "copyright", mod, "title/copyright.png")
    route(title, "copyrightSplash", mod, "title/copyright_splash.png")
    -- Gold ships localized cloud sheets; Silver intentionally keeps its own
    -- US/DE-identical Lugia cloud animation when these files are absent.
    route(title, "clouds", mod, "title/clouds.png")
    route(title, "cloudsGray", mod, "title/clouds_gray.png")
  end

  local gfx = data.gen2MenuGfx
  if type(gfx) == "table" then
    route(gfx.battleHud, "hpBar", mod, "battle/hud/hp_bar.png")
    route(gfx.battleHud, "battleExtra", mod,
      "fonts/font_battle_extra.png")
    route(gfx.pack, "menu", mod, "pack/menu.png")
    route(gfx.pokedex, "tiles", mod, "pokedex/dex.png")
    route(gfx.pokegear, "tiles", mod, "pokegear/gear.png")
    -- TrainerCard's styled path draws ID-Nr. from the last two `card` tiles
    -- and ORDEN from the last five `leaders` tiles. Both sheets come from the
    -- matching language ROM when supplied. PT-BR also localizes the status
    -- plaque; OAM and badge geometry stay on the imported game data.
    route(gfx.trainerCard, "card", mod, "trainer_card/card.png")
    route(gfx.trainerCard, "status", mod, "trainer_card/status.png")
    if edition == "crystal" then
      route(gfx.trainerCard, "cardFemale", mod,
        "trainer_card/card_f.png")
    end
    route(gfx.trainerCard, "leaders", mod,
      "trainer_card/leaders.png")
  end

  route(data.gen2Credits, 'theEnd', mod, 'credits/theend.png')
  route(data.gen2Diploma, 'image', mod, 'diploma/diploma.png')

  for _, record in pairs(data.gen2Tilesets or {}) do
    if type(record) == "table" then
      local name = basename(record.image)
      if name == "johto" or name == "johto_modern" or name == "kanto" then
        route(record, "image", mod, "tilesets/" .. name .. ".png")
      end
    end
  end

  return true
end

return Adapter
