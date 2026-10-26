package.path = "./?.lua;./?/init.lua;" .. package.path
local snapshot = assert(arg[1])
local assets = arg[2] ~= "" and arg[2] or nil
local originalOpen = io.open
io.open = function(path, mode, ...)
  if type(path) == "string" and path:sub(1, 21) == "mods/quality_of_life/" then
    assert(mode == nil or mode == "r" or mode == "rb", "mod source is read-only")
    path = snapshot .. "/" .. path:sub(22)
  elseif assets and type(path) == "string" and path:sub(1, 17) == "assets/generated/" then
    assert(mode == nil or mode == "r" or mode == "rb", "imported art is read-only")
    path = assets .. "/" .. path:sub(18)
  end
  return originalOpen(path, mode, ...)
end
if arg[3] == "rectangle-glyphs" then
  require("tests.modkit")
  -- The unchanged suite asserts the mod's documented rectangle fallback.
  -- Keep that device capability identical on both engines; production
  -- modules and the mod itself remain untouched.
  if love.image then
    love.image.newImageData = nil
  end
end
if arg[4] and arg[4] ~= "" then
  dofile(arg[4])
else
  dofile(snapshot .. "/tests/quality_of_life_test.lua")
end
