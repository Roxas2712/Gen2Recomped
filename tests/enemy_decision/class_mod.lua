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
