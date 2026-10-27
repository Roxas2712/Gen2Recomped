function love.conf(t)
 t.identity=os.getenv('ASCENDANT_QA_IDENTITY') or 'recompiled-ascendant-intro'
 t.version=love.getVersion()>=12 and '12.0' or '11.5'
 t.window.title='Recompiled Ascendant · by Roxas2712'
 t.window.width=1024;t.window.height=576;t.window.resizable=true;t.window.vsync=1
 t.modules.physics=false
end
