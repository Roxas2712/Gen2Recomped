-- Per-frame wall-time statistics inside an owned benchmark host.
return function(game, seconds, action, observe)
  assert(type(seconds)=='number' and seconds>=60,'at least 60 real seconds required')
  local U=require('tests.drivers.util')
  local FP=require('src.core.FrameProfile')
  local clock=love.timer.getTime
  local section,add,bake,present=FP.section,FP.add,FP.bake,love.graphics.present
  local wasEnabled=FP.enabled()
  local meter={frames=0,sections={},bakes={},tierTrace={},intervalSum=0,intervalMax=0,presentSum=0,presentMax=0}
  local perFrame,frameBakes={},{}
  local intervalEnds,intervalValues={},{}
  local function record(name,elapsed)
    if meter.started and not meter.done then
      perFrame[name]=(perFrame[name] or 0)+elapsed
    end
  end
  FP.setEnabled(true);FP.reset()
  FP.section=function(name,...)
    local close=section(name,...)
    local started=clock()
    return function(...)
      local elapsed=clock()-started
      close(...)
      record(name,elapsed)
    end
  end
  FP.add=function(name,elapsed)
    add(name,elapsed)
    record(name,elapsed or 0)
  end
  if bake then
    FP.bake=function(name)
      bake(name)
      if meter.started and not meter.done then
        local row=meter.bakes[name] or {total=0,peakPerFrame=0}
        row.total=row.total+1
        frameBakes[name]=(frameBakes[name] or 0)+1
        row.peakPerFrame=math.max(row.peakPerFrame,frameBakes[name])
        meter.bakes[name]=row
      end
    end
  end
  local function pack(...) return {n=select('#',...),...} end
  love.graphics.present=function(...)
    local before=clock()
    local result=pack(present(...))
    local now=clock()
    if not meter.done then
      if observe then
        local tier,focused=observe()
        local last=meter.tierTrace[#meter.tierTrace]
        if not last or last.tier~=tier or last.focused~=focused then
          meter.tierTrace[#meter.tierTrace+1]={seconds=meter.started and now-meter.started or 0,tier=tier,focused=focused}
        end
      end
      if not meter.started then
        meter.started,meter.previous,meter.cpuStarted=now,now,os.clock()
      else
        local interval,presentTime=now-meter.previous,now-before
        meter.frames=meter.frames+1
        meter.intervalSum=meter.intervalSum+interval
        meter.intervalMax=math.max(meter.intervalMax,interval)
        if action then
          intervalEnds[#intervalEnds+1]=now
          intervalValues[#intervalValues+1]=interval*1000
        end
        meter.presentSum=meter.presentSum+presentTime
        meter.presentMax=math.max(meter.presentMax,presentTime)
        for name,value in pairs(perFrame) do
          local row=meter.sections[name] or {sum=0,max=0,frames=0}
          row.sum,row.max,row.frames=row.sum+value,math.max(row.max,value),row.frames+1
          meter.sections[name]=row
        end
        meter.previous=now
        if now-meter.started>=seconds then
          meter.done,meter.elapsed,meter.cpuSeconds=true,now-meter.started,os.clock()-meter.cpuStarted
        end
      end
      perFrame,frameBakes={},{}
    end
    return unpack(result,1,result.n)
  end
  local motion=action and coroutine.create(action)
  local actionResult
  while not meter.done do
    if meter.started and motion and coroutine.status(motion)~='dead' then
      local ok,value=coroutine.resume(motion)
      assert(ok,value)
      if coroutine.status(motion)=='dead' then actionResult=value end
    end
    U.wait(1)
  end
  FP.section,FP.add,love.graphics.present=section,add,present
  FP.bake=bake
  FP.setEnabled(wasEnabled)
  assert(not motion or coroutine.status(motion)=='dead','native walk exceeded the measurement interval')
  assert(meter.frames>0 and meter.elapsed>=60,'incomplete real-time interval')
  local sections={}
  for _, crossing in ipairs(actionResult or {}) do
    local frames,maxMs=0,0
    for i=1,#intervalValues do
      if intervalEnds[i]>crossing.crossingStart and intervalEnds[i]<=crossing.crossingEnd then
        frames=frames+1;maxMs=math.max(maxMs,intervalValues[i])
      end
    end
    assert(frames>0,'no presented frames cover the native crossing')
    crossing.maxFrameMs,crossing.windowFrames=maxMs,frames
    crossing.fromSeconds=crossing.crossingStart-meter.started
    crossing.toSeconds=crossing.crossingEnd-meter.started
    crossing.crossingStart,crossing.crossingEnd=nil,nil
  end
  for name,row in pairs(meter.sections) do
    sections[name]={avgMsPerFrame=row.sum/meter.frames*1000,maxMsPerFrame=row.max*1000,observedFrames=row.frames}
  end
  return {
    seconds=meter.elapsed,frames=meter.frames,
    frame={avgMs=meter.intervalSum/meter.frames*1000,maxMs=meter.intervalMax*1000},
    present={avgMs=meter.presentSum/meter.frames*1000,maxMs=meter.presentMax*1000},
    processCpuSeconds=meter.cpuSeconds,processCpuPercent=meter.cpuSeconds/meter.elapsed*100,
    sections=sections,bakes=meter.bakes,tierTrace=meter.tierTrace,walks=actionResult,
    timing='present-completion intervals and FrameProfile wall-time sections; GPU submission only, no completion fence',
    limitations={'inclusive sections cannot be summed','instrumented driver host; no screenshot readback during measurement','process CPU time includes active worker threads; no GPU utilization or energy measurement'},
  }
end
