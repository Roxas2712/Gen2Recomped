-- Run:  luajit tools/gen4_chunk_prebuild_check.lua
--
-- G9 -- THE RING AROUND THE GEN 4 VIEW IS MESHED IN IDLE TIME.  A ground
-- with a 6x6 grid and a 2x2 live view: the candidates are exactly the ring
-- one cell outside the view (and never a cell outside the grid or one with
-- no land); prebuild builds as many as the slice allows and stops when the
-- running cost says the next one will not fit; a full live cache stops it;
-- the switch stops it; the idle service reports busy/not busy; and
-- IdleStream hands a registered service its slice after the Gen 3 stream.

package.path = './?.lua;./?/init.lua;' .. package.path
love = love or require('tests.love_stub')

local PASS, FAIL = 0, 0
local function check(cond, label)
  if cond then PASS = PASS + 1 else FAIL = FAIL + 1; print('FAIL: ' .. label) end
end

local Performance = require('src.core.Performance')
local ok, Gen4Ground = pcall(require, 'src.render.Gen4Ground')
if not ok then
  print('gen4_chunk_prebuild_check: Gen4Ground did not load headless (' .. tostring(Gen4Ground) .. ')')
  os.exit(1)
end

-- a bare ground: only what the prebuild reads, with liveModel stubbed to
-- count builds instead of meshing
local function ground(w, h, view)
  local land = {}
  for i = 1, w * h do land[i] = i end
  local g = setmetatable({
    grid = { width = w, height = h, land = land },
    liveModels = {}, liveOrder = {},
    liveView = view and { view[1], view[2], view[3], view[4] } or nil,
    built = {},
  }, { __index = Gen4Ground })
  g.buildSeconds = 0.001
  g.now = 0
  g.clock = function() return g.now end
  function g:liveModel(id)
    self.now = self.now + self.buildSeconds
    self.liveModels[id] = { id = id }
    self.liveOrder[#self.liveOrder + 1] = id
    self.built[#self.built + 1] = id
    return self.liveModels[id]
  end
  return g
end

-- 1. the ring: view (2,2)-(3,3) in a 6x6 grid -> ring is 16 cells
do
  local g = ground(6, 6, { 2, 2, 3, 3 })
  local seen = {}
  while true do
    local land = g:prebuildCandidate()
    if not land then break end
    seen[#seen + 1] = land
    g.liveModels[land] = { }
  end
  check(#seen == 16, '16 ring cells around a 2x2 view (' .. #seen .. ')')
  local inView = false
  for _, id in ipairs(seen) do
    local cx, cy = (id - 1) % 6, math.floor((id - 1) / 6)
    if cx >= 2 and cx <= 3 and cy >= 2 and cy <= 3 then inView = true end
  end
  check(not inView, 'no view cell is a candidate')
end

-- 2. the grid edge: view at the corner -> ring stays inside the grid
do
  local g = ground(6, 6, { 0, 0, 1, 1 })
  local count = 0
  while g:prebuildCandidate() do g.liveModels[g:prebuildCandidate()] = {}; count = count + 1 end
  check(count == 5, 'a corner view has a 5-cell ring inside the grid (' .. count .. ')')
end

-- 3. a cell with no land, and a known-empty mesh, are never candidates
do
  local g = ground(6, 6, { 2, 2, 3, 3 })
  g.grid.land[1 * 6 + 1 + 1] = nil   -- (1,1) has no land
  g.liveModels[1 * 6 + 2 + 1] = false -- (2,1) meshed empty
  local seen = {}
  while g:prebuildCandidate() do local l = g:prebuildCandidate(); seen[l] = true; g.liveModels[l] = {} end
  check(seen[1 * 6 + 1 + 1] == nil, 'no land: not a candidate')
  check(seen[1 * 6 + 2 + 1] == nil, 'known empty: not a candidate')
end

-- 4. prebuild spends the slice and stops when the next build will not fit
do
  local g = ground(6, 6, { 2, 2, 3, 3 })
  local built = g:prebuild(0.0035, g.clock)
  check(built == 3, 'a 3.5 ms slice at 1 ms a build builds 3 (' .. built .. ')')
  check(g.prebuildCost and g.prebuildCost > 0, 'the running cost is recorded')
  built = g:prebuild(0.0005, g.clock)
  check(built == 0, 'a slice shorter than the cost builds nothing')
  built = g:prebuild(1, g.clock)
  check(built == 13 and not g:prebuildPending(), 'a long slice finishes the ring and the service goes quiet')
end

-- 5. a full live cache stops the prebuild (never evict what is on screen)
do
  local g = ground(6, 6, { 2, 2, 3, 3 })
  for i = 1, Gen4Ground.LIVE_CACHE - Gen4Ground.PREBUILD_HEADROOM + 1 do g.liveOrder[i] = -i end
  check(g:prebuildCandidate() == nil, 'no headroom in the live cache: nothing to prebuild')
end

-- 6. the switch
do
  local g = ground(6, 6, { 2, 2, 3, 3 })
  Performance.gen4ChunkPrebuild = false
  check(g:prebuildCandidate() == nil, 'gen4ChunkPrebuild=false: nothing to prebuild')
  Performance.gen4ChunkPrebuild = true
  check(g:prebuildCandidate() ~= nil, '...and back on')
end

-- 7. no live view yet (baked path, or before the first live frame)
do
  local g = ground(6, 6, nil)
  check(not g:prebuildPending(), 'no live view: not busy')
end

-- 8. the idle service through IdleStream
do
  package.loaded['src.core.game3.asset_stream'] = nil
  local IdleStream = require('src.core.IdleStream')
  local g = ground(6, 6, { 2, 2, 3, 3 })
  IdleStream.register(g:idleService())
  check(IdleStream.busy(), 'a ground with a ring to build makes the pump busy')
  Performance.tier = 'high'
  local timer = { now = 0 }
  function timer.getTime() return timer.now end
  g.clock = function() return timer.now end
  local offered = IdleStream.run(timer, 0.010)
  check(offered > 0, 'the pump offered the service a slice')
  check(#g.built > 0 and #g.built <= 6, 'the service built within a 6 ms cap (' .. #g.built .. ')')
  IdleStream.unregister(g:idleService())
  check(not IdleStream.busy(), 'unregistered: the pump is quiet')
end

print(('gen4_chunk_prebuild_check: %d passed, %d failed'):format(PASS, FAIL))
if FAIL > 0 then os.exit(1) end
