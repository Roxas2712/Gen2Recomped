-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
io.stdout:setvbuf('no')
local root = assert(os.getenv('PALETTE_INDEX_QA_ROOT'))
package.path = root .. '/?.lua;' .. root .. '/?/init.lua;' .. package.path
function love.errorhandler(err)
  io.stderr:write(debug.traceback(tostring(err), 2) .. '\n')
  return function() return 1 end
end
function love.load()
  local g, checks = love.graphics, 0
  local function check(value, label) checks = checks + 1; assert(value, label) end
  local Profile = require('src.core.FrameProfile')
  local Assets = require('src.render.Assets')
  local Version = require('src.core.GameVersion')
  local P = require('src.render.PaletteFX')
  local SR = require('src.render.SpriteRenderer')
  local TR = require('src.render.TileRenderer')
  Version.set('gold'); P.mode = 'gbc'; P.setDarkWorld(false)
  local source = love.image.newImageData(16, 96)
  for y = 0, 95 do for x = 0, 15 do
    local v = 1 - (x % 4) / 3
    source:setPixel(x, y, v, v, v, y % 7 == 0 and 0 or 1)
  end end
  local plain = g.newImage(source)
  Assets.image = function() return plain end
  Assets.imageData = function() return source:clone() end
  local colors = {{255, 239, 219}, {191, 47, 83}, {31, 137, 97}, {11, 17, 29}}
  local ts = {image='owned-gray',tilesPerRow=2,palMap={},palColors={colors}}
  for i = 1, 24 do ts.palMap[i] = 0 end
  local def = {id='OWNED',image='owned-gray',frames=6,gen2ObjPal=colors}
  local canvas = g.newCanvas(32, 96, {dpiscale=1})
  local function draw(profile)
    TR.invalidate(); SR.invalidate(); Profile.setEnabled(profile); Profile.reset()
    local sprite = SR.new(def)
    local tile = assert(TR.gen2AtlasFor(ts))
    local image = sprite:resolveImage()
    check(sprite:resolveImage() == image, 'warm OBJ lookup retains same RGBA image')
    check(TR.gen2AtlasFor(ts) == tile, 'warm atlas lookup retains same RGBA image')
    local counts = Profile.bakeCounts()
    if profile then
      check(counts['tiles.gen2'].total == 1, 'one cold atlas upload, zero warm bakes')
      check(counts['sprites.obp'].total == 1, 'one cold OBJ upload, zero warm bakes')
      TR.invalidate(); SR.invalidate()
      tile = assert(TR.gen2AtlasFor(ts)); image = SR.new(def):resolveImage()
      counts = Profile.bakeCounts()
      check(counts['tiles.gen2'].total == 2, 'invalidation rebuilds atlas once')
      check(counts['sprites.obp'].total == 2, 'invalidation rebuilds OBJ once')
    else check(next(counts) == nil, 'disabled profiling collects no counters') end
    g.push('all'); g.setCanvas(canvas); g.origin(); g.setShader(); g.setBlendMode('alpha')
    g.clear(0, 0, 0, 0); g.setColor(1, 1, 1, 1)
    g.draw(tile, 0, 0); g.draw(image, 16, 0)
    g.setCanvas(); g.pop()
    local data = canvas:newImageData(); local bytes = data:getString(); data:release()
    return bytes, counts
  end
  local off = draw(false)
  local on, counts = draw(true)
  local painted = 0
  for i = 4, #off, 4 do if off:byte(i) > 0 then painted = painted + 1 end end
  check(painted > 100, 'readback contains rendered atlas and sprite pixels')
  check(on == off, 'profiler off/on GPU readbacks are byte identical')
  Profile.setEnabled(false)
  local renderer, version, vendor, device = g.getRendererInfo()
  print('PALETTE_INDEX_GPU_RESULT ' .. require('src.link.Json').encode({
    passed=true, checks=checks, byteDifferences=0, bakes=counts,
    renderer=renderer, version=version, vendor=vendor, device=device,
    syntheticPixels=true, realSceneAcceptance=false, playerProfilesUsed=false,
  }))
  canvas:release(); plain:release(); source:release()
  love.event.quit(0)
end
