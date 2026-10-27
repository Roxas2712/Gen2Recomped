-- Deutsch für Pokémon Rot inside Translation German Universal.
--
-- Translates the imported US Pokémon Red dataset without modifying or
-- redistributing the player's ROM.
return function(mod)
  local GameVersion = require("src.core.GameVersion")
  if GameVersion.get() ~= "red" then
    mod.log:info("Deutsch für Pokémon Rot: in dieser Edition nicht aktiv")
    return
  end

  -- mod:read is the supported way into your own directory; the catalogs are
  -- plain Lua tables, so read and run them rather than require()ing them.
  local function catalog(name)
    local rel = "lang/" .. name .. ".lua"
    local body = mod:read(rel)
    if not body then return {} end
    local chunk, err = loadstring(body, rel)
    if not chunk then
      mod.log:warn("%s has a syntax error: %s", rel, tostring(err))
      return {}
    end
    local ok, table_ = pcall(chunk)
    if not ok or type(table_) ~= "table" then
      mod.log:warn("%s did not return a table: %s", rel, tostring(table_))
      return {}
    end
    return table_
  end

  -- An empty value means "not translated yet", never "translate to blank".
  local function each(name, apply)
    local n = 0
    for key, value in pairs(catalog(name)) do
      if type(value) == "string" and value ~= "" then
        apply(key, value)
        n = n + 1
      end
    end
    return n
  end

  -- The edition asset supplies the complete original German ROM font.  These
  -- mappings expose its native umlaut and international character slots.
  local germanCharmap = catalog("charmap")
  local germanStatusLabels = catalog("status_labels")
  local germanSpeciesNames = catalog("species_names")
  local germanItemNames = catalog("item_names")
  local germanDexMetrics = mod.shared and mod.shared.dexMetrics or {}
  for seq, code in pairs(germanCharmap) do
    mod.content.font:register("charmap:" .. seq, { seq = seq, code = code })
  end
  mod.content.font:override("main", {
    image = mod.path .. "/assets/fonts/font.png",
    base = 0x80,
    glyphsPerRow = 16,
  })

  -- ---- text ---------------------------------------------------------
  local counts = {}
  counts.dialogue = each("dialogue", function(id, value)
    mod.content.text:override(id, value)
  end)
  local germanStrings = catalog("strings")
  counts.strings = 0
  for source, value in pairs(germanStrings) do
    if type(value) == "string" and value ~= "" then
      mod.content.strings:override(source, value)
      counts.strings = counts.strings + 1
    end
  end
  local runtimeText = catalog("runtime_text")
  counts.runtimeText = 0
  for _ in pairs(runtimeText) do
    counts.runtimeText = counts.runtimeText + 1
  end
  local runtimePatterns = catalog("runtime_patterns")
  counts.runtimePatterns = #runtimePatterns
  local runtimeSentinel = "__deutsch_red_runtime_active__"
  mod.content.strings:override(runtimeSentinel, "active")
  local runtimeActive
  -- These labels are generated dynamically by the naming screen and are
  -- therefore not present in the engine-string extraction worksheet.
  mod.content.strings:register("lower case", "klein")
  mod.content.strings:register("UPPER CASE", "GROSS")
  counts.namingLabels = 2
  counts.species = 0
  for id, value in pairs(germanSpeciesNames) do
    if type(value) == "string" and value ~= "" then
      mod.content.pokemon:patch(id, { name = value })
      counts.species = counts.species + 1
    end
  end
  counts.dexKinds = each("dex_kinds", function(id, value)
    mod.content.pokemon:patch(id, { dexEntry = { kind = value } })
  end)
  counts.dexMetrics = 0
  for id, value in pairs(germanDexMetrics) do
    if type(value) == "table" and type(value.heightM) == "number"
        and type(value.weightKg) == "number" then
      mod.content.pokemon:patch(id, { dexEntry = {
        heightM = value.heightM,
        weightKg = value.weightKg,
      } })
      counts.dexMetrics = counts.dexMetrics + 1
    end
  end
  counts.moves = each("move_names", function(id, value)
    mod.content.moves:patch(id, { name = value })
  end)
  counts.items = each("item_names", function(id, value)
    mod.content.items:patch(id, { name = value })
  end)
  counts.trainers = each("trainer_names", function(id, value)
    mod.content.trainers:patch(id, { name = value })
  end)
  counts.statuses = each("status_labels", function(id, value)
    mod.content.statuses:patch(id, { label = value, hudLabel = value })
  end)
  counts.types = each("type_names", function(id, value)
    mod.content.type_chart:patch(id, { name = value })
  end)

  -- Trade nicknames are copied into the received party record. Patch the
  -- exact imported row before Commands.in_game_trade persists it; a renderer
  -- alias would leave the English nickname in every save file.
  local monNames = mod.shared and mod.shared.monNames
  local tradeRows = mod.game and mod.game.data and mod.game.data.field
    and mod.game.data.field.trades
  local tradeStats = monNames and monNames.patchTrades(
    tradeRows, catalog("mon_names").trades)
    or { matched = 0, unexpected = 0 }
  counts.tradeNames = tradeStats.matched
  if tradeStats.unexpected > 0 then
    mod.log:warn("%d Rot-Tauschzeilen hatten unerwartete Namen",
      tradeStats.unexpected)
  end

  -- Town Map names are ROM data but not part of the generator's standard
  -- translation catalogs, so patch the imported location records directly.
  local locations = {}
  counts.maps = each("map_names", function(id, value)
    locations[id] = { name = value }
  end)
  if next(locations) then
    mod.content.field:patch("townMap", { locations = locations })
  end

  -- Gen1Recomp 0.2.19 treats versionRibbon as one continuous strip and
  -- applies the cartridge slide-in offset to it.  The proxy's direct path
  -- remains edition-isolated without a second draw pass.
  mod.content.field:patch("title", {
    versionRibbon = mod.path .. "/assets/title/red_version.png",
  })

  -- Battle modules reproduce the US ROM's PlaceMoveUsersName behavior by
  -- inserting "Enemy " after the string catalog has already been applied.
  -- They also pass the English stat-name table as dynamic text.  Localize
  -- those engine-generated fragments centrally, then enforce the original
  -- two-line/18-glyph battle-box layout for every composed message.
  local Strings = require("src.core.Strings")
  local Font = require("src.render.Font")
  local BattleState = require("src.battle.BattleState")
  local ChoiceBox = require("src.ui.ChoiceBox")
  local SlotMachine = require("src.ui.SlotMachine")

  -- Choice boxes use localized glyph advances, not byte counts or a fixed
  -- English width.  Right-edge menus stay right-aligned; the save and
  -- trainer-switch boxes keep their left edge.  Four non-label tiles cover
  -- both borders, the cursor and the official German trailing inset, giving
  -- JA/NEIN the cartridge's WIDE_YES_NO_MENU geometry (12,7,8,5).
  local function germanChoiceGeometry(tx, tw, labels, rightEdge)
    if not runtimeActive or not runtimeActive() then return tx, tw end
    local widest = 0
    for _, label in ipairs(labels or { "YES", "NO" }) do
      widest = math.max(widest, Font.width(Strings(label)))
    end
    local cols = require("src.ui.Theme").cols or 20
    local required = math.min(cols,
      math.max(tw, math.ceil(widest / 8) + 4))
    if rightEdge or tx + tw >= cols then
      local edge = math.min(cols, rightEdge or (tx + tw))
      return math.max(0, edge - required), required
    end
    return tx, math.min(required, cols - tx)
  end

  if not ChoiceBox.__translationGermanDynamicGeometry then
    local patch = {
      originalNew = ChoiceBox.new,
      geometry = germanChoiceGeometry,
    }
    ChoiceBox.__translationGermanDynamicGeometry = patch
    ChoiceBox.new = function(game, onChoose, opts)
      local choice = patch.originalNew(game, onChoose, opts)
      choice.tx, choice.tw = patch.geometry(
        choice.tx, choice.tw, choice.labels)
      return choice
    end
  else
    ChoiceBox.__translationGermanDynamicGeometry.geometry =
      germanChoiceGeometry
  end

  -- The slot machine has its own hard-coded YES/NO menu.  Draw just those
  -- two stages with the same geometry helper; all other stages remain on the
  -- engine implementation and no Font function is replaced even briefly.
  local slotPatch = SlotMachine.__translationGermanDynamicChoiceGeometry
  if not slotPatch then
    slotPatch = {
      originalDrawBottom = SlotMachine.drawBottom,
      geometry = germanChoiceGeometry,
    }
    SlotMachine.__translationGermanDynamicChoiceGeometry = slotPatch
    SlotMachine.drawBottom = function(self)
      local active = slotPatch.active
      if not active or not active() then
        return slotPatch.originalDrawBottom(self)
      end
      if self.stage ~= "intro" and self.stage ~= "onemore" then
        return slotPatch.originalDrawBottom(self)
      end
      local lines = self.stage == "intro"
        and { "A slot machine!", "Want to play?" }
        or { "One more", "go?" }
      Font.drawBox(0, 12, 20, 6)
      love.graphics.setColor(0, 0, 0, 1)
      Font.draw(lines[1], 8, 14 * 8)
      Font.draw(lines[2], 8, 16 * 8)
      local by = self.stage == "intro" and 6 or 11
      local tx, tw = slotPatch.geometry(13, 6, { "YES", "NO" }, 20)
      Font.drawBox(tx, by, tw, 5)
      love.graphics.setColor(0, 0, 0, 1)
      Font.draw(Strings("YES"), (tx + 2) * 8, (by + 1) * 8)
      Font.draw(Strings("NO"), (tx + 2) * 8, (by + 2) * 8)
      Font.drawCode(0xED, (tx + 1) * 8,
        (by + 1 + (self.yesno == 1 and 0 or 1)) * 8)
      love.graphics.setColor(1, 1, 1, 1)
    end
  end
  slotPatch.geometry = germanChoiceGeometry

  -- The German cartridge widens BATTLE_MENU_TEMPLATE two tiles to the left:
  -- box (6,12)-(19,17), text at (8,14), cursors at columns 7/12.  The
  -- English geometry hard-coded by Gen1Recomp starts at column 8, so the
  -- original six-letter "FLUCHT" runs through its right border.  Replace
  -- only the classic normal command menu; Safari and wide/3D battles either
  -- already use the full width or have enough room.
  if not BattleState.__deutschOriginalDrawTextArea then
    BattleState.__deutschOriginalDrawTextArea = BattleState.drawTextArea
    BattleState.drawTextArea = function(self)
      local active = BattleState.__translationGermanGen1Active
      if not active or not active()
          or self.phase ~= "menu" or self.safari then
        return BattleState.__deutschOriginalDrawTextArea(self)
      end

      Font.drawBox(0, 12, 20, 6)
      Font.drawBox(6, 12, 14, 6)
      love.graphics.setColor(0, 0, 0, 1)
      Font.draw(Strings("FIGHT"), 64, 112)
      Font.drawCode(0xE1, 104, 112)
      Font.drawCode(0xE2, 112, 112)
      Font.draw(Strings("ITEM"), 64, 128)
      Font.draw(Strings("RUN"), 104, 128)

      if self.demo then
        Font.drawCode(0xED, 56,
          (self.demoTimer or 0) <= 80 and 112 or 128)
      else
        local col = (self.menuIndex - 1) % 2
        local row = math.floor((self.menuIndex - 1) / 2)
        Font.drawCode(0xED, col == 0 and 56 or 96, 112 + row * 16)
      end
      love.graphics.setColor(1, 1, 1, 1)
    end
  end

  local editionNames = {
    ["Red"] = "Rot",
    ["RED"] = "ROT",
    ["Pokemon Red"] = "Pokémon Rote Edition",
    ["Pokémon Red"] = "Pokémon Rote Edition",
    ["Red Version"] = "Rote Edition",
    ["RED VERSION"] = "ROTE EDITION",
    ["Red Edition"] = "Rote Edition",
    ["RED EDITION"] = "ROTE EDITION",
    ["POKéMON RED"] = "POKéMON ROTE EDITION",
  }
  local function localizeEditionName(text)
    if type(text) ~= "string" then return text end
    text = editionNames[text] or text
    text = text:gsub("%f[%a]POKéMON RED%f[%A]", "POKéMON ROTE EDITION")
    text = text:gsub("%f[%a]RED VERSION%f[%A]", "ROTE EDITION")
    text = text:gsub("%f[%a]Red Version%f[%A]", "Rote Edition")
    return text
  end

  -- Renderer-only UI and network messages may be formatted after the normal
  -- string registry has returned. Merge the two reviewed exact catalogs,
  -- compile anchored printf templates, then try the ordered pattern catalog.
  local exact = {}
  for source, translated in pairs(germanStrings) do
    if type(source) == "string" and type(translated) == "string"
        and translated ~= "" then
      exact[source] = translated
    end
  end
  for source, translated in pairs(runtimeText) do
    if type(source) == "string" and type(translated) == "string"
        and translated ~= "" then
      exact[source] = translated
    end
  end

  local patterns = {}
  for _, rule in ipairs(runtimePatterns) do
    if type(rule) == "table" and type(rule[1]) == "string"
        and type(rule[2]) == "string" then
      patterns[#patterns + 1] = rule
    end
  end

  local function escapePattern(value)
    value = value:gsub("%%%%", "%%")
    return (value:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"))
  end

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
  local function localizeRuntimeText(text)
    if type(text) ~= "string" or text == "" then return text end
    local translated = exact[text]
    if translated then return localizeEditionName(translated) end

    for _, rule in ipairs(templates) do
      local values = { text:match(rule.pattern) }
      if values[1] ~= nil then
        for index, kind in ipairs(rule.specs) do
          if kind == "c" then
            values[index] = values[index]:byte()
          elseif kind ~= "s" and kind ~= "q" then
            values[index] = tonumber(values[index]) or values[index]
          end
        end
        local ok, formatted = pcall(string.format, rule.target,
          unpackValues(values, 1, #rule.specs))
        if ok and formatted ~= text then
          text = formatted
          break
        end
      end
    end

    for _, rule in ipairs(patterns) do
      local value, changed = text:gsub(rule[1], rule[2], 1)
      if changed > 0 and value ~= text then
        text = value
        break
      end
    end
    text = localizeEditionName(text)

    -- Script substitutions use stable species ids (for example CHARMANDER)
    -- after the translated ROM sentence has already been selected.  Resolve
    -- only the received-Pokémon value, so player/rival names that happen to
    -- resemble an id are never rewritten globally.
    -- Fighting Dojo composes its result outside the ROM text system.
    local player, dojoSpecies = text:match("^(.-) got\n([^!\n]+)!$")
    local dojoName = dojoSpecies and germanSpeciesNames[dojoSpecies]
    if dojoName then text = player .. " erhält\n" .. dojoName .. "!" end

    -- Route 23 substitutes internal badge ids into otherwise localized ROM
    -- prose.  Restrict the replacement to that distinctive gate sentence.
    if text:match("^Du darfst nur\n") then
      text = text:gsub("([A-Z]+BADGE)", function(id)
        return germanItemNames[id] or id
      end)
    end

    local before, candidate, after =
      text:match("^(.- erhält\n)([^!\n]+)(!.*)$")
    if candidate then
      local article, species = candidate:match("^(ein )(.+)$")
      species = species or candidate
      local translatedSpecies = germanSpeciesNames[species]
      if translatedSpecies then
        text = before .. (article or "") .. translatedSpecies .. after
      end
    end
    return text
  end

  runtimeActive = function()
    local game = mod.game
    local liveStrings = game and game.data and game.data.strings
    return GameVersion.get() == "red"
      and type(liveStrings) == "table"
      and liveStrings[runtimeSentinel] == "active"
  end
  slotPatch.active = runtimeActive

  -- UPPER is ambiguous: naming keeps UPPER CASE -> GROSS; only the screen
  -- position option uses HÖHER.
  local ScreenPosition = require("src.core.ScreenPosition")
  ScreenPosition.__translationGermanGen1Active = runtimeActive
  if not ScreenPosition.__translationGermanGen1OriginalLabel then
    ScreenPosition.__translationGermanGen1OriginalLabel = ScreenPosition.label
    ScreenPosition.label = function(value)
      local label = ScreenPosition.__translationGermanGen1OriginalLabel(value)
      local active = ScreenPosition.__translationGermanGen1Active
      if active and active() then
        if label == "CENTER" then return "MITTE" end
        if label == "UPPER" then return "HÖHER" end
        if label == "TOP" then return "OBEN" end
      end
      return label
    end
  end

  -- Some hand-ported screens pass raw English literals directly instead of
  -- going through Strings(). Translate reviewed exact rows at both final
  -- display seams; this also covers labels such as USE on older builds.
  local TextBox = require("src.render.TextBox")
  TextBox.__translationGermanGen1Active = runtimeActive
  TextBox.__translationGermanGen1Localize = localizeRuntimeText
  if not TextBox.__translationGermanGen1OriginalNew then
    TextBox.__translationGermanGen1OriginalNew =
      TextBox.__deutschOriginalNew or TextBox.new
    TextBox.new = function(game, text, onDone, opts)
      local active = TextBox.__translationGermanGen1Active
      local translate = TextBox.__translationGermanGen1Localize
      if active and translate and active() then text = translate(text) end
      return TextBox.__translationGermanGen1OriginalNew(
        game, text, onDone, opts)
    end
  end

  -- Battle HUDs read the translated statuses registry, but the party and
  -- summary menus draw mon.status (the internal PSN/SLP/etc. id) directly.
  -- Translate those exact status ids at the final font seam so every menu
  -- displays the German three-letter label without changing save/mechanics.
  Font.__translationGermanGen1Active = runtimeActive
  Font.__translationGermanGen1Localize = localizeRuntimeText
  Font.__translationGermanGen1StatusLabels = germanStatusLabels
  if not Font.__translationGermanGen1OriginalDraw then
    Font.__translationGermanGen1OriginalDraw =
      Font.__deutschOriginalDraw or Font.draw
    Font.draw = function(text, x, y)
      local active = Font.__translationGermanGen1Active
      if active and active() then
        local translate = Font.__translationGermanGen1Localize
        local statuses = Font.__translationGermanGen1StatusLabels or {}
        if translate then text = translate(text) end
        if type(text) == "string" and statuses[text] then
          text = statuses[text]
        end
      end
      return Font.__translationGermanGen1OriginalDraw(text, x, y)
    end
  end

  -- The imported US charmap already maps "é" to $BA, while the German ROM
  -- stores it at $BC.  Registry rows are merged beside the original row and
  -- Font.load sorts equal-length sequences without a deterministic tie-break,
  -- so the US code could still win and draw the German $BA glyph ("à").  Pin
  -- every German sequence to its verified German-ROM slot after splitting.
  Font.__translationGermanGen1Charmap = germanCharmap
  if not Font.__translationGermanGen1OriginalSplit then
    Font.__translationGermanGen1OriginalSplit =
      Font.__deutschOriginalSplit or Font.split
    Font.split = function(text)
      local spans = Font.__translationGermanGen1OriginalSplit(text)
      local active = Font.__translationGermanGen1Active
      if active and active() then
        local map = Font.__translationGermanGen1Charmap or {}
        for _, span in ipairs(spans) do
          local seq = text:sub(span.from, span.to)
          local code = map[seq]
          if code then span.code = code end
        end
      end
      return spans
    end
  end

  -- TouchControlsEditor bypasses the cartridge Font. Translate skin labels
  -- before fitText, export feedback after assembly, and scope LOVE's print
  -- wrappers to one active draw. xpcall guarantees restoration on errors.
  local TouchControlsEditor = require("src.ui.TouchControlsEditor")
  TouchControlsEditor.__translationGermanGen1Localize = localizeRuntimeText
  TouchControlsEditor.__translationGermanGen1Active = runtimeActive

  if not TouchControlsEditor.__translationGermanGen1OriginalSkinLabel then
    TouchControlsEditor.__translationGermanGen1OriginalSkinLabel =
      TouchControlsEditor.skinLabel
    TouchControlsEditor.skinLabel = function(...)
      local label =
        TouchControlsEditor.__translationGermanGen1OriginalSkinLabel(...)
      local active = TouchControlsEditor.__translationGermanGen1Active
      local translate = TouchControlsEditor.__translationGermanGen1Localize
      if active and translate and active() then return translate(label) end
      return label
    end
  end

  if not TouchControlsEditor.__translationGermanGen1OriginalExportSkin then
    TouchControlsEditor.__translationGermanGen1OriginalExportSkin =
      TouchControlsEditor.exportSkin
    TouchControlsEditor.exportSkin = function(...)
      local result =
        TouchControlsEditor.__translationGermanGen1OriginalExportSkin(...)
      local active = TouchControlsEditor.__translationGermanGen1Active
      local translate = TouchControlsEditor.__translationGermanGen1Localize
      if active and translate and active()
          and type(TouchControlsEditor.exportMsg) == "string" then
        TouchControlsEditor.exportMsg =
          translate(TouchControlsEditor.exportMsg)
      end
      return result
    end
  end

  if not TouchControlsEditor.__translationGermanGen1OriginalDraw then
    TouchControlsEditor.__translationGermanGen1OriginalDraw =
      TouchControlsEditor.draw
    TouchControlsEditor.draw = function(...)
      local active = TouchControlsEditor.__translationGermanGen1Active
      local translate = TouchControlsEditor.__translationGermanGen1Localize
      local graphics = love and love.graphics
      if not (active and translate and active() and graphics
          and type(graphics.print) == "function"
          and type(graphics.printf) == "function") then
        return TouchControlsEditor.__translationGermanGen1OriginalDraw(...)
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
        return TouchControlsEditor.__translationGermanGen1OriginalDraw(
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

  local battleTerms = {
    ["ATTACK"] = "ANGR",
    ["DEFENSE"] = "VERT",
    ["SPEED"] = "INIT",
    ["SPECIAL"] = "SPEZ",
    ["ACCURACY"] = "GENA",
    ["EVADE"] = "FLU",
    ["FOE"] = "GEGNER",
    ["OLD MAN"] = "ALTER MANN",
  }

  local function generatedBattleTerms(text)
    text = localizeRuntimeText(text)
    text = text:gsub("Enemy ", "Gegn. ")
    for source, translated in pairs(battleTerms) do
      text = text:gsub("%f[%a]" .. source .. "%f[%A]", translated)
    end
    return text
  end

  local function wrapBattleLine(line)
    local result = {}
    line = line:gsub("^ +", ""):gsub(" +$", "")
    while #Font.split(line) > 18 do
      local spans = Font.split(line)
      local cut, nextSpan = 18, 19
      for i = 18, 2, -1 do
        if line:sub(spans[i].from, spans[i].to) == " " then
          cut, nextSpan = i - 1, i + 1
          break
        end
      end
      result[#result + 1] = line:sub(spans[1].from, spans[cut].to)
      line = nextSpan <= #spans and line:sub(spans[nextSpan].from) or ""
      line = line:gsub("^ +", "")
    end
    result[#result + 1] = line
    return result
  end

  local function localizeBattleText(text)
    if type(text) ~= "string" then return text end
    -- Safety net for the trainer-switch fragment. In the normal path
    -- sayChoice rejoins it with the following Pokémon name, but if another
    -- mod displays the row early it must still never leak English.
    text = text:gsub("^(.-) is\nabout to use$", "%1 wird nun\neinsetzen:")
    text = text:gsub("^(.-) is about to use$", "%1 wird nun\neinsetzen:")
    text = generatedBattleTerms(text)
    local result, pos, lineNumber = {}, 1, 0
    while true do
      local controlAt = text:find("[\n\v\f]", pos)
      local line = controlAt and text:sub(pos, controlAt - 1)
                                or text:sub(pos)
      local wrapped = wrapBattleLine(line)
      for index, part in ipairs(wrapped) do
        if index > 1 then
          result[#result + 1] = lineNumber == 0 and "\n" or "\v"
          lineNumber = lineNumber + 1
        end
        result[#result + 1] = part
      end
      if not controlAt then break end
      local control = text:sub(controlAt, controlAt)
      if control == "\f" then
        result[#result + 1] = control
        lineNumber = 0
      else
        -- A third physical line uses the ROM's CONT behavior so it scrolls
        -- into the two-line box instead of appearing outside of it.
        result[#result + 1] =
          control == "\n" and lineNumber > 0 and "\v" or control
        lineNumber = lineNumber + 1
      end
      pos = controlAt + 1
    end
    return table.concat(result)
  end

  BattleState.__translationGermanGen1Active = runtimeActive
  BattleState.__translationGermanGen1LocalizeBattle = localizeBattleText

  if not BattleState.__deutschOriginalStartMessage then
    BattleState.__deutschOriginalStartMessage = BattleState.startMessage
    BattleState.startMessage = function(self, item)
      local active = BattleState.__translationGermanGen1Active
      local translate = BattleState.__translationGermanGen1LocalizeBattle
      if active and translate and active() and item and item.text then
        item.text = translate(item.text)
      end
      return BattleState.__deutschOriginalStartMessage(self, item)
    end
  end

  -- EnemySendOutFirstMon builds _TrainerAboutToUseText as three independent
  -- English queue entries ("TRAINER is / about to use", "MON!", then the
  -- switch question).  Rejoin those fragments before they are displayed so
  -- the result follows the German ROM's complete sentence:
  --   TRAINER wird / MON in den / Kampf schicken!
  if not BattleState.__deutschOriginalSayChoice then
    BattleState.__deutschOriginalSayChoice = BattleState.sayChoice
    BattleState.sayChoice = function(self, text, onChoose)
      local active = BattleState.__translationGermanGen1Active
      if not active or not active() then
        return BattleState.__deutschOriginalSayChoice(self, text, onChoose)
      end
      local queue = self.queue or {}
      local trainerName = self.trainer and self.trainer.name

      -- Find the last two text rows instead of assuming they are the final
      -- two queue entries. Animation/wait rows may be inserted between them
      -- by the battle flow or another compatible presentation mod.
      local monIndex, aboutIndex
      for index = #queue, 1, -1 do
        if type(queue[index].text) == "string" then
          if not monIndex then
            monIndex = index
          else
            aboutIndex = index
            break
          end
        end
      end
      local about = aboutIndex and queue[aboutIndex] or nil
      local mon = monIndex and queue[monIndex] or nil
      local nextName = mon and mon.text:match("^(.-)!$") or nil
      local aboutText = about and about.text
      local isSwitchQuestion = type(text) == "string"
        and (text:find("change POKéMON", 1, true)
          or text:find("POKéMON wechseln", 1, true))
      local isTrainerSwitch = type(aboutText) == "string"
        and type(trainerName) == "string"
        and isSwitchQuestion
        and (aboutText:find("about to use", 1, true)
          or aboutText:find("einsetzen:", 1, true)
          or aboutText:find("setzt gleich ein:", 1, true))
      if isTrainerSwitch and nextName and nextName ~= "" then
        about.text = trainerName .. " wird\n" .. nextName
          .. " in den\vKampf schicken!"
        table.remove(queue, monIndex)
        text = "Möchtest Du das\nPOKéMON wechseln?"
      end
      return BattleState.__deutschOriginalSayChoice(self, text, onChoose)
    end
  end

  -- German defaults for a new game. Player-entered names and existing saves
  -- remain untouched.
  mod.content.field:patch("boot", {
    playerName = "ROT",
    rivalName = "BLAU",
    namePresets = mod.DELETE,
  })
  mod.content.field:patch("boot", {
    namePresets = {
      player = { "ROT", "ASH", "JACK" },
      rival = { "BLAU", "GARY", "JOHN" },
    },
  })

  -- ---- name entry ---------------------------------------------------
  -- The naming screen's letter grid.  Leave lang/naming.lua returning nil
  -- to keep the English alphabet.
  local grid = catalog("naming")
  if grid.upper then
    mod.hooks:wrap("ui.naming.grid", function(next, base, ctx)
      base = next(base, ctx)
      local want = ctx.lower and grid.lower or grid.upper
      return want or base
    end)
  end

  mod.events:on("game.ready", function()
    local total = 0
    for _, n in pairs(counts) do total = total + n end
    mod.log:info("Deutsch: %d Einträge geladen", total)
  end)
end
