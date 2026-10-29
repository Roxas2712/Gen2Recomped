io.stdout:setvbuf('no')
function love.errorhandler(err)
  io.stderr:write(debug.traceback(tostring(err),2)..'\n')
  return function()return 1 end
end
function love.load()
  local root=assert(os.getenv('POKEPORT_WORKER_QA_ROOT'))
  package.path=root..'/?.lua;'..package.path
  local W=require('src.core.BuildWorker')
  local P=require('src.core.Performance')
  -- The host is a separate LÖVE source directory. Keep the actual thread
  -- script and spawn function, supplying its bytes plus the owned Lua path.
  local file=assert(io.open(root..'/src/core/build_worker.lua','rb'))
  local script=file:read('*a');file:close()
  W.SCRIPT=love.filesystem.newFileData(('package.path=%q..package.path\n'):format(root..'/?.lua;')..script,'build_worker.lua')
  local checks=0
  local function check(v,why)checks=checks+1;assert(v,why)end
  local threads,channels={},{}
  local spawn=W._spawn
  W._spawn=function(jobs,results)
    local thread=spawn(jobs,results)
    threads[#threads+1]=thread
    channels[#channels+1]=jobs
    return thread
  end
  local function wait(done)
    local deadline=love.timer.getTime()+5
    repeat
      W.poll(4)
      for _,thread in ipairs(threads)do check(not thread:getError(),tostring(thread:getError()))end
      if done()then return end
      love.timer.sleep(.001)
    until love.timer.getTime()>deadline
    error('actual worker result timed out')
  end
  W.register('echo','tools.build-worker.echo')
  P.buildWorkers,P.tier=true,'high'
  local got
  local bytes=love.data.newByteData('owned bytes')
  check(W.submit('echo','data',{value=21,data=bytes},function(result,key)got={result,key}end)~=nil,'submit actual worker')
  wait(function()return got~=nil end)
  check(got[1].value==42 and got[2]=='data','actual callback value/key')
  check(got[1].data:getString()=='owned bytes','ByteData crosses the worker boundary')
  P.buildWorkers=false
  check(W.submit('echo','off',{value=1})==nil and W.pending()==0,'live pool honors disabled switch')
  P.buildWorkers=true
  local failure
  W.submit('echo','failure',{fail=true},nil,function(err,key)failure={err,key}end)
  wait(function()return failure~=nil end)
  check(failure[1]=='owned worker failure' and failure[2]=='failure','actual worker error attribution')
  local retiredCallbacks=0
  for cycle=1,4 do
    local old=channels[#channels]
    W.submit('echo','retired',{value=1,delay=.02},function()retiredCallbacks=retiredCallbacks+1 end)
    W.shutdown()
    got=nil
    W.submit('echo','restart',{value=cycle},function(result)got=result end)
    check(old~=channels[#channels],'restart isolates old stop sentinels')
    wait(function()return got~=nil end)
    check(got.value==cycle*2 and retiredCallbacks==0,'restart delivers only its own callback')
  end
  P.tier='low';got=nil
  W.submit('echo','low',{value=7},function(result)got=result end)
  check(W.running()==1,'LOW starts one worker after idle retiering')
  wait(function()return got~=nil end)
  check(got.value==14,'LOW worker completes')
  W.register('gen3atlas','src.compat.gen1.AtlasPixelsCore')
  local Pixels=require('src.compat.gen1.AtlasPixels')
  local atlasBytes=0
  for _,edition in ipairs({'firered','leafgreen','emerald','ruby','sapphire'})do
    local f=require('tools.native-atlas.fixture').new(edition)
    f.pair.primary.palettes[2][2]={7,113,203}
    local expected=Pixels.new(f.pair,f.layout)
    got=nil;local errorMessage
    W.submit('gen3atlas',edition,{pair=f.pair,layout=f.layout},function(result)got=result end,
      function(err)errorMessage=err end)
    wait(function()assert(not errorMessage,errorMessage);return got~=nil end)
    local model=Pixels.fromCore(got,f.pair,f.layout)
    for _,over in ipairs({false,true})do
      local bytes=model:rgba(over);atlasBytes=atlasBytes+#bytes
      check(bytes==expected:rgba(over),'threaded atlas pixels '..edition)
      check(model:blob(over)==expected:blob(over),'threaded atlas indices '..edition)
    end
    check(model.decoder.primary==f.pair.primary,'live primary restored on the main thread')
    check(W.running()==1,'atlas handler respects LOW single-worker pool')
  end
  got=nil
  W.submit('echo','graphics-after-atlas',{value=1},function(result)got=result end)
  wait(function()return got~=nil end)
  check(got.value==2,'atlas handler did not load graphics in the worker VM')
  W.shutdown()
  for _,thread in ipairs(threads)do thread:wait();check(not thread:getError(),'worker stops cleanly')end
  print('BUILD_WORKER_NATIVE_RESULT '..require('src.link.Json').encode({passed=true,checks=checks,
    actualThreads=true,channelRestarts=4,byteDataRoundTrip=true,lowWorkers=1,atlasBytesEqual=true,atlasRgbaBytes=atlasBytes,graphicsFree=true}))
  love.event.quit(0)
end
