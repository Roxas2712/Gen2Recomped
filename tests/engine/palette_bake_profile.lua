-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
local lines = {}
package.loaded['src.core.Logger'] = {
  warn = function() end, flush = function() end,
  report = function(fmt, ...) lines[#lines + 1] = string.format(fmt, ...) end,
}
love = { timer = { getTime = function() return 1 end } }
local P = require('src.core.FrameProfile')
local checks = 0
local function check(value, label) checks = checks + 1; assert(value, label) end
P.bake('disabled')
check(next(P.bakeCounts()) == nil, 'disabled profiler retains no bake state')
P.setEnabled(true)
for _ = 1, 8 do P.bake('tiles.shift') end
local counts = P.bakeCounts()
check(counts['tiles.shift'].total == 8, 'eight generated images counted exactly')
check(counts['tiles.shift'].currentFrame == 8, 'current frame sees complete burst')
check(counts['tiles.shift'].peakPerFrame == 8, 'peak records cold-cache burst')
counts['tiles.shift'].total = 999
counts.other = {}
check(P.bakeCounts()['tiles.shift'].total == 8, 'snapshot cannot mutate live totals')
P.frame()
check(P.bakeCounts()['tiles.shift'].currentFrame == 0, 'rendered-frame boundary clears current count')
P.bake('tiles.shift')
check(P.bakeCounts()['tiles.shift'].total == 9, 'window total survives frame boundary')
check(P.bakeCounts()['tiles.shift'].peakPerFrame == 8, 'smaller burst preserves peak')
P.bake('sprites.obp')
P.count('ordinary count', 2)
for _ = 2, 120 do P.frame() end
local report = table.concat(lines, '\n')
check(report:find('total=9  peak=8/frame  mean=0.075/frame', 1, true), 'report retains exact totals, peak and fractional mean')
check(report:find('total=1  peak=1/frame  mean=0.008/frame', 1, true), 'one hitch in 120 frames remains visible')
check(report:find('ordinary count', 1, true), 'existing section/count reports survive')
check(next(P.bakeCounts()) == nil, 'automatic window rollover resets bake state')
P.bake('one')
P.reset()
check(next(P.bakeCounts()) == nil, 'explicit reset clears all counters')
P.bake('two')
P.setEnabled(false)
P.bake('disabled')
check(next(P.bakeCounts()) == nil, 'disable resets and stops collection')
P.setEnabled(true)
check(next(P.bakeCounts()) == nil, 'new profile starts clean')
print('PALETTE_BAKE_PROFILE_PASS ' .. checks .. ' checks')
