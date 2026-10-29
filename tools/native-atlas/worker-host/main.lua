io.stdout:setvbuf('no')
local root=assert(os.getenv('QA_ATLAS_ROOT'));package.path=root..'/?.lua;'..package.path
function love.errorhandler(e)print(debug.traceback(tostring(e),2));return function()return 1 end end
function love.load()
 local checks=0
 local function check(v,why)checks=checks+1;assert(v,why)end
 local W=require('src.core.BuildWorker');local P=require('src.core.Performance')
 P.atlasWorker,P.buildWorkers,P.tier=true,true,'low'
 local f=assert(io.open(root..'/src/core/build_worker.lua','rb'));local script=f:read('*a');f:close()
 W.SCRIPT=love.filesystem.newFileData(('package.path=%q..package.path\n'):format(root..'/?.lua;')..script,'build_worker.lua')
 local Native=require('src.core.game3.tileset_native');local Stream=require('src.core.game3.asset_stream')
 local Build=require('src.compat.gen1.AtlasBuild');local Pixels=require('src.compat.gen1.AtlasPixels')
 local function prepare(edition)
  Native.release();local fixture=require('tools.native-atlas.session-fixture').new(edition)
  local before=Build._counters().submitted
  check(Native.prefetch(fixture.pair,1),'prefetch accepted')
  check(Build._counters().submitted==before+1,'actual worker submitted')
  local deadline=love.timer.getTime()+10
  local job=assert(Native._stream.pending[fixture.pair])
  while job._worker do
   check(love.timer.getTime()<deadline,'real worker reply bounded');W.poll(4);love.timer.sleep(.001)
  end
  check(job.ts==nil and Native.resident()==0,'actual reply performs no graphics allocations')
  check(job._core~=nil,'real detached CPU core delivered')
  return fixture,job
 end
 local function read(image)
  local g=love.graphics;local canvas=g.newCanvas(image:getWidth(),image:getHeight(),{format='rgba8'})
  g.push('all');g.setCanvas(canvas);g.origin();g.setShader();g.clear(0,0,0,0)
  g.setBlendMode('replace','premultiplied');g.setColor(1,1,1,1);g.draw(image);g.setCanvas();g.pop()
  local data=g.readbackTexture(canvas);local bytes=data:getString();data:release();canvas:release();return bytes
 end
 local function compare(fixture,ts)
  local expected=Pixels.new(fixture.picture.pair,fixture.picture.layout)
  expected:update(require('src.render.TileRenderer').animFrame())
  check(read(ts.image)==expected:rgba(false),'real under texture matches native pixel oracle')
  check(read(ts.overImage)==expected:rgba(true),'real over texture matches native pixel oracle')
 end
 for _,edition in ipairs{'firered','leafgreen','emerald','ruby','sapphire'}do
  local fixture,job=prepare(edition)
  Stream.update(1)
  check(job.ts.image and not job.ts.overImage,'one real texture in first slice')
  check(Native.resident()==0,'half upload stays private')
  Stream.update(1)
  check(job.ts.overImage and Native.resident()==0,'second texture waits for publication')
  Stream.update(1)
  local ts=assert(Native.get(fixture.pair));compare(fixture,ts)
  check(Build._cacheInfo(Native._pairs).worker==1,'real worker publication retains provenance')
  fixture,job=prepare(edition);Stream.update(1);local partial=job.ts
  fixture.game.data.map_tilesets.P.palettes[1][2][1]=222
  ts=assert(Native.get(fixture.pair));compare(fixture,ts)
  check(partial._retired and Build._cacheInfo(Native._pairs).worker==0,'late source edit releases real staged resources and falls back')
  fixture,job=prepare(edition);Stream.update(1);partial=job.ts
  Native._stream:cancel()
  check(partial._retired and Native.resident()==0 and next(Native._stream.pending)==nil,'cancel releases real half upload')
 end
 Native.release();W.shutdown()
 print('ATLAS_NATIVE_GPU_PASS '..require('src.link.Json').encode{passed=true,checks=checks,editions=5,realThreads=true,realTextureReadback=true,boundedUploads=true})
 love.event.quit(0)
end
