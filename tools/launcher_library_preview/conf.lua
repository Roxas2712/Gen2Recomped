function love.conf(t)
  love.filesystem.setSymlinksEnabled(true)
  t.identity = 'Gen2Recomp-layout-preview'
  t.window.title = 'Gen2Recomp / Library preview'
  t.window.width = tonumber(os.getenv('LIBRARY_PREVIEW_WIDTH')) or 1440
  t.window.height = tonumber(os.getenv('LIBRARY_PREVIEW_HEIGHT')) or 960
  t.window.resizable = true
  t.window.highdpi = false
  t.modules.audio = os.getenv('LIBRARY_PREVIEW_AUDIO') == '1'
  t.modules.physics = false
end
