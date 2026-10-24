-- Exact import-symbol facts are loaded only when a native prose consumer or
-- registry needs them. Never identify a label by matching its rendered words.
local Labels = {}
local cache = {}
local supported = { gold = true, silver = true, crystal = true, firered = true, emerald = true }
function Labels.forVersion(version)
  if not supported[version] then
    return nil
  end
  if not cache[version] then
    cache[version] = require("src.mods.rom_text_labels." .. version)
  end
  return cache[version]
end
function Labels.address(version, name)
  local rows = Labels.forVersion(version)
  if not rows or not rows.text then
    return nil
  end
  local offset = rows.battle[name]
  if offset then
    return offset, true
  end
  return rows.text[name], false
end
return Labels
