-- VSYNC: ON, ADAPTIVE or OFF, as an option.
--
-- Persisted as save.options.vsync.  The port always ran with vsync on
-- (conf.lua), and the frame pacer (src/core/FrameCap.lua) reads the live
-- setting each frame, so this row only has to push the value into the
-- window.  ADAPTIVE (-1) is vsync that stops waiting when a frame comes in
-- late -- it tears for that frame instead of halving the rate, which on a
-- desktop that mostly keeps up is the smoother answer.  OFF lets the pacer
-- alone decide the cadence (MAX FPS), which is the right choice on a panel
-- whose refresh and the cap disagree.  Drivers that cannot do ADAPTIVE
-- report so through love.window.getVSync; nothing here insists.
--
-- No-ops on mobile and in headless stubs that lack love.window.setVSync.

local VSync = {}

VSync.MODES = { "on", "adaptive", "off" }
VSync.DEFAULT = "on"

local LABELS = { on = "ON", adaptive = "ADAPTIVE", off = "OFF" }
local VALUES = { on = 1, adaptive = -1, off = 0 }

function VSync.normalize(mode)
  if mode == "adaptive" or mode == "off" then return mode end
  return VSync.DEFAULT
end

function VSync.modeLabel(mode)
  return LABELS[VSync.normalize(mode)]
end

function VSync.value(mode)
  return VALUES[VSync.normalize(mode)]
end

function VSync.cycle(mode, dir)
  mode = VSync.normalize(mode)
  local i = 1
  for idx, m in ipairs(VSync.MODES) do if m == mode then i = idx break end end
  local n = #VSync.MODES
  return VSync.MODES[(i - 1 + ((tonumber(dir) or 1) < 0 and -1 or 1)) % n + 1]
end

function VSync.isMobile()
  if not love or not love.system or not love.system.getOS then return false end
  local osName = love.system.getOS()
  return osName == "Android" or osName == "iOS"
end

-- what the window reports after the push, or nil without a window
function VSync.apply(mode)
  if VSync.isMobile() then return nil end
  if not (love and love.window and love.window.setVSync) then return nil end
  local want = VSync.value(mode)
  pcall(love.window.setVSync, want)
  if love.window.getVSync then
    local ok, got = pcall(love.window.getVSync)
    if ok then return got end
  end
  return want
end

function VSync.applyOptions(opts)
  return VSync.apply(opts and opts.vsync)
end

return VSync
