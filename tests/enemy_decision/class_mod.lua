-- Appended unchanged to the public consumer by the shared loader fixture.
local registered = mod.content.ai_classes:register("PORTABLE_NATIVE_CLASS", {
  kind = "class",
  uses = 1,
  item = "POTION",
})
mod.exports.registeredClassItem = registered.item
registered.uses = 99
local class = mod.content.ai_classes:get("PORTABLE_NATIVE_CLASS")
mod.exports.classItem = class.item
class.item, class.uses = "FULL_RESTORE", 99
mod.exports.classDetached = mod.content.ai_classes:get("PORTABLE_NATIVE_CLASS").uses == 1
local patched = mod.content.ai_classes:patch("PORTABLE_NATIVE_CLASS", { item = "FULL_RESTORE" })
mod.exports.patchResultClassItem = patched.item
mod.exports.patchedClassItem = mod.content.ai_classes:get("PORTABLE_NATIVE_CLASS").item
mod.content.ai_classes:override("PORTABLE_NATIVE_CLASS", { kind = "class", uses = 1, item = "POTION" })
for id, value in mod.content.ai_classes:each() do
  if id == "PORTABLE_NATIVE_CLASS" then
    mod.exports.iteratedClassItem = value.item
  end
end
local brain = { calls = 0, mode = "pick", pick = 2, seen = {} }
mod.exports.brain = brain
local function choose(view)
  brain.calls = brain.calls + 1
  brain.lastView = view
  local moves = {}
  for _, row in ipairs(view.moves or {}) do
    local move = {}
    for key, value in pairs(row.move or {}) do
      move[key] = value
    end
    moves[#moves + 1] = { slot = row.slot, usable = row.usable, move = move }
  end
  brain.seen[#brain.seen + 1] = {
    moves = moves,
    hookCalls = out.calls,
    target = view.target and view.target.mon and view.target.mon.nickname,
  }
  if brain.mode == "error" then
    error("intentional native brain failure")
  end
  if brain.mode == "first-usable" then
    for _, row in ipairs(view.moves or {}) do
      if row.usable then
        return row.slot
      end
    end
    return nil
  end
  return brain.pick
end
mod.content.ai_classes:register("PORTABLE_NATIVE_BRAIN", { kind = "brain", brain = choose })
mod.content.ai_classes:register("PORTABLE_LAYER_WITH_BRAIN", { kind = "layer", brain = choose })
