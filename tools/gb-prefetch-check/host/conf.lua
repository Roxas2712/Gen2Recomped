function love.conf(t)
  assert(os.getenv('GEN1_PERF_GUARDED')=='1','Use check_gen1_performance.py')
  t.identity=assert(os.getenv('POKEPORT_IDENTITY'))
  t.window.title='GB prefetch pixel qualification'
  t.window.width,t.window.height,t.window.visible,t.window.vsync=64,64,false,0
  t.modules.audio,t.modules.joystick,t.modules.physics=false,false,false
end
