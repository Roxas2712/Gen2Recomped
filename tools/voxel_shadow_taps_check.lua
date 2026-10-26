-- Run:  luajit tools/voxel_shadow_taps_check.lua
--
-- V6 -- ONE SHADOW-MAP READ PER FRAGMENT ON BALANCED AND LOW.
--
-- The tier table names the filter (shadowTaps), the scene shader carries
-- both filters under SUN_ONE_TAP with the same normalisation, and
-- Voxel3D.shader keys its variant cache by the answer so a tier change binds
-- the other program.  Headless: the mod's Tier module is loaded the way the
-- other voxel tools load it, with the engine's Performance module standing
-- in as the tier source.
package.path = './?.lua;./?/init.lua;' .. package.path
local PASS, FAIL = 0, 0
local function check(cond, label)
  if cond then PASS = PASS + 1 else FAIL = FAIL + 1; print('FAIL: ' .. label) end
end

local Performance = require('src.core.Performance')
local libs = {}
local V = { require = function(n)
  if not libs[n] then libs[n] = assert(loadfile('mods/DRAMATIC_SHAPE/lib/' .. n .. '.lua'))(V) end
  return libs[n]
end }
local Tier = V.require('Tier')

for _, t in ipairs({ 'high', 'balanced', 'low' }) do
  Performance.tier = t
  local caps = Tier.caps()
  check(type(caps.shadowTaps) == 'number', t .. ' names a tap count')
end
Performance.tier = 'high';     check(Tier.caps().shadowTaps == 4, 'HIGH keeps the 2x2 filter')
Performance.tier = 'balanced'; check(Tier.caps().shadowTaps == 1, 'BALANCED reads once')
Performance.tier = 'low';      check(Tier.caps().shadowTaps == 1, 'LOW reads once (and has no sun pass anyway)')
Performance.tier = 'high'

local src = assert(io.open('mods/DRAMATIC_SHAPE/lib/Voxel3D.lua')):read('*a')
check(src:find('#ifdef SUN_ONE_TAP', 1, true) ~= nil, 'the scene shader carries the one-tap filter')
check(src:find('float lit = 4.0 * step(z, sunDepth(p.xy));', 1, true) ~= nil, 'one tap is scaled by four...')
check(src:find('return 1.0 - sunDark * edge * (1.0 - lit * 0.25);', 1, true) ~= nil, '...so the shared normalisation is unchanged')
check(src:find('lit = min(lit, 4.0 * step(z, sunDynamicDepth(p.xy)));', 1, true) ~= nil, 'the moving-caster map takes one tap too')
check(src:find('if oneTap then key = tostring(key) .. "-1tap" end', 1, true) ~= nil, 'the variant cache is keyed by the filter')
check(src:find('if oneTap then src="#define SUN_ONE_TAP 1\\n"..src end', 1, true) ~= nil, 'and the define is prepended for it')
-- both branches must balance: one #ifdef, one #else, one #endif inside sunlight
local body = src:match('float sunlight%(vec3 p%) {(.-)\n  }')
check(body ~= nil, 'sunlight() is where the filter lives')
if body then
  local _, ifdefs = body:gsub('#ifdef SUN_ONE_TAP', '')
  local _, elses = body:gsub('#else', '')
  local _, endifs = body:gsub('#endif', '')
  check(ifdefs == 1 and elses == 1 and endifs == 1, 'the preprocessor branches in sunlight() balance')
end

print(('%d checks, %d failed'):format(PASS + FAIL, FAIL))
if FAIL > 0 then os.exit(1) end
