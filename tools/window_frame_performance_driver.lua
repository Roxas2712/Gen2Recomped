-- Real native games, deterministic 60 Hz simulation, uncapped rendering.
-- No observers, screenshots or pixel scans run inside the measured intervals.
return function(game)
  local U=require("tests.drivers.util")
  local Json=require("src.link.Json")
  local Frame=require("src.render.WindowFrame")
  local g,timer=love.graphics,love.timer
  local threadClock
  if love.system.getOS()=="OS X" then
    local ffi=require("ffi")
    ffi.cdef[[unsigned long long clock_gettime_nsec_np(int);]]
    threadClock=function()return tonumber(ffi.C.clock_gettime_nsec_np(16))/1e9 end
  end
  local out=assert(os.getenv("PALETTE_GPU_OUT"))
  local version=assert(os.getenv("POKEPORT_VERSION"))
  assert(love.filesystem.getIdentity():match("^gen2%-palette%-gpu%-"))
  local renderer,api,vendor,device=g.getRendererInfo()
  local major,minor,revision=love.getVersion()
  local report={game=version,gpu={renderer=renderer,version=api,vendor=vendor,device=device},
    runtime={major=major,minor=minor,revision=revision},phases={},
    simulationHz=60,vsync=0,mainLoopSleepSeconds=.001,
    measuredPixelReadbackObservers=false,measuredScreenshots=false,
    readbackMetric="synchronous call or asynchronous submission; completion wait is in transfer, runtime completion copy may be in present",
    readbackTimingAvailable=g.readbackTexture~=nil,mainThreadCpuAvailable=threadClock~=nil}
  local function stats(values)
    local sorted,total={},0
    for i,v in ipairs(values) do sorted[i]=v;total=total+v end
    table.sort(sorted)
    local function percentile(p)return sorted[math.max(1,math.ceil(#sorted*p))]*1000 end
    return {samples=#values,meanMs=total/#values*1000,p50Ms=percentile(.5),
      p95Ms=percentile(.95),p99Ms=percentile(.99),maxMs=sorted[#sorted]*1000}
  end
  local phase,insideBody,pending
  local updateCost,gcCost,paletteCost=0,0,0
  local update,gc=game.update,collectgarbage
  local Tiles=require("src.render.Gen3Tiles")
  local paletteTicks=Tiles.setPaletteTicks
  local Cycles=require("src.render.Gen3PaletteCycles")
  local fullSample=Cycles.sample
  Cycles.sample=function(...)
    if phase then phase.fullPaletteSamples=phase.fullPaletteSamples+1 end
    return fullSample(...)
  end
  game.update=function(self,...)
    if not phase then return update(self,...) end
    gcCost=0
    local at=timer.getTime();update(self,...);updateCost=timer.getTime()-at
  end
  collectgarbage=function(action,...)
    if not phase or action~="step" then return gc(action,...) end
    local at=timer.getTime();local result=gc(action,...)
    gcCost=gcCost+timer.getTime()-at
    return result
  end
  Tiles.setPaletteTicks=function(self,...)
    if not phase then return paletteTicks(self,...) end
    local at=timer.getTime();local changed,reason=paletteTicks(self,...)
    paletteCost=paletteCost+timer.getTime()-at
    return changed,reason
  end
  local proofActive,drawCount=false,0
  local originalDraw=love.draw
  love.draw=function()
    originalDraw();drawCount=drawCount+1
    if not proofActive then return end
    g.push("all");g.setCanvas();g.origin();g.setShader();g.setScissor()
    g.setBlendMode("replace","premultiplied")
    for bit=0,31 do
      local one=math.floor(drawCount/2^bit)%2==1
      g.setColor(one and 1 or 0,one and 0 or 1,0,1)
      g.rectangle("fill",bit*2,0,2,3)
    end
    g.pop()
  end
  local draw,present,readback,readbackAsync=Frame.draw,g.present,g.readbackTexture,g.readbackTextureAsync
  Frame.draw=function(body,capture)
    if not phase then return draw(body,capture) end
    assert(not capture,"capture requested during performance measurement")
    local at=timer.getTime()
    pending={start=at,readback=0,readbacks=0,update=updateCost,gcStep=gcCost}
    paletteCost=0
    if phase.previousStart then
      phase.intervals[#phase.intervals+1]=at-phase.previousStart
    end
    phase.previousStart=at
    draw(function()
      insideBody=true
      local bodyStart=timer.getTime();body()
      pending.body=timer.getTime()-bodyStart;insideBody=false
    end)
    pending.frame=timer.getTime()-at
    pending.transfer=pending.frame-pending.body-pending.readback
    pending.paletteSync=paletteCost
  end
  if readback then
    g.readbackTexture=function(...)
      local at=timer.getTime();local data=readback(...)
      if phase and pending and not insideBody then
        pending.readback=pending.readback+timer.getTime()-at
        pending.readbacks=pending.readbacks+1
      end
      return data
    end
  end
  if readbackAsync then
    g.readbackTextureAsync=function(...)
      local at=timer.getTime();local request=readbackAsync(...)
      if phase and pending and not insideBody then
        pending.readback=pending.readback+timer.getTime()-at
        pending.readbacks=pending.readbacks+1
      end
      return request
    end
  end
  g.present=function(...)
    local at=timer.getTime();present(...)
    if phase and pending then
      pending.present=timer.getTime()-at
      pending.render=pending.frame+pending.present
      for _,key in ipairs({"body","frame","readback","transfer","present","render","update","gcStep","paletteSync"}) do
        local list=phase[key];list[#list+1]=pending[key]
      end
      phase.readbackCalls=phase.readbackCalls+pending.readbacks
      pending=nil
    end
  end
  local emerald=version=="emerald"
  local maps=emerald and {{"MAP_G26_N21",10,5},{"MAP_G26_N18",11,10}}
    or {{"MAP_G03_N00",11,11},{"MAP_G04_N01",6,6}}
  local Overworld=require("src.world.OverworldController")
  local computeNeighbors=Overworld.computeNeighbors
  do
    -- Benchmark-only construction order. pairs(connections) otherwise assigns
    -- seeded constructor RNG draws to different neighbouring NPCs. Keep the
    -- returned maps/placements intact and sort before NPC construction.
    Overworld.computeNeighbors=function(...)
      local list=computeNeighbors(...)
      table.sort(list,function(a,b)
        if a.id~=b.id then return a.id<b.id end
        if a.ox~=b.ox then return a.ox<b.ox end
        return a.oy<b.oy
      end)
      return list
    end
  end
  report.npcConstruction="seeded-sorted-neighbors-fresh-pool"
  local probes={}
  local function npcWorkload(world)
    local function row(npc,ox,oy)
      local values={tostring(npc.id),tostring(npc.def and npc.def.sprite),tostring(ox),tostring(oy)}
      for _,key in ipairs({"cellX","cellY","targetX","targetY","facing","moving","timer"}) do
        values[#values+1]=tostring(npc[key])
      end
      return table.concat(values,"|")
    end
    local home,ghosts={},{}
    for _,npc in ipairs(world.npcs) do home[#home+1]=row(npc,0,0) end
    for _,ghost in ipairs(world.ghosts) do ghosts[#ghosts+1]=row(ghost.npc,ghost.ox,ghost.oy) end
    -- Dynamic entry scripts can append equivalent actors in a different list
    -- order. Compare identities, sprites, placements and state canonically;
    -- do not change native update/draw methods or their actor lists.
    table.sort(home);table.sort(ghosts)
    return "home:"..#home.."\n"..table.concat(home,"\n").."\nghosts:"..#ghosts.."\n"..table.concat(ghosts,"\n")
  end
  for _,size in ipairs({{640,480},{960,720}}) do
    local _,_,flags=love.window.getMode()
    flags.vsync=0;flags.highdpi=true
    assert(love.window.setMode(size[1],size[2],flags))
    local _,_,actualFlags=love.window.getMode()
    assert(actualFlags.vsync==0,"uncapped benchmark requires vsync disabled")
    local w,h=g.getDimensions();local pw,ph=g.getPixelDimensions()
    assert(w==size[1] and h==size[2],"requested dimensions differ")
    for _,map in ipairs(maps) do
      local seed=27122026+#report.phases
      math.randomseed(seed);love.math.setRandomSeed(seed)
      Overworld.npcPool=nil
      U.teleport(game,map[1],map[2],map[3],"down")
      U.wait(600) -- shader/JIT/upload/fade warmup, not part of measurement
      local TR=require("src.render.TileRenderer")
      local cacheBefore=TR.gen3PaletteCacheStats and TR.gen3PaletteCacheStats()
      local world=game.overworld
      probes[#probes+1]=assert(world.map.renderer.gen3).tiles
      local beforeNPC=npcWorkload(world)
      local sampler=world.map.renderer.gen3.tiles.paletteSampler
      local samplerBefore=sampler and sampler:stats()
      local stackBefore=require("src.core.StateStack").describe(game.stack:top())
      collectgarbage("collect")
      phase={map=map[1],logicalWidth=w,logicalHeight=h,pixelWidth=pw,pixelHeight=ph,
        body={},frame={},readback={},transfer={},present={},render={},intervals={},
        update={},gcStep={},paletteSync={},readbackCalls=0,fullPaletteSamples=0}
      local cpu,wall,thread=os.clock(),timer.getTime(),threadClock and threadClock()
      U.wait(600)
      local elapsed,cpuElapsed=timer.getTime()-wall,os.clock()-cpu
      local threadElapsed=thread and threadClock()-thread
      local measured=phase;phase=nil;pending=nil
      local entry={map=map[1],logicalWidth=w,logicalHeight=h,pixelWidth=pw,pixelHeight=ph,
        mode=Frame.info().mode,measuredFrames=#measured.frame,readbackCalls=measured.readbackCalls,
        latencyFrames=Frame.info().latencyFrames or 0,pendingReadbacks=Frame.info().pendingReadbacks or 0,
        elapsedSeconds=elapsed,cpuMsPerFrame=cpuElapsed/#measured.frame*1000,metrics={},
        randomSeed=seed,npcWorkloadBefore=beforeNPC,npcWorkloadAfter=npcWorkload(world),
        stackBefore=stackBefore,stackAfter=require("src.core.StateStack").describe(game.stack:top()),
        fullPaletteSamples=measured.fullPaletteSamples,
        mainThreadCpuMsPerFrame=threadElapsed and threadElapsed/#measured.frame*1000}
      if samplerBefore then entry.paletteSamples={before=samplerBefore,after=sampler:stats()} end
      if cacheBefore then entry.paletteCache={before=cacheBefore,after=TR.gen3PaletteCacheStats()} end
      assert(entry.measuredFrames==600,"missing measured frames")
      for _,key in ipairs({"body","frame","readback","transfer","present","render","intervals","update","gcStep","paletteSync"}) do
        entry.metrics[key]=stats(measured[key])
      end
      assert(renderer~="Metal" or measured.readbackCalls==0,"benchmark changed Metal readback cost")
      assert(renderer~="OpenGL" or not readback or measured.readbackCalls==600,
        "each OpenGL recovery frame must submit one readback")
      report.phases[#report.phases+1]=entry
      print(string.format("[window-perf] %s %dx%d: render %.3f ms, interval %.3f ms, CPU %.3f ms",
        map[1],pw,ph,entry.metrics.render.meanMs,entry.metrics.intervals.meanMs,entry.cpuMsPerFrame))
      if os.getenv("POKEPORT_OS_WINDOW_PROOF")=="1" then
        -- Outside every timed interval. No Frame.observe/capture: GL must
        -- present its ordinary frame stream, including the changing stamp.
        proofActive=true
        local threshold=drawCount
        U.wait(10)
        local tag=({"initial-map","second-map","resized","map-return"})[#report.phases]
        local ffi=require("ffi");ffi.cdef[[int getpid(void);]]
        local request=assert(io.open(out.."/window-request.json","w"))
        request:write(Json.encode({phase=tag,pid=tonumber(ffi.C.getpid()),
          window=assert(require("src.render.MacWindowSurface").windowNumber()),
          logicalWidth=w,logicalHeight=h,minimumStamp=threshold}));request:close()
        local deadline=timer.getTime()+30
        while true do
          local ack=io.open(out.."/window-"..tag..".ok","r")
          if ack then ack:close();break end
          assert(timer.getTime()<deadline,"own-window proof timeout");U.wait(1)
        end
        proofActive=false
      end
    end
  end
  -- Run allocation probes only AFTER every timed phase and window proof.
  -- A tight sampler loop can change JIT/collector state even if its garbage
  -- is collected; it must not precede the workload being compared.
  for i,source in ipairs(probes) do
    local probe=Tiles.new({primary=source.primary,secondary=source.secondary},source)
    paletteTicks(probe,0)
    for tick=1,128 do paletteTicks(probe,tick) end
    collectgarbage("collect");collectgarbage("stop")
    local before=collectgarbage("count")
    for tick=129,248 do paletteTicks(probe,tick) end
    report.phases[i].paletteAllocationProbe={samples=120,warmupTicks=128,
      luaKiBPerSample=(collectgarbage("count")-before)/120,
      static=#probe.paletteState.primaryFrames==0 and #probe.paletteState.secondaryFrames==0}
    collectgarbage("restart");collectgarbage("collect")
  end
  Frame.draw=draw;g.present=present;g.readbackTexture=readback;g.readbackTextureAsync=readbackAsync;love.draw=originalDraw
  game.update=update;collectgarbage=gc;Tiles.setPaletteTicks=paletteTicks
  Cycles.sample=fullSample
  Overworld.computeNeighbors=computeNeighbors
  report.pass=true
  local file=assert(io.open(out.."/gpu.json","w"));file:write(Json.encode(report));file:close()
end
