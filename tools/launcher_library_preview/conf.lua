function love.conf(t)
  love.filesystem.setSymlinksEnabled(true)
  t.identity = os.getenv('LIBRARY_PREVIEW_SMOKE')=='1' and 'oasc-retro-launcher-qa-smoke' or 'oasc-retro-launcher-qa-layout'
  t.window.title = 'RetroRecomped / Library preview'
  t.window.width = tonumber(os.getenv('LIBRARY_PREVIEW_WIDTH')) or 1440
  t.window.height = tonumber(os.getenv('LIBRARY_PREVIEW_HEIGHT')) or 960
  t.window.resizable = true
  t.window.highdpi = true
  if love.getVersion and love.getVersion()>=12 then t.highdpi=true;t.window.highdpi=nil end
  t.modules.audio = os.getenv('LIBRARY_PREVIEW_AUDIO') == '1'
  t.modules.physics = false
end
