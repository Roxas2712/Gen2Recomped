-- Headless check for the EXCLUSIVE video mode and the VSYNC option.
--   luajit tools/video_vsync_check.lua   (plain lua works too)
-- Drives src/core/VideoMode and src/core/VSync against a stub love.window
-- and asserts the cycles, the launcher's FULLSCREEN alias, the exclusive
-- setMode call, the borderless fallback when the driver refuses, and the
-- windowed size coming back after an exclusive mode.

package.path = "./?.lua;./?/init.lua;" .. package.path

local calls = {}
local win = { w = 960, h = 864, full = false, ftype = nil, vsync = 1, refuse = false }
love = {
  system = { getOS = function() return "Linux" end },
  window = {
    getMode = function() return win.w, win.h, { fullscreen = win.full, fullscreentype = win.ftype } end,
    getFullscreen = function() return win.full, win.ftype end,
    getDesktopDimensions = function() return 2560, 1440 end,
    setMode = function(w, h, flags)
      calls[#calls + 1] = { "setMode", w, h, flags.fullscreen, flags.fullscreentype }
      if flags.fullscreen and win.refuse then error("no exclusive mode here") end
      win.w, win.h, win.full, win.ftype = w, h, flags.fullscreen or false, flags.fullscreentype
      return true
    end,
    setFullscreen = function(on, ftype)
      calls[#calls + 1] = { "setFullscreen", on, ftype }
      win.full, win.ftype = on, on and (ftype or "desktop") or nil
      return true
    end,
    setVSync = function(v) calls[#calls + 1] = { "setVSync", v }; win.vsync = v end,
    getVSync = function() return win.vsync end,
  },
}

local VideoMode = require("src.core.VideoMode")
local VSync = require("src.core.VSync")
local n = 0
local function eq(a, b, what)
  n = n + 1
  if a ~= b then error(("%s: got %s, want %s"):format(what, tostring(a), tostring(b)), 2) end
end
local function last() return calls[#calls] end

-- cycles and normalisation
eq(VideoMode.cycle("windowed"), "borderless", "windowed -> borderless")
eq(VideoMode.cycle("borderless"), "exclusive", "borderless -> exclusive")
eq(VideoMode.cycle("exclusive"), "windowed", "exclusive wraps to windowed")
eq(VideoMode.cycle("windowed", -1), "exclusive", "reverse wraps to exclusive")
eq(VideoMode.normalize("fullscreen"), "exclusive", "launcher FULLSCREEN is exclusive")
eq(VideoMode.normalize("garbage"), "windowed", "garbage degrades to windowed")
eq(VideoMode.modeLabel("exclusive"), "EXCLUSIVE", "label")
eq(VSync.cycle("on"), "adaptive", "on -> adaptive")
eq(VSync.cycle("adaptive"), "off", "adaptive -> off")
eq(VSync.cycle("off"), "on", "off wraps to on")
eq(VSync.value("adaptive"), -1, "adaptive is -1")
eq(VSync.value("off"), 0, "off is 0")
eq(VSync.value(nil), 1, "missing option is on")

-- exclusive takes the desktop size through setMode
VideoMode.apply("exclusive")
eq(last()[1], "setMode", "exclusive goes through setMode")
eq(last()[2], 2560, "exclusive width is the desktop's")
eq(last()[5], "exclusive", "fullscreentype exclusive")
eq(win.full, true, "window is fullscreen")

-- back to windowed restores the remembered size, not the desktop's
VideoMode.apply("windowed")
eq(last()[1], "setMode", "windowed after exclusive restores through setMode")
eq(win.w, 960, "windowed width restored")
eq(win.h, 864, "windowed height restored")
eq(win.full, false, "window is windowed again")

-- a driver that refuses exclusive falls back to borderless
win.refuse = true
VideoMode.apply("exclusive")
eq(last()[1], "setFullscreen", "refused exclusive falls back to setFullscreen")
eq(last()[3], "desktop", "fallback is the desktop (borderless) mode")
win.refuse = false
VideoMode.apply("borderless")
eq(last()[3], "desktop", "borderless is the desktop mode")
VideoMode.apply("windowed")
eq(win.full, false, "windowed from borderless")

-- vsync is pushed and read back
eq(VSync.apply("adaptive"), -1, "adaptive applied and read back")
eq(VSync.applyOptions({ vsync = "off" }), 0, "off applied via options")
eq(VSync.applyOptions({}), 1, "no option means on")

-- mobile is a no-op
love.system.getOS = function() return "Android" end
calls = {}
VideoMode.apply("exclusive")
VSync.apply("off")
eq(#calls, 0, "mobile makes no window calls")

print(("video_vsync_check: %d checks ok"):format(n))
