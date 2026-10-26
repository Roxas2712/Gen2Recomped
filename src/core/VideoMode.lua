-- Windowed, borderless (desktop) fullscreen, or exclusive fullscreen.
--
-- Persisted as save.options.videoMode.  Applied from OptionsMenu and on
-- boot via Game:applyOptions.  No-ops on mobile and in headless stubs
-- that lack love.window.
--
-- EXCLUSIVE is the one of the three the compositor stays out of: on Windows
-- a borderless window is composited by the desktop (one more copy and the
-- compositor's own cadence between the game and the panel), an exclusive
-- one flips straight to the display -- a frame of latency less and a vsync
-- that is the panel's own.  It is taken at the desktop's native size, so no
-- display mode change is forced; the renderer scales as it does for any
-- window.  A machine that refuses the mode falls back to borderless.

local VideoMode = {}

VideoMode.MODES = { "windowed", "borderless", "exclusive" }
VideoMode.DEFAULT = "windowed"

local LABELS = {
  windowed = "WINDOWED",
  borderless = "BORDERLESS",
  exclusive = "EXCLUSIVE",
}

function VideoMode.normalize(mode)
  if mode == "borderless" or mode == "exclusive" then return mode end
  -- the launcher's settings panel has offered FULLSCREEN all along
  if mode == "fullscreen" then return "exclusive" end
  return VideoMode.DEFAULT
end

function VideoMode.modeLabel(mode)
  return LABELS[VideoMode.normalize(mode)] or LABELS[VideoMode.DEFAULT]
end

function VideoMode.isMobile()
  if not love or not love.system or not love.system.getOS then return false end
  local osName = love.system.getOS()
  return osName == "Android" or osName == "iOS"
end

-- Cycle windowed -> borderless -> exclusive -> windowed (dir -1 reverses).
function VideoMode.cycle(mode, dir)
  mode = VideoMode.normalize(mode)
  local i = 1
  for idx, m in ipairs(VideoMode.MODES) do if m == mode then i = idx break end end
  local n = #VideoMode.MODES
  return VideoMode.MODES[(i - 1 + ((tonumber(dir) or 1) < 0 and -1 or 1)) % n + 1]
end

-- the windowed size to come back to after an exclusive mode
local windowedSize = nil

local function rememberWindowed()
  if not (love.window.getFullscreen and love.window.getMode) then return end
  local full = love.window.getFullscreen()
  if full then return end
  local w, h = love.window.getMode()
  if w and h and w > 0 and h > 0 then windowedSize = { w, h } end
end

-- Push the mode into the live window.  Safe when love.window is missing.
function VideoMode.apply(mode)
  if VideoMode.isMobile() then return end
  if not love or not love.window or not love.window.setFullscreen then return end
  mode = VideoMode.normalize(mode)
  if mode == "exclusive" then
    rememberWindowed()
    local ok = false
    if love.window.getDesktopDimensions and love.window.getMode and love.window.setMode then
      ok = pcall(function()
        local dw, dh = love.window.getDesktopDimensions()
        local _, _, flags = love.window.getMode()
        flags = flags or {}
        flags.fullscreen = true
        flags.fullscreentype = "exclusive"
        return love.window.setMode(dw, dh, flags)
      end)
    end
    if not ok then
      -- the compositor's fullscreen is the next best thing, and always works
      love.window.setFullscreen(true, "desktop")
    end
  elseif mode == "borderless" then
    rememberWindowed()
    -- "desktop" = borderless fullscreen matching the display
    love.window.setFullscreen(true, "desktop")
  else
    local wasExclusive = love.window.getFullscreen
      and select(2, love.window.getFullscreen()) == "exclusive"
    if wasExclusive and windowedSize and love.window.setMode and love.window.getMode then
      -- an exclusive mode's size is the desktop's, not the window the
      -- player had: give that one back
      local okBack = pcall(function()
        local _, _, flags = love.window.getMode()
        flags = flags or {}
        flags.fullscreen = false
        flags.fullscreentype = nil
        return love.window.setMode(windowedSize[1], windowedSize[2], flags)
      end)
      if okBack then return end
    end
    love.window.setFullscreen(false)
  end
end

function VideoMode.applyOptions(opts)
  VideoMode.apply(opts and opts.videoMode)
end

return VideoMode
