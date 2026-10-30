io.stdout:setvbuf('no')
function love.errorhandler(err)
  io.stderr:write(debug.traceback(tostring(err),2)..'\n')
  return function()return 1 end
end
function love.load()
  local root=assert(os.getenv('GEN1_PERF_ROOT'))
  package.path=root..'/?.lua;'..root..'/?/init.lua;'..package.path
  local W=require('src.core.BuildWorker');local P=require('src.core.Performance')
  P.tier='low'
  local f=assert(io.open(root..'/src/core/build_worker.lua','rb'));local boot=f:read('*a');f:close()
  W.SCRIPT=love.filesystem.newFileData(('package.path=%q..package.path\n'):format(root..'/?.lua;')..boot,'build_worker.lua')
  local threads={};local spawn=W._spawn
  W._spawn=function(...)
    local t=spawn(...);threads[#threads+1]=t;return t
  end
  local M=require('src.render.GbAssetPrefetch');local Assets=require('src.render.Assets')
  local checks=0
  local function check(v,why)checks=checks+1;assert(v,why)end
  local function readback(image)
    local g=love.graphics;local w,h=image:getDimensions()
    local canvas=g.newCanvas(w,h,{format='rgba8',dpiscale=1})
    g.push('all');g.setCanvas(canvas);g.clear(0,0,0,0)
    g.origin();g.setColor(1,1,1,1);g.setBlendMode('replace');g.draw(image);g.pop()
    local pixels=canvas:newImageData();canvas:release();return pixels
  end
  local function wait(key)
    local deadline=love.timer.getTime()+10
    repeat
      M.service.step();W.poll(4)
      for _,t in ipairs(threads)do assert(not t:getError(),tostring(t:getError()))end
      if M.has(key)then return end
      love.timer.sleep(.001)
    until love.timer.getTime()>deadline
    error('Actual GB worker timed out: '..key..' '..tostring(M.status().lastError))
  end
  local src=love.image.newImageData(16,16,'rgba8')
  for y=0,15 do for x=0,15 do
    local c=({0,43,44,127,128,211,212,255})[x%8+1]/255
    src:setPixel(x,y,c,c,c,y%5==0 and 0 or 1)
  end end
  local raw=src:encode('png'):getString()
  love.filesystem.createDirectory('assets/generated/tilesets')
  local path='assets/generated/tilesets/prefetch.png'
  assert(love.filesystem.write(path,raw))
  check(Assets.prefetchImage(path),'native Assets queues a PNG hint')
  wait('image:'..path)
  check(W.running()==1,'LOW uses the existing single worker')
  local a,b=Assets.imageData(path),Assets.imageData(path)
  check(a~=b and a:getString()==src:getString(),'mutable readers receive exact independent clones')
  a:setPixel(0,0,1,0,0,1)
  check(b:getString()==src:getString(),'mutation cannot contaminate shared prefetched pixels')
  local shared=Assets.imageDataShared(path)
  check(shared==Assets.imageDataShared(path)and shared:getString()==src:getString(),'shared decode retains native cache semantics')
  local image=Assets.image(path)
  check(image:getWidth()==16 and image:getHeight()==16,'real graphics upload accepts prefetched pixels')
  local colors={{240,230,220},{120,110,100},{60,50,40},{10,20,30}}
  local other={{200,240,220},{40,170,90},{20,100,60},{0,30,10}}
  local FX=require('src.render.PaletteFX');local Tiles=require('src.render.TileRenderer')
  local group=0
  FX.usesGbcPack=function()return true end
  FX.worldGroupColors=function()return{colors,other}end
  FX.worldGroupAt=function()return group end
  FX.darkKey=function()return''end
  FX.TILE_ALIASES={MAP={{tile=0,alias=3,group=0}}}
  local ts={id='TS',image=path,tilesPerRow=2}
  local data={maps={MAP={tileset='TS'}},tilesets={TS=ts}}
  local submit,payload=W.submit
  W.submit=function(kind,key,value,...)
    if kind=='gb-assets'and value.kind=='bake'then payload=value end
    return submit(kind,key,value,...)
  end
  P.gbAssetPrefetch=false
  local control=readback(Tiles.gbcAtlasFor(ts,'MAP',data))
  Tiles.invalidate();P.gbAssetPrefetch=true
  check(Tiles.prefetchAtlas(data,'MAP',true),'native TileRenderer queues RED++ preparation')
  wait('atlas:'..path..'#gbc:MAP')
  check(#payload.palettes==1 and #payload.tilePalettes==4 and not payload.colors,
    'the actual channel payload sends one palette plus numeric tile indices')
  check(payload.tilePalettes[1]==payload.tilePalettes[4]and payload.aliases[1].palette==1,
    'repeated tiles and aliases share the compact palette index')
  W.submit=submit
  local actual=readback(Tiles.gbcAtlasFor(ts,'MAP',data))
  check(actual:getString()==control:getString(),'actual threaded atlas and synchronous native pixels are byte-identical')
  Tiles.invalidate();check(Tiles.prefetchAtlas(data,'MAP',true))
  wait('atlas:'..path..'#gbc:MAP')
  colors[2][1]=17 -- change after completion, before publication
  local edited=readback(Tiles.gbcAtlasFor(ts,'MAP',data))
  Tiles.invalidate();P.gbAssetPrefetch=false
  local expected=readback(Tiles.gbcAtlasFor(ts,'MAP',data))
  check(edited:getString()==expected:getString(),'in-place palette edits reject stale worker output')
  check(edited:getString()~=control:getString(),'edited colors really reach the renderer')
  P.gbAssetPrefetch=true;Tiles.invalidate();check(Tiles.prefetchAtlas(data,'MAP',true))
  wait('atlas:'..path..'#gbc:MAP');group=1
  local regrouped=readback(Tiles.gbcAtlasFor(ts,'MAP',data))
  Tiles.invalidate();P.gbAssetPrefetch=false
  local regroupedExpected=readback(Tiles.gbcAtlasFor(ts,'MAP',data))
  check(regrouped:getString()==regroupedExpected:getString()and regrouped:getString()~=edited:getString(),
    'changed tile palette assignments reject completed compact output')
  P.gbAssetPrefetch=true;Tiles.invalidate();check(Tiles.prefetchAtlas(data,'MAP',true))
  wait('atlas:'..path..'#gbc:MAP');FX.TILE_ALIASES.MAP[1].group=1
  local realiased=readback(Tiles.gbcAtlasFor(ts,'MAP',data))
  Tiles.invalidate();P.gbAssetPrefetch=false
  local realiasedExpected=readback(Tiles.gbcAtlasFor(ts,'MAP',data))
  check(realiased:getString()==realiasedExpected:getString()and realiased:getString()~=regrouped:getString(),
    'changed alias palettes reject completed compact output')
  local groupAt=FX.worldGroupAt
  FX.worldGroupAt=function(_,_,tile)colors[2][1]=5+tile*20;return 0 end
  P.gbAssetPrefetch=true;Tiles.invalidate();check(Tiles.prefetchAtlas(data,'MAP',true))
  wait('atlas:'..path..'#gbc:MAP')
  local dynamic=readback(Tiles.gbcAtlasFor(ts,'MAP',data))
  Tiles.invalidate();P.gbAssetPrefetch=false
  local dynamicExpected=readback(Tiles.gbcAtlasFor(ts,'MAP',data))
  check(dynamic:getString()==dynamicExpected:getString(),
    'custom selectors may edit a shared color row between individual tiles')
  FX.worldGroupAt=groupAt
  P.gbAssetPrefetch=true;Assets.invalidate()
  check(M.status().bytes==0 and M.status().pending==0,'native invalidation retires all speculative state')
  -- Overrides are resolved before submission and have their own cache key.
  local override='mods/qa/overrides/tilesets/prefetch.png'
  love.filesystem.createDirectory('mods/qa/overrides/tilesets')
  local replacement=src:clone();replacement:setPixel(0,1,.4,.2,.8,1)
  local replacementPng=replacement:encode('png'):getString()
  assert(love.filesystem.write(override,replacementPng))
  Assets.installLoader({loaded={{path='mods/qa',manifest={id='qa'}}}})
  check(Assets.prefetchImage(path),'mod override queues')
  wait('image:'..override)
  check(Assets.imageData(path):getString()==replacement:getString(),'worker respects actual native mod override resolution')
  Assets.installLoader(nil)
  -- A private cache uses a main-state prefix shim absent in worker states.
  local Cache=require('src.import.CacheFs')
  local prefix='launcher/private_games/qa/'
  love.filesystem.createDirectory(prefix..'assets/generated/tilesets')
  assert(love.filesystem.write(prefix..path,replacementPng))
  Cache.installPrefixShim(prefix);Assets.invalidate()
  check(Assets.prefetchImage(path),'private edition image queues')
  wait('image:'..path)
  check(Assets.imageData(path):getString()==replacement:getString(),'worker opens exact captured private-edition path')
  Cache.clearPrefixShim();Assets.invalidate()
  -- Patched public pixel readers retain their own transformation path.
  local mutable=Assets.imageData
  Assets.imageData=function()return replacement:clone()end
  check(not Assets.prefetchPayload(path),'custom pixel readers retain synchronous ownership')
  check(Assets.imageDataShared(path):getString()==replacement:getString(),'shared decode still delegates to the public reader')
  Assets.imageData=mutable;Assets.invalidate()
  check(not Assets.prefetchPayload('image@2x.png'),'DPI-special images retain their path loader')
  local before=M.status().queued
  P.buildWorkers=false
  check(not Assets.prefetchImage(path)and M.status().queued==before,'unavailable pool retains synchronous fallback')
  -- Exercise the shipping quit owner, not a test-only direct pool shutdown.
  require('src.core.SessionLifecycle').endProcess()
  check(W.running()==0 and W.pending()==0,'native process exit retires the actual pool')
  check(M.status().bytes==0,'native process exit releases prefetched CPU pixels')
  for _,t in ipairs(threads)do t:wait();assert(not t:getError())end
  print('GB_PREFETCH_RESULT '..require('src.link.Json').encode({passed=true,checks=checks,
    actualThreads=true,lowWorkers=1,atlasPixelsEqual=true,paletteMutation=true,
    overrides=true,privateEditionPaths=true,customReaders=true,processExit=true,
    renderer=love.graphics.getRendererInfo()}))
  love.event.quit(0)
end
