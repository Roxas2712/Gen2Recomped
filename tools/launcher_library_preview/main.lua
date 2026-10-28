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
local xyImportStarted = false
local xyFile = os.getenv('LIBRARY_PREVIEW_XY_FILE')

function love.load()
  if love.setDeprecationOutput then love.setDeprecationOutput(false) end
  local root = assert(os.getenv('LIBRARY_PREVIEW_ROOT'), 'Use run.py to open the preview')
  package.path = root .. '/?.lua;' .. package.path
  require('src.core.SaveData').otherLocations = function() return {} end
  if not require('src.core.GameVersion').VERSIONS[version] and not require('src.import.LauncherPokemonXY').info(version) then version='crystal' end
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
    ui._launcherSequence.waitForWindow=not output and not frameFolder and not smoke
    if output then ui._launcherSequence.elapsed=tonumber(os.getenv('LIBRARY_PREVIEW_TIME')) or (mode=='intro' and 2.25 or 1.5) end
  end
  if mode == 'list' then
    ui.section, ui.gamesView, ui.browseConsole, ui.browseSeries = 'games', 'list', 'gbc', 'pokemon'
  elseif mode == 'settings' then ui:_sbGo('settings')
  elseif mode == 'tools' then ui:_sbGo('tools')
  elseif mode == 'designer' then ui:_openCartDesigner(version)
  elseif mode == 'original' then ui:_openCartDesigner(version);ui._cartDraft.originalOnly=true
  elseif mode == 'appearance' then ui:_sbGo('settings');ui:_workspaceOpenCategory('launcher')
  elseif mode == 'mods' then
    ui:_sbGo('mods')
    local catalogue=os.getenv('LIBRARY_PREVIEW_CATALOGUE')
    if catalogue then
      local file=assert(io.open(catalogue,'rb'));local bytes=file:read('*a');file:close()
      ui.findIndex=assert(require('src.mods.ModIndex').parse(bytes));ui.findLoaded=true
      ui.findIndex.categories=require('src.mods.ModIndex').categoriesIn(ui.findIndex)
      ui.findQuery=os.getenv('LIBRARY_PREVIEW_QUERY') or ''
      ui._ensureFind=function() end
      local images={}
      local imageManifest=os.getenv('LIBRARY_PREVIEW_THUMBNAILS')
      if imageManifest then
        local f=assert(io.open(imageManifest,'rb'));local paths=require('src.link.Json').decode(f:read('*a'));f:close()
        for id,path in pairs(paths) do
          local f=assert(io.open(path,'rb'));local bytes=f:read(2*1024*1024+1);f:close()
          assert(require('src.import.ImageBounds').allowed(bytes,2048))
          images[id]=love.graphics.newImage(love.filesystem.newFileData(bytes,'preview.jpg'))
          images[id]:setFilter('linear','linear')
        end
      end
      ui._findThumb=function(_,entry) return images[entry.catalogueId] end
      ui.mods={};ui.modsLoaded=true;ui._ensureMods=function() end
      local first=ui.findIndex.mods[1]
      if first then ui.mods={{id=first.id,name=first.title,version=first.version,enabled=true,github=first.github}} end
      if first and os.getenv('LIBRARY_PREVIEW_UPDATE')=='1' then ui.modUpdateInfo={[first.id]={status='available',latest='2.0.0'}} end
      for _,entry in ipairs(ui.findIndex.mods) do
        if ui.findIndex.week and entry.catalogueId==ui.findIndex.week.catalogue_id then entry._communityResolved=entry.latest~=nil end
      end
      if os.getenv('LIBRARY_PREVIEW_DETAILS')=='1' then
        local rows=ui:_findRows()
        if rows[1] then ui:_findShowDetails(rows[1]);ui._findDetails.previewExpanded=true end
      end
    end
  elseif mode == '3ds' then
    ui._setupPending=nil;ui._setupOverlay=nil
    ui:_sbOpenGame(version=='y' and 'y' or 'x')
  elseif mode == 'game' then ui:_sbOpenGame(version)
  elseif mode == 'news' then ui:_sbGo('news') end
end

function love.update(dt)
  frames = frames + 1
  if mode=='3ds' or not output and not frameFolder and not smoke then ui:update(dt)
  else ui.pulse = (ui.pulse or 0) + dt end
  if mode=='3ds' and xyFile and not xyImportStarted and not ui._xyJob then
    xyImportStarted=true;ui:_xyImport(xyFile)
  end
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
  if frames > 3 and output and not captured and not (mode=='3ds' and ui._xyJob) then
    if mode=='3ds' and xyFile then
      local row=ui._xyData and ui._xyData[ui._xyEdition]
      assert(xyImportStarted and row and row.imported and not row.ready,'Real worker must import the fixture without false native readiness: '..tostring(ui._xyNotice))
      if os.getenv('LIBRARY_PREVIEW_XY_EXPECT_FAILURE')=='1' then assert(ui._xyNoticeIsError,'The native worker must explicitly report a failed compile')end
      print('3DS_WORKER_IMPORT_PASS')
    end
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
    ui._launcherSequence.waitForWindow=true
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
