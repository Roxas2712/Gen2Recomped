function love.conf(t)
  assert(os.getenv('POKEPORT_WORKER_QA_GUARDED')=='1','run through performance_qualification.py')
  t.identity=assert(os.getenv('POKEPORT_IDENTITY'))
  t.window=false
  t.modules.graphics,t.modules.audio,t.modules.joystick,t.modules.physics=false,false,false,false
end
