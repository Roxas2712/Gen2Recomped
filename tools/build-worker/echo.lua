local Echo={}
function Echo.run(payload)
  assert(not love.graphics,'worker must not load graphics')
  if payload.fail then error('owned worker failure',0) end
  if payload.delay then love.timer.sleep(payload.delay) end
  return {value=payload.value*2,data=payload.data}
end
return Echo
