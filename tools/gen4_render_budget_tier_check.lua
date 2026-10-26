-- Run:  luajit tools/gen4_render_budget_tier_check.lua
--
-- G6 -- THE GEN 4 SUPERSAMPLE UNDER THE PERFORMANCE TIER, and the scratch
-- quads.  A phone or handheld must never be handed a x3 / x4 target however
-- the OPTIONS row was left; the row itself offers only the rungs the tier
-- allows; and the transition / snow effects re-aim one quad per purpose
-- instead of asking for a new one per band or scanline.

package.path = './?.lua;./?/init.lua;' .. package.path
love = love or require('tests.love_stub')

local PASS, FAIL = 0, 0
local function check(cond, label)
  if cond then PASS = PASS + 1 else FAIL = FAIL + 1; print('FAIL: ' .. label) end
end

local Performance = require('src.core.Performance')
check(Performance.CAPS.high.gen4RenderScaleMax == 4, 'HIGH allows every rung')
check(Performance.CAPS.balanced.gen4RenderScaleMax == 2, 'BALANCED stops at x2')
check(Performance.CAPS.low.gen4RenderScaleMax == 1, 'LOW draws at the DS size only')

local src = assert(io.open('src/render/Gen4Ground.lua')):read('*a')
check(src:find('function Gen4Ground.renderScaleCap()', 1, true) ~= nil, 'the ground exposes the cap')
check(src:find('local cap = Gen4Ground.renderScaleCap()\n    if index > cap then index = cap end\n    Gen4Ground.renderScaleIndex = index', 1, true) ~= nil,
      'syncRenderScale clamps the stored option against it')
check(src:find('local cap = Gen4Ground.renderScaleCap()\n  if index > cap then index = cap end\n  Gen4Ground.renderScaleIndex = index', 1, true) ~= nil,
      'setRenderScale clamps a direct set too')
local menu = assert(io.open('src/ui/OptionsMenu.lua')):read('*a')
check(menu:find('math.min(#Gen4Ground.RENDER_SCALES, Gen4Ground.renderScaleCap())', 1, true) ~= nil,
      'the 3D RES row cycles only the allowed rungs')

-- the clamp itself, with the module's own tier table
do
  local ok, Gen4Ground = pcall(require, 'src.render.Gen4Ground')
  if ok then
    local was = Performance.tier
    Performance.tier = 'low'
    check(Gen4Ground.setRenderScale(4) == 1, 'LOW: a x4 request draws at DS size')
    Performance.tier = 'balanced'
    check(Gen4Ground.setRenderScale(4) == 2, 'BALANCED: a x4 request draws at x2')
    check(Gen4Ground.setRenderScale(2) == 2, 'BALANCED: x2 is honoured')
    Performance.tier = 'high'
    check(Gen4Ground.setRenderScale(4) == 4, 'HIGH: x4 is honoured')
    local game = { save = { options = { gen4RenderScale = 4, performance = 'high' } } }
    Performance.tier = 'balanced'
    local scale, index = Gen4Ground.syncRenderScale(game)
    check(scale == 2 and index == 2, 'syncRenderScale clamps a stored x4 to the live tier')
    check(game.save.options.gen4RenderScale == 4, 'and leaves the stored option alone')
    Performance.tier = was
  else
    print('  (Gen4Ground not loadable headless here: ' .. tostring(Gen4Ground) .. ')')
  end
end

-- scratch quads
do
  local t = assert(io.open('src/render/Gen4BattleTransition.lua')):read('*a')
  local _, perFrame = t:gsub('g%.newQuad%(', '')
  check(perFrame == 0, 'the transition asks love.graphics.newQuad for no quad per draw any more')
  check(t:find('sliceScratch:setViewport(x, y, w, h, sw, sh)', 1, true) ~= nil, 'the slice quad is re-aimed with the source size')
  check(t:find('bannerScratch:setViewport(x, y, w, h, sw, sh)', 1, true) ~= nil, 'the banner quad too')
  local sn = assert(io.open('src/render/Gen4SnowView.lua')):read('*a')
  local _, snowPerFrame = sn:gsub('g%.newQuad%(', '')
  check(snowPerFrame == 0, 'the snow view asks for no quad per draw any more')
  check(sn:find('layerScratch:setViewport(x, y, w, h, 256, 256)', 1, true) ~= nil, 'the layer quad is re-aimed')
end

print(('%d checks, %d failed'):format(PASS + FAIL, FAIL))
if FAIL > 0 then os.exit(1) end
