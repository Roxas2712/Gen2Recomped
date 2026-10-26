-- Run:  luajit tools/assets_shared_decode_check.lua
--
-- G8 -- ONE DECODE PER SHEET FOR THE READ-ONLY BAKES.
--
-- `Assets.imageData` decodes on every call because some callers write into
-- the result; `Assets.imageDataShared` answers the same decoded data from a
-- cache for callers that only read.  The cache must hand back one object
-- per path, drop it with the image cache, and leave `imageData` fresh per
-- call; and every bake that only reads must take the shared one while the
-- writers keep the fresh one.
package.path = './?.lua;./?/init.lua;' .. package.path
love = love or require('tests.love_stub')
local decodes = 0
love.image = love.image or {}
function love.image.newImageData(a, b)
  decodes = decodes + 1
  return { id = decodes, getDimensions = function() return 8, 8 end, getWidth = function() return 8 end, getHeight = function() return 8 end }
end

local PASS, FAIL = 0, 0
local function check(cond, label)
  if cond then PASS = PASS + 1 else FAIL = FAIL + 1; print('FAIL: ' .. label) end
end

local Assets = require('src.render.Assets')
local a1 = Assets.imageDataShared('assets/generated/tilesets/probe.png')
local a2 = Assets.imageDataShared('assets/generated/tilesets/probe.png')
check(a1 == a2, 'the shared decode is one object per path')
local before = decodes
Assets.imageDataShared('assets/generated/tilesets/probe.png')
check(decodes == before, 'a third request decodes nothing')
local f1 = Assets.imageData('assets/generated/tilesets/probe.png')
local f2 = Assets.imageData('assets/generated/tilesets/probe.png')
check(f1 ~= f2 and f1 ~= a1, 'imageData stays fresh per call and never hands out the shared object')
Assets.invalidate()
local a3 = Assets.imageDataShared('assets/generated/tilesets/probe.png')
check(a3 ~= a1, 'invalidate drops the shared decode with the image cache')

local tr = assert(io.open('src/render/TileRenderer.lua')):read('*a')
local sr = assert(io.open('src/render/SpriteRenderer.lua')):read('*a')
local _, trFresh = tr:gsub('Assets%.imageData[,(]', '')
local _, trShared = tr:gsub('Assets%.imageDataShared', '')
check(trFresh == 0, 'TileRenderer takes no fresh decode any more (' .. trFresh .. ')')
check(trShared >= 10, 'TileRenderer reads every sheet through the shared decode (' .. trShared .. ')')
check(sr:find('ShadeRecolour.whole(Assets.imageDataShared(path), colors, "obp")', 1, true) ~= nil, 'the OBP FFI pass reads the shared decode')
check(sr:find('local id = Assets.imageData(path)\n      id:mapPixel(', 1, true) ~= nil, 'the OBP mapPixel fallback, which writes, keeps a fresh one')
-- nothing in TileRenderer writes into a shared decode
for _, verb in ipairs({ 'mapPixel', 'setPixel', 'paste' }) do
  for name in tr:gmatch('local (%w+) = Assets%.imageDataShared%(') do
    check(tr:find(name .. ':' .. verb .. '%(') == nil, ('TileRenderer never calls %s on shared decode `%s`'):format(verb, name))
  end
end

print(('%d checks, %d failed'):format(PASS + FAIL, FAIL))
if FAIL > 0 then os.exit(1) end
