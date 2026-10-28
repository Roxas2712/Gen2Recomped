-- Adapted from Gen1Recomp535a5ec0, Copyright(C)2026 BOIS CLUB GAMES, LLC.
-- GPLv3 + Section7; licenses/GEN1RECOMP-TOUCH-SKINS.md.
-- Skin Studio art import: the native image picker behind the "Import" buttons
-- (bezel / idle / pressed), and the alt-tab crash that took the studio down --
-- love.focus fell through to Game:focus with no game booted.
--   luajit tests/engine/skin_studio_image_import.lua

package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local T = require("tests.harness")
local check, eq = T.check, T.eq

local FilePicker = require("src.core.FilePicker")
local TouchSkin = require("src.core.TouchSkin")
local Studio = require("src.ui.SkinStudio")

local function session()
  Studio.skin = TouchSkin.newSkin("t")
  Studio.skinIdField = "t"
  Studio.pageIndex = 1
  Studio.selected = nil
  Studio.canvasIndex = 1
  Studio.drag = nil
  Studio.dirty = false
  Studio.status = nil
  Studio.testing = false
  Studio.images = {}
  Studio.imageTarget = "idle"
  return Studio.skin
end

-- ------------------------------------------------------------ file picker

check(FilePicker.matches("bezel.png", FilePicker.IMAGE), "png is art")
check(FilePicker.matches("BEZEL.PNG", FilePicker.IMAGE), "case does not matter")
check(FilePicker.matches("shot.jpg", FilePicker.IMAGE), "jpg is art")
check(FilePicker.matches("shot.jpeg", FilePicker.IMAGE), "jpeg is art")
check(not FilePicker.matches("skin.zip", FilePicker.IMAGE), "a zip is not art")
eq(FilePicker.basename("/home/me/art/bezel.png"), "bezel.png", "posix basename")
eq(FilePicker.basename("C:\\Users\\me\\bezel.png"), "bezel.png", "windows basename")
eq(FilePicker.basename("bezel.png"), "bezel.png", "a bare name is its own basename")

-- ----------------------------------------------------------- import target

session()
Studio.addControl()
local ctl = Studio.selectedControl()
check(Studio.adoptImage("bezel.png", "PNGDATA", "bezel"), "bezel import succeeds")
eq(Studio.page().imagePath, "img/bezel.png", "bezel art lands on the page")
eq(ctl.imagePath, nil, "and not on the selected control")
check(Studio.dirty, "importing marks the skin dirty")
check(Studio.status:find("bezel", 1, true) ~= nil, "the status names the target")

check(Studio.adoptImage("a_button.png", "PNGDATA", "idle"), "idle import succeeds")
eq(ctl.imagePath, "img/a_button.png", "idle art lands on the control")
eq(Studio.page().imagePath, "img/bezel.png", "and leaves the bezel alone")

check(Studio.adoptImage("a_down.png", "PNGDATA", "pressed"), "pressed import succeeds")
eq(ctl.pressedImagePath, "img/a_down.png", "pressed art lands on the control")
eq(ctl.imagePath, "img/a_button.png", "idle art survives")

check(not Studio.adoptImage("notes.txt", "junk", "bezel"), "non-art is refused")
eq(Studio.page().imagePath, "img/bezel.png", "and changes nothing")

-- the imported files are listed for the cycle buttons
local listed = {}
for _, rel in ipairs(Studio.images or {}) do listed[rel] = true end
check(listed["img/bezel.png"], "the imported bezel joins the image list")

-- -------------------------------------------------------- picker plumbing

local realOpen, realRead, realAvailable = FilePicker.open, FilePicker.read, FilePicker.available
FilePicker.available=function()return true end
local asked
FilePicker.open = function(prompt, kind)
  asked = { prompt = prompt, kind = kind }
  return "/tmp/some folder/frame.png"
end
FilePicker.read = function() return "PNGDATA" end

session()
Studio.importImageFile("bezel")
check(asked ~= nil, "the bezel button opens a picker")
eq(asked.kind, FilePicker.IMAGE, "and asks for images, not archives")
check(asked.prompt:lower():find("bezel", 1, true) ~= nil, "with a bezel prompt")
eq(Studio.page().imagePath, "img/frame.png", "the pick becomes the bezel")
eq(Studio.imageTarget, "bezel", "and the target sticks for the cycle button")

-- no control selected: an art import says so instead of writing to the page
session()
asked = nil
Studio.importImageFile("idle")
check(asked == nil, "no picker opens without a control to paint")
eq(Studio.page().imagePath, nil, "and the bezel is not overwritten")
check(Studio.status ~= nil, "the studio explains why")

-- a cancelled dialog leaves the skin exactly as it was
session()
FilePicker.open = function() return nil end
Studio.importImageFile("bezel")
eq(Studio.page().imagePath, nil, "cancelling imports nothing")
check(not Studio.dirty, "and does not dirty the skin")

FilePicker.open, FilePicker.read = realOpen, realRead
FilePicker.available=realAvailable

-- --------------------------------------------------------- focus / alt-tab

session()
Studio.drag = { kind = "control-move", mx = 1, my = 1, bx = 0, by = 0, bw = 1, bh = 1 }
Studio.clicked = true
Studio.focus(false)
eq(Studio.drag, nil, "losing focus drops the in-flight drag")
eq(Studio.clicked, false, "and the queued click")
check(pcall(Studio.visible, false), "minimizing is survivable too")

-- Actual native main.lua event ownership is exercised by
-- skin_studio_native_host.lua; a text scan of a different host's variable
-- names would not prove that this engine dispatches those events.

T.finish("skin_studio_image_import")
