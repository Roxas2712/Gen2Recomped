-- Official German text and graphics for the imported US Pokemon Gold data.
return function(mod)
  local GameVersion = require("src.core.GameVersion")
  if not GameVersion.isGold() then
    mod.log:info("Deutsch für Pokémon Gold: in dieser Edition nicht aktiv")
    return
  end

  local function catalog(name)
    local rel = "lang/" .. name .. ".lua"
    local body = mod:read(rel)
    if not body then
      mod.log:warn("%s fehlt", rel)
      return {}
    end
    local chunk, err = loadstring(body, rel)
    if not chunk then
      mod.log:warn("%s hat einen Syntaxfehler: %s", rel, tostring(err))
      return {}
    end
    local ok, result = pcall(chunk)
    if not ok or type(result) ~= "table" then
      mod.log:warn("%s liefert keine Tabelle: %s", rel, tostring(result))
      return {}
    end
    return result
  end

  local function eachString(name, apply)
    local count = 0
    for id, value in pairs(catalog(name)) do
      if type(value) == "string" and value ~= "" then
        apply(id, value)
        count = count + 1
      end
    end
    return count
  end

  for seq, code in pairs(catalog("charmap")) do
    mod.content.font:register("charmap:gold-de:" .. seq,
      { seq = seq, code = code })
  end

  local data = mod.game and mod.game.data or {}
  local counts = {}
  counts.dialogue = eachString("dialogue", function(id, value)
    mod.content.text:override(id, value)
  end)
  counts.strings = eachString("strings", function(source, value)
    mod.content.strings:override(source, value)
  end)
  local runtimeSentinel = "__deutsch_gold_runtime_active__"
  mod.content.strings:override(runtimeSentinel, "active")
  local runtimeActive
  counts.species = eachString("species_names", function(id, value)
    mod.content.pokemon:patch(id, { name = value })
  end)
  counts.moves = eachString("move_names", function(id, value)
    if data.moves and data.moves[id] then data.moves[id].name = value end
  end)
  counts.items = eachString("item_names", function(id, value)
    mod.content.items:patch(id, { name = value })
  end)
  counts.trainerClasses = eachString("trainer_class_names", function(id, value)
    mod.content.trainers:patch(id, { name = value })
  end)
  counts.types = eachString("type_names", function(id, value)
    mod.content.type_chart:patch(id, { name = value })
  end)
  counts.landmarks = eachString("landmark_names", function(id, value)
    mod.content.landmarks:patch(id, { name = value })
  end)

  -- The current Gen 2 registry exposes names but not the cartridge's item /
  -- move descriptions, individual trainer names or Pokedex record. They are
  -- already loaded before mod entry points run, so update only those textual
  -- leaves on the live Gold data. No gameplay values are replaced.
  for id, value in pairs(catalog("move_descriptions")) do
    if data.moves and data.moves[id] and type(value) == "string" then
      data.moves[id].description = value
    end
  end
  for id, value in pairs(catalog("item_descriptions")) do
    if data.items and data.items[id] and type(value) == "string" then
      data.items[id].description = value
    end
  end
  for key, value in pairs(catalog("trainer_names")) do
    local classId, index = tostring(key):match("^(.-):(%d+)$")
    local class = data.gen2Trainers and data.gen2Trainers.classes
      and data.gen2Trainers.classes[classId]
    local trainer = class and class.trainers and class.trainers[tonumber(index)]
    if trainer and type(value) == "string" then trainer.name = value end
  end
  -- NPC trades and the Route-35 named gift copy these values into permanent
  -- mon records. Apply the official German rows at their data sources, then
  -- scope the Lua-authored Shuckle gift to its semantic special handler.
  local monNames = mod.shared and mod.shared.monNames
  local monNameCatalog = catalog("mon_names")
  local monNameStats = monNames and monNames.patchGen2Data(
    data, monNameCatalog) or {}
  counts.tradeNames = monNameStats.trades and monNameStats.trades.matched or 0
  counts.scriptGiftNames = monNameStats.gifts and monNameStats.gifts.matched or 0
  if monNames then
    local okSpecials, Specials = pcall(require, "src.script.gen2.Specials")
    if okSpecials then
      counts.specialGiftNames =
        monNames.installGen2Specials(Specials, monNameCatalog, function()
          return runtimeActive and runtimeActive() or false
        end)
    end
  end
  local pokedex = data.gen2Pokedex and data.gen2Pokedex.entries
  for id, translated in pairs(catalog("dex_entries")) do
    local entry = pokedex and pokedex[id]
    if entry and type(translated) == "table" then
      entry.kind = translated.kind or entry.kind
      -- Preserve the imported US height/weight words: Gen-2 Heavy Ball logic
      -- consumes the imperial weight.  The adapter reads the separate German
      -- dm/hg catalog when it renders the localized Pokédex screen.
      entry.text = translated.text or entry.text
      entry.text2 = translated.text2 or entry.text2
    end
  end

  -- The German POKéCOM radio plaque is two tiles wider than the US one.
  -- Its localized sheet therefore needs the matching eight-cell tilemap
  -- delta; the clock and phone cards are byte-identical between both ROMs.
  local gearDelta = catalog("pokegear_radio_tilemap")
  local gear = data.gen2MenuGfx and data.gen2MenuGfx.pokegear
  local radioMap = gear and gear.cards and gear.cards.radio
  counts.gearCells = 0
  if type(radioMap) == "table" and type(gearDelta.cells) == "table" then
    local width = tonumber(gearDelta.width) or 20
    local height = tonumber(gearDelta.height) or 18
    for _, cell in ipairs(gearDelta.cells) do
      local x, y, tile = tonumber(cell.x), tonumber(cell.y), tonumber(cell.tile)
      if x and y and tile and x >= 0 and x < width and y >= 0 and y < height then
        radioMap[y * width + x + 1] = tile
        counts.gearCells = counts.gearCells + 1
      end
    end
  end

  -- The Gold intro imports its own US-ROM text table.  That table has higher
  -- priority than OakSpeech's Strings-backed fallbacks, so replace the text
  -- leaves with the official German-ROM blocks while keeping all pictures,
  -- music and timing from the imported data.
  local oak = catalog("oak_speech")
  local oakData = mod.game and mod.game.oakSpeechData
  if mod.game and type(oakData) ~= "table" then
    oakData = {}
    mod.game.oakSpeechData = oakData
  end
  if type(oakData) == "table" then
    oakData.text = type(oakData.text) == "table" and oakData.text or {}
    counts.oak = 0
    for key, value in pairs(oak) do
      if type(key) == "string" and type(value) == "string" and value ~= "" then
        oakData.text[key] = value
        counts.oak = counts.oak + 1
      end
    end
  end

  -- A number of Gen-2 screens still author labels and composed messages
  -- directly instead of routing them through src.core.Strings.  Localize at
  -- the three shared rendering boundaries so text is translated BEFORE its
  -- width, wrapping and pagination are calculated.  The wrappers are
  -- installed once and keep their implementation in module fields so a dev
  -- hot reload updates the catalogs without stacking another wrapper.
  local exact = {}
  local function mergeExact(name)
    for source, translated in pairs(catalog(name)) do
      if type(source) == "string" and type(translated) == "string"
          and translated ~= "" then
        exact[source] = translated
      end
    end
  end
  mergeExact("runtime_ui")
  mergeExact("runtime_battle")
  mergeExact("runtime_system")

  -- The asset-free TrainerCard fallback is the only visible path that emits
  -- badge ids, and it truncates every id to four columns before printing.
  -- Keep those aliases out of the global exact map: otherwise a player or
  -- Pokemon nicknamed HIVE/FOG/SOUL would be translated as if it were UI.
  -- A slot-scoped Chrome hook below applies the compact targets instead.
  local trainerCardBadgeLabels = {}
  for _, badgeId in ipairs({
    "ZEPHYR", "HIVE", "PLAIN", "FOG", "STORM", "MINERAL", "GLACIER",
    "RISING", "BOULDER", "CASCADE", "THUNDER", "RAINBOW", "SOUL",
    "MARSH", "VOLCANO", "EARTH",
  }) do
    local translated = exact[badgeId]
    if translated then
      trainerCardBadgeLabels[badgeId:sub(1, 4)] = translated
      exact[badgeId] = nil
    end
  end

  -- Some Gen-2 code composes visible strings from internal ids only after the
  -- normal registries have returned.  Keep those ids intact in game data, but
  -- resolve them at the render boundary (radio species, trainer items,
  -- disabled moves and decoration species are the important callers).
  local function aliasCatalog(name)
    local aliases = {}
    for source, translated in pairs(catalog(name)) do
      if type(source) == "string" and type(translated) == "string"
          and translated ~= "" and translated ~= source then
        aliases[source] = translated
      end
    end
    return aliases
  end
  local speciesAliases = aliasCatalog("species_names")
  local moveAliases = aliasCatalog("move_names")
  local itemAliases = aliasCatalog("item_names")

  local patterns = {}
  local function appendPatterns(name)
    for _, rule in ipairs(catalog(name)) do
      if type(rule) == "table" and type(rule[1]) == "string"
          and type(rule[2]) == "string" then
        patterns[#patterns + 1] = rule
      end
    end
  end
  appendPatterns("runtime_patterns")
  appendPatterns("runtime_system_patterns")

  local function escapePattern(value)
    -- A source format's `%%` has already become one literal percent by the
    -- time its composed text reaches the renderer.
    value = value:gsub("%%%%", "%%")
    return (value:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"))
  end

  -- Pocket names are inserted into an otherwise already translated message,
  -- so an exact lookup cannot see them on its own.  These four values are the
  -- ItemPocketNames table from German Gold.
  local embeddedPhrases = {
    { "ITEM POCKET", "ITEM-TASCHE" },
    { "KEY POCKET", "BASIS-ITEMS" },
    { "BALL POCKET", "BALL-TASCHE" },
    { "TM POCKET", "TM-TASCHE" },
  }

  local Pokegear
  local MapRadio
  local TrainerCard
  local decorationStandalone = {
    MAGNAPLANT = true,
    TROPICPLANT = true,
    JUMBOPLANT = true,
    ["TOWN MAP"] = true,
    ["SUPER NES"] = true,
    NINTENDO64 = true,
    ["SURF PIKACHU DOLL"] = true,
    ["GOLD TROPHY"] = true,
    ["SILVER TROPHY"] = true,
  }
  local function resolveEmbeddedNames(text)
    for _, alias in ipairs(embeddedPhrases) do
      text = text:gsub(escapePattern(alias[1]), alias[2])
    end

    -- Oak's and Mary's radio lines keep an internal species id until their
    -- final concatenation.  Resolve only that field: globally replacing every
    -- species-like token would also rename a user-chosen nickname.
    local species = text:match("^OAK: ([%u%d_]+)$")
    if species and speciesAliases[species] then
      text = "OAK: " .. speciesAliases[species]
    end
    species = text:match("^MARY: ([%u%d_]+)'s$")
    if species and speciesAliases[species] then
      text = "MARY: " .. speciesAliases[species] .. "'s"
    end

    -- The Pokedex radio show draws just the id on one line.  The draw wrapper
    -- below marks that narrow context so a nicknamed Pokemon with the same
    -- spelling remains untouched everywhere else.
    local drawingRadio = (Pokegear and Pokegear.__deutschGoldDrawingRadio)
      or (MapRadio and MapRadio.__deutschGoldDrawingRadio)
    if drawingRadio
        and speciesAliases[text] then
      text = speciesAliases[text]
    end

    -- Other callers expose ids inside distinctive, fully authored messages.
    local lead, id = text:match("^(.- TRANSFORMED into )([%u%d_]+)!$")
    if lead and speciesAliases[id] then
      text = lead .. speciesAliases[id] .. "!"
    end
    local owner
    owner, id = text:match("^(.-)'s ([%u%d_]+) was disabled!$")
    if owner and moveAliases[id] then
      text = owner .. "'s " .. moveAliases[id] .. " was disabled!"
    end
    owner, id = text:match("^(.-)'s ([%u%d_]+) is DISABLED!$")
    if owner and moveAliases[id] then
      text = owner .. "'s " .. moveAliases[id] .. " is DISABLED!"
    end
    local actor
    actor, id = text:match("^(.-) used ([%u%d_]+)!$")
    local usedName = id and (itemAliases[id] or moveAliases[id])
    if actor and usedName then
      text = actor .. " used " .. usedName .. "!"
    end

    -- Pokedex and decoration code likewise assembles a translated suffix
    -- around an untranslated base id.
    species = text:match("^([%u%d_]+)'S NEST$")
    if species and speciesAliases[species] then
      text = speciesAliases[species] .. "'S NEST"
    end
    local decoPrefix, decoText = "", text
    if decoText:sub(1, 4) == "und " then
      decoPrefix, decoText = "und ", decoText:sub(5)
    end
    if decoPrefix ~= "" and decorationStandalone[decoText]
        and exact[decoText] then
      text = decoPrefix .. exact[decoText]
      decoText = ""
    end
    for _, suffix in ipairs({ " BED", " CARPET", " POSTER", " DOLL" }) do
      if decoText:sub(-#suffix) == suffix then
        local base = decoText:sub(1, -#suffix - 1)
        local translatedBase = exact[base] or speciesAliases[base]
        if translatedBase then text = decoPrefix .. translatedBase .. suffix end
        break
      end
    end
    local big = decoText:match("^BIG ([%u%d_]+)$")
    if big then
      text = decoPrefix .. "RIESIGES " .. (speciesAliases[big] or big)
    end
    return text
  end

  -- Direct UI code often formats a literal before handing it to the shared
  -- renderer.  Compile those catalog keys into anchored matchers so e.g.
  -- "Give %s" also catches the already-composed "Give PIKACHU".  Captures
  -- are passed back through the translated format string in the same order.
  local templates = {}
  local formatToken = "%%[-+ #0]*%d*%.?%d*[cdiouxXeEfgGqs]"
  for source, translated in pairs(exact) do
    local cursor, chunks, specs = 1, {}, {}
    while true do
      local first, last = source:find(formatToken, cursor)
      if not first then break end
      chunks[#chunks + 1] = escapePattern(source:sub(cursor, first - 1))
      local spec = source:sub(first, last)
      local kind = spec:sub(-1)
      specs[#specs + 1] = kind
      if kind == "s" or kind == "q" then
        chunks[#chunks + 1] = "(.-)"
      elseif kind == "c" then
        chunks[#chunks + 1] = "(.)"
      else
        chunks[#chunks + 1] = "([+-]?[%d%.eE]+)"
      end
      cursor = last + 1
    end
    if #specs > 0 then
      chunks[#chunks + 1] = escapePattern(source:sub(cursor))
      templates[#templates + 1] = {
        source = source,
        target = translated,
        pattern = "^" .. table.concat(chunks) .. "$",
        specs = specs,
      }
    end
  end
  table.sort(templates, function(a, b) return #a.source > #b.source end)

  local unpackValues = unpack or table.unpack
  local function localize(text)
    if type(text) ~= "string" or text == "" then return text end
    local translated = exact[text]
    if translated then return translated end

    -- Resolve embedded data ids before matching composed-message patterns.
    text = resolveEmbeddedNames(text)
    translated = exact[text]
    if translated then return translated end

    for _, rule in ipairs(templates) do
      local values = { text:match(rule.pattern) }
      if values[1] ~= nil then
        for i, kind in ipairs(rule.specs) do
          if kind == "c" then
            values[i] = values[i]:byte()
          elseif kind ~= "s" and kind ~= "q" then
            values[i] = tonumber(values[i]) or values[i]
          end
        end
        local ok, formatted = pcall(string.format, rule.target,
          unpackValues(values, 1, #rule.specs))
        -- Identity templates such as "%s." are useful catalog coverage for
        -- one composing screen, but must not shadow a more specific dynamic
        -- pattern (for example "PIKACHU was released.").
        if ok and formatted ~= text then return formatted end
      end
    end

    for _, rule in ipairs(patterns) do
      local value, changed = text:gsub(rule[1], rule[2], 1)
      if changed > 0 and value ~= text then return value end
    end
    return text
  end

  runtimeActive = function()
    -- Read the freshly reloaded Data table, not Strings' cached catalog.
    -- Gen1Recomp 0.2.22 restores Data during F5 hot reload without rebinding
    -- Strings, so the live sentinel is the reliable hot-unload guard.
    local game = mod.game
    local liveStrings = game and game.data and game.data.strings
    return GameVersion.isGold()
      and type(liveStrings) == "table"
      and liveStrings[runtimeSentinel] == "active"
  end

  -- `UPPER` is ambiguous: the naming screen means upper-case letters
  -- (`GROSS`), while the port's screen-position option means the intermediate
  -- position between centred and top. Translate that option at its semantic
  -- source instead of globally changing the naming-screen label.
  local ScreenPosition = require("src.core.ScreenPosition")
  ScreenPosition.__deutschGoldActive = runtimeActive
  if not ScreenPosition.__deutschGoldOriginalLabel then
    ScreenPosition.__deutschGoldOriginalLabel = ScreenPosition.label
    ScreenPosition.label = function(value)
      local label = ScreenPosition.__deutschGoldOriginalLabel(value)
      local active = ScreenPosition.__deutschGoldActive
      if active and active() then
        if label == "CENTER" then return "MITTE" end
        if label == "UPPER" then return "HÖHER" end
        if label == "TOP" then return "OBEN" end
      end
      return label
    end
  end

  -- TouchControlsEditor uses LOVE's window font and calls print/printf
  -- directly, outside the cartridge render boundaries above. Scope those
  -- two functions to one active German draw pass only; xpcall guarantees
  -- restoration even when the editor or a graphics backend raises. The
  -- wrappers around skinLabel/exportSkin run at the semantic source so skin
  -- ids and export paths are localized before truncation and after assembly.
  local TouchControlsEditor = require("src.ui.TouchControlsEditor")
  TouchControlsEditor.__deutschGoldLocalize = localize
  TouchControlsEditor.__deutschGoldActive = runtimeActive

  if not TouchControlsEditor.__deutschGoldOriginalSkinLabel then
    TouchControlsEditor.__deutschGoldOriginalSkinLabel =
      TouchControlsEditor.skinLabel
    TouchControlsEditor.skinLabel = function(...)
      local label = TouchControlsEditor.__deutschGoldOriginalSkinLabel(...)
      local active = TouchControlsEditor.__deutschGoldActive
      local translate = TouchControlsEditor.__deutschGoldLocalize
      if active and translate and active() then return translate(label) end
      return label
    end
  end

  if not TouchControlsEditor.__deutschGoldOriginalExportSkin then
    TouchControlsEditor.__deutschGoldOriginalExportSkin =
      TouchControlsEditor.exportSkin
    TouchControlsEditor.exportSkin = function(...)
      local result = TouchControlsEditor.__deutschGoldOriginalExportSkin(...)
      local active = TouchControlsEditor.__deutschGoldActive
      local translate = TouchControlsEditor.__deutschGoldLocalize
      if active and translate and active()
          and type(TouchControlsEditor.exportMsg) == "string" then
        TouchControlsEditor.exportMsg =
          translate(TouchControlsEditor.exportMsg)
      end
      return result
    end
  end

  if not TouchControlsEditor.__deutschGoldOriginalDraw then
    TouchControlsEditor.__deutschGoldOriginalDraw = TouchControlsEditor.draw
    TouchControlsEditor.draw = function(...)
      local active = TouchControlsEditor.__deutschGoldActive
      local translate = TouchControlsEditor.__deutschGoldLocalize
      local graphics = love and love.graphics
      if not (active and translate and active() and graphics
          and type(graphics.print) == "function"
          and type(graphics.printf) == "function") then
        return TouchControlsEditor.__deutschGoldOriginalDraw(...)
      end

      local originalPrint, originalPrintf = graphics.print, graphics.printf
      graphics.print = function(text, ...)
        return originalPrint(translate(text), ...)
      end
      graphics.printf = function(text, ...)
        return originalPrintf(translate(text), ...)
      end

      local args = { n = select("#", ...), ... }
      local function invoke()
        return TouchControlsEditor.__deutschGoldOriginalDraw(
          unpackValues(args, 1, args.n))
      end
      local function trace(err)
        if debug and type(debug.traceback) == "function" then
          return debug.traceback(tostring(err), 2)
        end
        return tostring(err)
      end
      local ok, result = xpcall(invoke, trace)
      graphics.print, graphics.printf = originalPrint, originalPrintf
      if not ok then error(result, 0) end
      return result
    end
  end

  -- Mark only the radio's draw pass for the one line where the Pokedex Show
  -- renders a bare internal species id.  All other radio lines have enough
  -- surrounding text to be recognized without context.
  Pokegear = require("src.ui.gen2.Pokegear")
  if not Pokegear.__deutschGoldOriginalDrawRadio then
    Pokegear.__deutschGoldOriginalDrawRadio = Pokegear.drawRadio
    Pokegear.drawRadio = function(self)
      local previous = Pokegear.__deutschGoldDrawingRadio
      Pokegear.__deutschGoldDrawingRadio = true
      Pokegear.__deutschGoldOriginalDrawRadio(self)
      Pokegear.__deutschGoldDrawingRadio = previous
    end
  end
  MapRadio = require("src.ui.gen2.MapRadio")
  if not MapRadio.__deutschGoldOriginalDraw then
    MapRadio.__deutschGoldOriginalDraw = MapRadio.draw
    MapRadio.draw = function(self)
      local previous = MapRadio.__deutschGoldDrawingRadio
      MapRadio.__deutschGoldDrawingRadio = true
      MapRadio.__deutschGoldOriginalDraw(self)
      MapRadio.__deutschGoldDrawingRadio = previous
    end
  end

  -- The styled card uses edition-local German ROM sheets routed by the Gen-2
  -- adapter. This hook is solely for the asset-free fallback: mark only its
  -- badge pages, restore the marker after errors, and let Chrome translate
  -- only the eight fixed badge coordinates.
  TrainerCard = require("src.ui.gen2.TrainerCard")
  TrainerCard.__deutschGoldActive = runtimeActive
  if not TrainerCard.__deutschGoldOriginalDrawPlain then
    TrainerCard.__deutschGoldOriginalDrawPlain = TrainerCard.drawPlain
    TrainerCard.drawPlain = function(self, ...)
      local active = TrainerCard.__deutschGoldActive
      if not (active and active() and self
          and (self.page == 2 or self.page == 3)) then
        return TrainerCard.__deutschGoldOriginalDrawPlain(self, ...)
      end
      local previous = TrainerCard.__deutschGoldDrawingPlainBadges
      TrainerCard.__deutschGoldDrawingPlainBadges = true
      local args = { n = select("#", ...), ... }
      local function invoke()
        return TrainerCard.__deutschGoldOriginalDrawPlain(
          self, unpackValues(args, 1, args.n))
      end
      local function trace(err)
        if debug and type(debug.traceback) == "function" then
          return debug.traceback(tostring(err), 2)
        end
        return tostring(err)
      end
      local ok, result = xpcall(invoke, trace)
      TrainerCard.__deutschGoldDrawingPlainBadges = previous
      if not ok then error(result, 0) end
      return result
    end
  end

  local Font = require("src.render.Font")
  Font.__deutschGoldLocalize = localize
  Font.__deutschGoldActive = runtimeActive
  if not Font.__deutschGoldOriginalEncode then
    Font.__deutschGoldOriginalEncode = Font.encode
    Font.encode = function(text)
      local active = Font.__deutschGoldActive
      local translate = Font.__deutschGoldLocalize
      if active and translate and active() then text = translate(text) end
      return Font.__deutschGoldOriginalEncode(text)
    end
  end

  local Chrome = require("src.ui.gen2.Chrome")
  Chrome.__deutschGoldTrainerCardBadgeLabels = trainerCardBadgeLabels
  Chrome.__deutschGoldLocalize = localize
  Chrome.__deutschGoldActive = runtimeActive
  if not Chrome.__deutschGoldOriginalPrint then
    Chrome.__deutschGoldOriginalPrint = Chrome.print
    Chrome.print = function(text, tx, ty)
      local active = Chrome.__deutschGoldActive
      local labels = Chrome.__deutschGoldTrainerCardBadgeLabels
      local inBadgeSlot = TrainerCard.__deutschGoldDrawingPlainBadges
        and (ty == 10 or ty == 13)
        and type(tx) == "number" and tx >= 2 and tx <= 14
        and (tx - 2) % 4 == 0
      if inBadgeSlot and active and labels and active() then
        text = labels[text] or text
      end
      return Chrome.__deutschGoldOriginalPrint(text, tx, ty)
    end
  end
  if not Chrome.__deutschGoldOriginalWrap then
    Chrome.__deutschGoldOriginalWrap = Chrome.wrap
    Chrome.wrap = function(text, width)
      local active = Chrome.__deutschGoldActive
      local translate = Chrome.__deutschGoldLocalize
      if active and translate and active() then text = translate(text) end
      return Chrome.__deutschGoldOriginalWrap(text, width)
    end
  end

  local TextBox = require("src.render.TextBox")
  TextBox.__deutschGoldLocalize = localize
  TextBox.__deutschGoldActive = runtimeActive
  if not TextBox.__deutschGoldOriginalNew then
    TextBox.__deutschGoldOriginalNew = TextBox.new
    TextBox.new = function(game, text, onDone, opts)
      local active = TextBox.__deutschGoldActive
      local translate = TextBox.__deutschGoldLocalize
      if active and translate and active() then text = translate(text) end
      return TextBox.__deutschGoldOriginalNew(game, text, onDone, opts)
    end
  end

  counts.runtime = 0
  for _ in pairs(exact) do counts.runtime = counts.runtime + 1 end
  counts.patterns = #patterns

  mod.log:info(
    "Deutsch für Pokémon Gold aktiv: %d Dialoge, %d Engine-Texte, %d Laufzeittexte, %d Muster, %d Eich-Texte, %d PokéCom-Kacheln",
    counts.dialogue or 0, counts.strings or 0, counts.runtime or 0,
    counts.patterns or 0, counts.oak or 0, counts.gearCells or 0)
end
