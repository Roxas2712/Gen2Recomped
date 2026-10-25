-- Run from the repository: python3 tools/launcher_library_preview/run.py
-- Uses a separate identity. Fixtures never touch real game saves or options.
local ui, frames, captured = nil, 0, false
local output = os.getenv('LIBRARY_PREVIEW_OUT')
local frameFolder = os.getenv('LIBRARY_PREVIEW_FRAMES')
local frameIndex, framePending = 1, false
local frameCount = tonumber(os.getenv('LIBRARY_PREVIEW_FRAME_COUNT')) or 91
local smoke = os.getenv('LIBRARY_PREVIEW_SMOKE') == '1'
local fixture = smoke or os.getenv('LIBRARY_PREVIEW_FIXTURE') == '1'
local smokeStep, bootCount = 0, 0
local mode = os.getenv('LIBRARY_PREVIEW_MODE') or 'library'
local version = os.getenv('LIBRARY_PREVIEW_VERSION') or 'crystal'
local previewBooted = false

function love.load()
  local root = assert(os.getenv('LIBRARY_PREVIEW_ROOT'), 'Use run.py to open the preview')
  package.path = root .. '/?.lua;' .. package.path
  require('src.core.SaveData').otherLocations = function() return {} end
  if not require('src.core.GameVersion').VERSIONS[version] then version='crystal' end
  local RI = require('src.import.RomImporter')
  ui = RI.new(function(v) bootCount=bootCount+1;previewBooted=true;print('PLAY ' .. tostring(v)) end, {launcher = true})
  ui._launcherSequence = nil
  if os.getenv('LIBRARY_PREVIEW_SEASON') then ui:_settings().launcherIntroSeason=os.getenv('LIBRARY_PREVIEW_SEASON') end
  if os.getenv('LIBRARY_PREVIEW_LOGO_CARDS')=='1' then ui:_settings().launcherLogoCards=true end
  ui._newsPending = false
  ui._news = {items = {}, offline = true}
  -- No live game, network, import, or updater work is run by this preview.
  ui._sbDrawBackdrop = function() end
  ui._sbBackdropWant = function() return nil end
  ui._sbLastSaved = function() return fixture and 'crystal' or nil end
  if fixture then
    ui.ready.crystal, ui.ready.gold, ui.ready.emerald = true, true, true
    if os.getenv('LIBRARY_PREVIEW_ALL_READY')=='1' then
      for id,info in pairs(require('src.core.GameVersion').VERSIONS) do
        if info.importable~=false then ui.ready[id]=true end
      end
    end
    require('src.import.LauncherSidebar').activeSlotRow = function()
      return {name = 'KRIS', meta = {badges = 8, timeText = '24:16', dexCount = 96}}
    end
  end
  if mode=='intro' or mode=='insertion' then
    ui._launcherSequence=require('src.import.LauncherSequence').new(mode=='intro' and 'intro' or 'play',version,ui:_settings().launcherIntroSeason)
    if output then ui._launcherSequence.elapsed=tonumber(os.getenv('LIBRARY_PREVIEW_TIME')) or (mode=='intro' and 2.25 or 1.5) end
  end
  if mode == 'list' then
    ui.section, ui.gamesView, ui.browseConsole, ui.browseSeries = 'games', 'list', 'gbc', 'pokemon'
  elseif mode == 'settings' then ui:_sbGo('settings')
  elseif mode == 'tools' then ui:_sbGo('tools')
  elseif mode == 'designer' then ui:_openCartDesigner(version)
  elseif mode == 'appearance' then ui:_sbGo('settings');ui:_workspaceOpenCategory('launcher')
  elseif mode == 'mods' then ui:_sbGo('mods')
  elseif mode == 'game' then ui:_sbOpenGame(version)
  elseif mode == 'news' then ui:_sbGo('news') end
end

function love.update(dt)
  frames = frames + 1
  if not output and not frameFolder and not smoke then ui:update(dt)
  else ui.pulse = (ui.pulse or 0) + dt end
  if previewBooted and not smoke then
    previewBooted=false
    ui._handedOff=false -- A preview returns to the library so Play can be tried again.
  end
end

function love.draw()
  if frameFolder and ui._launcherSequence then
    ui._launcherSequence.elapsed = (frameIndex - 1) / (frameCount-1) * ui._launcherSequence.duration
  end
  ui:draw()
  if smoke and frames>3 then
    smokeStep=smokeStep+1
    require('tools.launcher_library_preview.smoke')(ui,smokeStep,function() return bootCount end)
  end
  if frameFolder and frames > 3 and not framePending then
    framePending = true
    love.graphics.captureScreenshot(function(data)
      local file = assert(io.open(frameFolder .. ('/frame%03d.png'):format(frameIndex), 'wb'))
      file:write(data:encode('png'):getString());file:close()
      frameIndex, framePending = frameIndex + 1, false
      if frameIndex > frameCount then love.event.quit(0) end
    end)
  end
  if frames > 3 and output and not captured then
    captured = true
    love.graphics.captureScreenshot(function(data)
      local file = assert(io.open(output, 'wb'))
      file:write(data:encode('png'):getString()); file:close()
      print('CAPTURED ' .. output)
      love.event.quit(0)
    end)
  end
end

function love.mousepressed(x,y,b) ui:mousepressed(x,y,b) end
function love.mousereleased(x,y,b) if ui.mousereleased then ui:mousereleased(x,y,b) end end
function love.wheelmoved(x,y) ui:wheelmoved(x,y) end
function love.keypressed(key)
  if key=='f5' and not smoke then
    for _,field in ipairs({'_introSound','_latchSound','_powerSound'}) do
      if ui[field] then ui[field]:stop();ui[field]=nil end
    end
    ui._handedOff=false
    ui._launcherSequence=require('src.import.LauncherSequence').new('intro',version,ui:_settings().launcherIntroSeason)
    return
  end
  ui:keypressed(key)
end
function love.textinput(value) ui:textinput(value) end
function love.filedropped(file) ui:filedropped(file) end

function love.errorhandler(message)
  io.stderr:write(tostring(message)..'\n'..debug.traceback()..'\n')
  return function() return 1 end
end

function love.gamepadpressed(joystick,button) ui:gamepadpressed(joystick,button) end
function love.gamepadreleased(joystick,button) ui:gamepadreleased(joystick,button) end
function love.gamepadaxis(joystick,axis,value) ui:gamepadaxis(joystick,axis,value) end
function love.touchpressed(id,x,y) ui:touchpressed(id,x,y) end
function love.touchmoved(id,x,y) ui:touchmoved(id,x,y) end
function love.touchreleased(id,x,y) ui:touchreleased(id,x,y) end
