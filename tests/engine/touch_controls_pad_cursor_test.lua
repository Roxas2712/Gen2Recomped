-- Adapted from Gen1Recomp535a5ec0, Copyright(C)2026 BOIS CLUB GAMES, LLC.
-- GPLv3 + Section7; licenses/GEN1RECOMP-TOUCH-SKINS.md.
-- Touch-controls editor pad / Joy-Con cursor (same class as save-editor soft-lock).
-- Opening Touch Controls parked the launcher cursor and dropped all gamepad
-- input; touch still worked.  PadCursor + main.lua forwarding restore the
-- virtual pointer.
--   luajit tests/engine/touch_controls_pad_cursor_test.lua

package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local T = require("tests.harness")
local check, eq = T.check, T.eq

local PadCursor = require("src.ui.PadCursor")
local GamepadMap = require("src.core.GamepadMap")

PadCursor.reset()
PadCursor.gamepadaxis(nil, "leftx", 1)
PadCursor.update(0.05)
check(PadCursor.isActive(), "left stick activates pad cursor")
local x0 = select(1, PadCursor.pointer())
PadCursor.update(0.05)
check(select(1, PadCursor.pointer()) > x0, "left stick moves cursor right")

eq(PadCursor.gamepadpressed(nil, "a"), "a", "gamepad a → click")
eq(PadCursor.gamepadpressed(nil, "b"), "b", "gamepad b → close")
eq(PadCursor.gamepadpressed(nil, "leftshoulder"), "tab_prev", "L → size down")
eq(PadCursor.gamepadpressed(nil, "rightshoulder"), "tab_next", "R → size up")

GamepadMap._setForceNXForTests(true)
eq(PadCursor.gamepadpressed(nil, "a"), "b", "NX SDL a (south) → close (GB b)")
eq(PadCursor.gamepadpressed(nil, "b"), "a", "NX SDL b (east) → click (GB a)")
GamepadMap._setForceNXForTests(false)

PadCursor.yieldToPointer()
check(not PadCursor.isActive(), "yieldToPointer drops the virtual cursor")

-- Native default editor keeps its actual pad implementation; it need not
-- replace the separately working save-editor cursor to expose these controls.
local Touch=require('src.core.TouchControls')
local Editor=require('src.ui.TouchControlsEditor')
local Save=require('src.core.SaveData')
local image=love.graphics.newImage
love.graphics.newImage=function(...)
  local result=image(...)
  function result:setFilter(min,mag)self.filter={min,mag}end
  return result
end
love.system=love.system or {};love.system.getOS=function()return 'Linux'end
Editor.load();Editor.draw()
local z=Touch:layout().hotbar
PadCursor.reset()
-- D-pad motion positions the real virtual cursor; a touch must yield it.
Editor.gamepadaxis(nil,'leftx',1);Editor.update(.05)
check(PadCursor.isActive(),'native editor forwards actual gamepad axis')
Editor.touchpressed('finger',z.cx,z.cy)
check(not PadCursor.isActive(),'real editor touch yields virtual cursor')
eq(Editor.drag and Editor.drag.name,'hotbar','native editor captures toggle drag')
Editor.touchreleased('finger')
Editor.gamepadpressed(nil,'rightshoulder')
local scale=Touch:currentBucket().scale
check(scale>1,'native shoulder action changes actual layout scale')
Editor.gamepadpressed(nil,'leftshoulder')
eq(Touch:currentBucket().scale,1,'reverse shoulder restores original scale')
Editor.gamepadaxis(nil,'leftx',1);Editor.update(.05)
Editor.focus(false)
check(not PadCursor.isActive(),'focus loss releases actual virtual cursor')
eq(Editor.drag,nil,'focus loss cancels native editor drag')
Editor.unload()
T.finish('native default touch editor and shared pad cursor')
