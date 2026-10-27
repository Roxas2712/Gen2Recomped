-- Edition-scoped localization for names which become part of a save file.
--
-- Renderer replacements are deliberately wrong for these values: an NPC
-- trade or scripted gift copies its nickname / OT into the permanent mon
-- record.  Patch only the cartridge data row or the exact special which owns
-- the value, and require the expected US value before changing a field.

local Names = {}

local function target(spec)
  if type(spec) == "string" then return spec end
  return type(spec) == "table" and spec.to or nil
end

local function matches(value, spec)
  if type(spec) == "string" then return value == spec end
  if type(spec) ~= "table" then return false end
  return value == spec.from or value == spec.to
end

local function patchField(row, field, spec)
  local translated = target(spec)
  if type(row) ~= "table" or type(translated) ~= "string"
      or not matches(row[field], spec) then
    return false
  end
  row[field] = translated
  return true
end

function Names.patchTrades(rows, catalog)
  local result = { matched = 0, missing = 0, unexpected = 0 }
  rows = type(rows) == "table" and rows or {}
  catalog = type(catalog) == "table" and catalog or {}
  for index, fields in pairs(catalog) do
    local row = rows[tonumber(index) or index]
    if type(row) ~= "table" then
      result.missing = result.missing + 1
    elseif type(fields) == "table" then
      local rowMatched, rowUnexpected = false, false
      for _, field in ipairs({ "nickname", "otName" }) do
        local spec = fields[field]
        if spec ~= nil then
          if patchField(row, field, spec) then
            rowMatched = true
          else
            rowUnexpected = true
          end
        end
      end
      if rowMatched then result.matched = result.matched + 1 end
      if rowUnexpected then result.unexpected = result.unexpected + 1 end
    end
  end
  return result
end

-- gen2Scripts is a pointer-keyed table of flat command arrays.  Only the
-- trainer arm of `givepoke` persists the command's own nickname and OT.  The
-- Route-35 SPEAROW is the sole retail use, but keep the rules data-driven and
-- match both original fields so unrelated gifts and user names are untouched.
function Names.patchScriptGifts(scripts, catalog)
  local result = { matched = 0, missing = 0 }
  scripts = type(scripts) == "table" and scripts or {}
  catalog = type(catalog) == "table" and catalog or {}
  local seen = {}
  for _, commands in pairs(scripts) do
    if type(commands) == "table" then
      for _, cmd in ipairs(commands) do
        if type(cmd) == "table" and cmd.op == "givepoke"
            and tonumber(cmd.trainer or 0) ~= 0 then
          for ruleIndex, rule in ipairs(catalog) do
            if not seen[ruleIndex]
                and matches(cmd.name, rule.nickname)
                and matches(cmd.otName, rule.otName) then
              patchField(cmd, "name", rule.nickname)
              patchField(cmd, "otName", rule.otName)
              seen[ruleIndex] = true
              result.matched = result.matched + 1
              break
            end
          end
        end
      end
    end
  end
  for index in ipairs(catalog) do
    if not seen[index] then result.missing = result.missing + 1 end
  end
  return result
end

function Names.patchGen2Data(data, catalog)
  data = type(data) == "table" and data or {}
  catalog = type(catalog) == "table" and catalog or {}
  return {
    trades = Names.patchTrades(
      data.gen2EventTables and data.gen2EventTables.trades,
      catalog.trades),
    gifts = Names.patchScriptGifts(data.gen2Scripts, catalog.scriptGifts),
  }
end

local function newPartyMon(Specials, vm, before)
  local shared = Specials and Specials.shared
  local party = shared and type(shared.party) == "function"
      and shared.party(vm) or nil
  if type(party) ~= "table" or #party ~= before + 1 then return nil end
  return party[#party]
end

local function partySize(Specials, vm)
  local shared = Specials and Specials.shared
  local party = shared and type(shared.party) == "function"
      and shared.party(vm) or nil
  return type(party) == "table" and #party or 0
end

-- A Shuckle received in German may be returned after the same save is opened
-- in English (and vice versa).  Keep both official identities valid without
-- permanently changing the engine's process-global MANIA constants.
Names.GERMAN_SHUCKLE = {
  nickname = { from = "SHUCKIE", to = "MODRI" },
  otName = { from = "MANIA", to = "GABRIELE" },
}

local function stateFor(Specials)
  if type(Specials) ~= "table" or type(Specials.HANDLERS) ~= "table"
      or type(Specials.ALL) ~= "table" then
    return nil
  end
  local state = Specials.__translationGermanOfficialMonNames
  if not state then
    state = {
      giveShuckle = Specials.HANDLERS.GiveShuckle,
      giveOddEgg = Specials.HANDLERS.GiveOddEgg,
      returnShuckle = Specials.HANDLERS.ReturnShuckie,
      maniaOt = Specials.MANIA_OT,
    }
    Specials.__translationGermanOfficialMonNames = state
  end
  return state
end

local function activeRule(state, name)
  if type(state.active) ~= "function" then return nil end
  local ok, active = pcall(state.active)
  if not ok or active ~= true then return nil end
  return type(state.catalog) == "table" and state.catalog[name] or nil
end

-- ReturnShuckie is gameplay logic rather than visible localization.  Install
-- this compatibility arm even on an English boot so a save can safely cross
-- the language restart boundary.  Its behavior is otherwise byte-for-byte
-- equivalent to the engine handler and accepts the exact official English, German, Spanish, French and Italian OTs.
function Names.installGen2ReturnCompatibility(Specials)
  local state = stateFor(Specials)
  if not state or state.returnInstalled
      or type(state.returnShuckle) ~= "function" then
    return state and state.returnInstalled == true or false
  end

  local wrapper = function(vm)
    local shared = Specials.shared
    if type(shared) ~= "table"
        or type(shared.selectMon) ~= "function"
        or type(shared.answer) ~= "function"
        or type(shared.party) ~= "function"
        or Specials.MANIA_OT_ID == nil
        or Specials.SHUCKIE_WRONG_MON == nil
        or Specials.SHUCKIE_REFUSED == nil
        or Specials.SHUCKIE_RETURNED == nil
        or Specials.SHUCKIE_HAPPY == nil
        or Specials.SHUCKIE_FAINTED == nil
        or Specials.SHUCKIE_HAPPY_THRESHOLD == nil then
      return state.returnShuckle(vm)
    end

    local index, mon = shared.selectMon(vm, "choose")
    if not mon then
      shared.answer(vm, Specials.SHUCKIE_REFUSED)
      return
    end
    local originalOT = state.maniaOt or "MANIA"
    local germanOT = target(Names.GERMAN_SHUCKLE.otName)
    local validOT = mon.ot == originalOT or mon.ot == germanOT
        or mon.ot == "MANÍA" or mon.ot == "MATTIA"
    if mon.species ~= "SHUCKLE"
        or mon.otId ~= Specials.MANIA_OT_ID or not validOT then
      shared.answer(vm, Specials.SHUCKIE_WRONG_MON)
      return
    end
    if (mon.hp or 0) <= 0 then
      shared.answer(vm, Specials.SHUCKIE_FAINTED)
      return
    end
    vm.shuckieHappiness = mon.happiness or 0
    if (mon.happiness or 0) >= Specials.SHUCKIE_HAPPY_THRESHOLD then
      shared.answer(vm, Specials.SHUCKIE_HAPPY)
      return
    end
    local party = shared.party(vm)
    if type(party) ~= "table" or type(index) ~= "number" then
      -- This cannot happen with the retail VM; fail closed instead of
      -- removing an unknown slot from a third-party party implementation.
      shared.answer(vm, Specials.SHUCKIE_WRONG_MON)
      return
    end
    table.remove(party, index)
    shared.answer(vm, Specials.SHUCKIE_RETURNED)
  end
  Specials.HANDLERS.ReturnShuckie = wrapper
  Specials.ALL.ReturnShuckie = wrapper
  state.returnInstalled = true
  return true
end

-- GiveShuckle and Crystal's GiveOddEgg currently author their names in Lua,
-- outside every ROM/string catalog.  Wrap only those semantic handlers.  The
-- dispatch table is updated in place because Vm.SPECIALS holds the same ALL
-- table by reference.  An active callback makes both wrappers transparent as
-- soon as the German registry sentinel disappears during a hot unload.
function Names.installGen2Specials(Specials, catalog, active)
  local state = stateFor(Specials)
  if not state then return 0 end
  catalog = type(catalog) == "table" and catalog or {}
  state.catalog = catalog
  state.active = active
  Names.installGen2ReturnCompatibility(Specials)

  if not state.giveShuckleInstalled
      and type(state.giveShuckle) == "function" then
      local wrapper = function(vm)
        local rule = activeRule(state, "shuckle")
        if not rule then return state.giveShuckle(vm) end
        local before = partySize(Specials, vm)
        local result = state.giveShuckle(vm)
        local mon = newPartyMon(Specials, vm, before)
        if mon and matches(mon.nickname, rule.nickname)
            and matches(mon.otName or mon.ot, rule.otName) then
          patchField(mon, "nickname", rule.nickname)
          local translatedOT = target(rule.otName)
          mon.ot, mon.otName = translatedOT, translatedOT
        end
        return result
      end
      Specials.HANDLERS.GiveShuckle = wrapper
      Specials.ALL.GiveShuckle = wrapper
      state.giveShuckleInstalled = true
  end

  if not state.giveOddEggInstalled
      and type(state.giveOddEgg) == "function" then
      local wrapper = function(vm)
        local rule = activeRule(state, "oddEgg")
        if not rule then return state.giveOddEgg(vm) end
        local before = partySize(Specials, vm)
        local result = state.giveOddEgg(vm)
        local mon = newPartyMon(Specials, vm, before)
        if mon and matches(mon.nickname, rule.nickname)
            and matches(mon.otName or mon.ot, rule.otName) then
          patchField(mon, "nickname", rule.nickname)
          local translatedOT = target(rule.otName)
          mon.ot, mon.otName = translatedOT, translatedOT
        end
        return result
      end
      Specials.HANDLERS.GiveOddEgg = wrapper
      Specials.ALL.GiveOddEgg = wrapper
      state.giveOddEggInstalled = true
  end

  local shuckle = catalog.shuckle
  local installed = 0
  if shuckle and type(state.giveShuckle) == "function" then installed = installed + 1 end
  if catalog.oddEgg and type(state.giveOddEgg) == "function" then installed = installed + 1 end
  return installed
end

return Names
