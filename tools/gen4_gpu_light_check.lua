-- Run:  luajit tools/gen4_gpu_light_check.lua
--
-- G2 -- THE AREA LIGHT IN THE VERTEX SHADER, against the CPU equation.
--
-- `Gen4Shade.forTemplate` folds a template into a closure and multiplies it
-- into every vertex colour at mesh build; G2 instead carries the normal as a
-- vertex attribute and evaluates `g4Shade` in the shader from
-- `Gen4Shade.uniforms(template)`.  A light band is then a uniform upload, not
-- a rebuild of every mesh.  The two must agree to the last bit of float
-- arithmetic a GPU would see, so this check re-evaluates the GLSL of
-- `g4Shade` in Lua from the uniform block and compares it with the closure
-- over real template shapes, many normals and every edge the closure has:
-- no light, a light from below, a channel no light reaches, a colour channel
-- at zero, four lights, ambient equal to diffuse.  It also pins the vertex
-- format, the shader text and the flag.  No GPU, ROM or window needed.

package.path = './?.lua;./?/init.lua;' .. package.path
love = love or require('tests.love_stub')

local PASS, FAIL = 0, 0
local function check(cond, label)
  if cond then PASS = PASS + 1 else FAIL = FAIL + 1; print('FAIL: ' .. label) end
end
local function near(a, b, eps) return math.abs(a - b) <= (eps or 1e-9) end

local Shade = require('src.render.Gen4Shade')
local AreaLight = require('src.import.Gen4AreaLight')
local MAX = AreaLight.CHANNEL_MAX

-- ------------------------------------------- the GLSL, transcribed exactly
local function clamp01(v) if v < 0 then return 0 elseif v > 1 then return 1 end return v end
local function g4Shade(u, nx, ny, nz)
  if not u or u.count < 0.5 or (nx * nx + ny * ny + nz * nz) < 0.25 then return 1, 1, 1 end
  local lr, lg, lb = 0, 0, 0
  for i = 1, 4 do
    if (i - 1) < u.count then
      local d = u.dirs[i]
      local v = -(nx * d[1] + ny * d[2] + nz * d[3])
      if v > 0 then
        lr, lg, lb = lr + v * u.cols[i][1], lg + v * u.cols[i][2], lb + v * u.cols[i][3]
      end
    end
  end
  local out = {}
  local lit = { lr, lg, lb }
  for c = 1, 3 do
    local safeUp = math.max(u.up[c], 1e-6)
    local res = clamp01(u.share[c] + (1 - u.share[c]) * lit[c] / safeUp)
    -- mix(res, 1, step(up, 0)): 1 where up <= 0
    out[c] = (u.up[c] <= 0) and 1 or res
  end
  return out[1], out[2], out[3]
end

-- ----------------------------------------------------- template fixtures
local function light(x, y, z, r, g, b)
  return { unit = { x, y, z }, colour = { r, g, b } }
end
local templates = {
  sun = { lights = { light(0.3, -0.9, 0.2, 31, 29, 24) },
          ambient = { 10, 10, 10 }, diffuse = { 20, 20, 20 } },
  dusk = { lights = { light(-0.6, -0.5, 0.6, 31, 14, 6), light(0.0, -0.2, -1.0, 4, 6, 20) },
           ambient = { 8, 6, 12 }, diffuse = { 24, 18, 14 } },
  fourLights = { lights = { light(0, -1, 0, 31, 31, 31), light(1, 0, 0, 31, 0, 0),
                            light(0, 0, 1, 0, 31, 0), light(-1, 0, 0, 0, 0, 31) },
                 ambient = { 5, 5, 5 }, diffuse = { 26, 26, 26 } },
  fromBelow = { lights = { light(0, 1, 0, 31, 31, 31) },          -- nothing reaches the top
                ambient = { 10, 10, 10 }, diffuse = { 20, 20, 20 } },
  deadChannel = { lights = { light(0, -1, 0, 31, 0, 31) },        -- green never lit
                  ambient = { 10, 0, 10 }, diffuse = { 20, 0, 20 } },
  allAmbient = { lights = { light(0.2, -0.9, 0.3, 31, 31, 31) },
                 ambient = { 31, 31, 31 }, diffuse = { 31, 31, 31 } },
  sparse = { lights = { [3] = light(0.1, -0.95, 0.1, 20, 25, 31) },  -- cartridge index gap
             ambient = { 10, 10, 10 }, diffuse = { 20, 20, 20 } },
  dark = { lights = {}, ambient = { 10, 10, 10 }, diffuse = { 20, 20, 20 } },
}

-- normals: axis-aligned, the tree lean, and a deterministic spread
local normals = {
  { 0, 1, 0 }, { 0, -1, 0 }, { 1, 0, 0 }, { -1, 0, 0 }, { 0, 0, 1 }, { 0, 0, -1 },
  { 0, 0.819, 0.575 }, { 0.707, 0.707, 0 }, { -0.577, 0.577, 0.577 },
}
local seed = 12345
local function rnd() seed = (seed * 1103515245 + 12345) % 2147483648; return seed / 2147483648 end
for _ = 1, 400 do
  local x, y, z = rnd() * 2 - 1, rnd() * 2 - 1, rnd() * 2 - 1
  local len = math.sqrt(x * x + y * y + z * z)
  if len > 1e-3 then normals[#normals + 1] = { x / len, y / len, z / len } end
end
-- ...and the signed-byte quantised ones the cache really carries (s8 / 127)
for i = -127, 127, 17 do
  for j = -127, 127, 31 do
    normals[#normals + 1] = { i / 127, j / 127, (127 - math.abs(i)) / 127 }
  end
end

-- ------------------------------------------------------ 1. equivalence
for name, template in pairs(templates) do
  local cpu = Shade.forTemplate(template)
  local u = Shade.uniforms(template)
  check((cpu == nil) == (u == nil), name .. ': uniforms exist exactly when the closure does')
  if cpu and u then
    local worst = 0
    for _, n in ipairs(normals) do
      local r1, g1, b1 = cpu(n[1], n[2], n[3])
      local r2, g2, b2 = g4Shade(u, n[1], n[2], n[3])
      worst = math.max(worst, math.abs(r1 - r2), math.abs(g1 - g2), math.abs(b1 - b2))
    end
    check(worst <= 1e-9, ('%s: shader and closure agree over %d normals (worst %.2e)'):format(name, #normals, worst))
  end
end
check(Shade.uniforms(templates.dark) == nil, 'a template with no enabled light answers nil, as forTemplate does')
check(Shade.uniforms(nil) == nil and Shade.uniforms('x') == nil, 'a non-template answers nil')

-- ---------------------------------------------- 2. the uniform block shape
do
  local u = Shade.uniforms(templates.dusk)
  check(u.count == 2, 'count is the number of enabled lights')
  check(#u.dirs == 4 and #u.cols == 4, 'direction and colour arrays are always four long for the shader')
  check(u.dirs[3][1] == 0 and u.cols[4][3] == 0, 'unused slots are zero')
  check(near(u.cols[1][1], 31 / MAX) and near(u.cols[1][2], 14 / MAX), 'colours are on the 0..1 scale the closure uses')
  check(near(u.share[1], 8 / (8 + 24)) and near(u.share[3], 12 / (12 + 14)), 'share is ambient / (ambient + diffuse) per channel')
  local cpuUp = { 0, 0, 0 }
  for i = 1, 2 do
    local v = -u.dirs[i][2]
    if v > 0 then for c = 1, 3 do cpuUp[c] = cpuUp[c] + v * u.cols[i][c] end end
  end
  check(near(u.up[1], cpuUp[1]) and near(u.up[2], cpuUp[2]) and near(u.up[3], cpuUp[3]), 'up is lit(0, 1, 0)')
  local s = Shade.uniforms(templates.sparse)
  check(s.count == 1 and near(s.dirs[1][2], -0.95), 'a cartridge index gap still packs the light first')
  local fb = Shade.uniforms(templates.fromBelow)
  check(fb.up[1] == 0, 'a light from below leaves up at zero...')
  check(select(1, g4Shade(fb, 0, 1, 0)) == 1, '...and the shader then multiplies by 1, as the closure does')
end

-- --------------------------------------------- 3. the unlit vertex escape
do
  local u = Shade.uniforms(templates.sun)
  local r, g, b = g4Shade(u, 0, 0, 0)
  check(r == 1 and g == 1 and b == 1, 'a zero normal (no light, lightmapped, fogged) is left alone')
end

-- ---------------------------------------------- 4. format, shader, flag
do
  local src = assert(io.open('src/render/Gen4Model.lua')):read('*a')
  check(src:find('{ "LitNormal", "float", 3 },', 1, true) ~= nil, 'the vertex format carries LitNormal')
  check(select(2, src:gsub('attribute vec3 LitNormal;', '')) == 2, 'both shader variants declare the attribute')
  check(select(2, src:gsub('VaryingColor%.rgb %*= g4Shade%(LitNormal%);', '')) == 2, 'both shader variants apply it in position()')
  check(src:find('uniform vec3 g4LightDir%[4%];') ~= nil, 'four light directions are declared')
  check(src:find('uniform vec3 g4LightCol%[4%];') ~= nil, 'four light colours are declared')
  check(src:find('shader:send("g4LightDir", u.dirs[1], u.dirs[2], u.dirs[3], u.dirs[4])', 1, true) ~= nil,
        'the array uniform is sent with all four entries')
  -- every literal vertex handed to newMesh(FORMAT, ...) has fifteen numbers
  local short = 0
  for line in src:gmatch('[^\n]+') do
    if line:find('1, 1, 1, 1, ', 1, true) and line:find('{', 1, true) and line:find('}', 1, true) then
      -- a call argument list carries commas of its own: vAt(row, a0)
      local inner = line:match('{(.-)}'):gsub('%b()', 'X')
      local n = 0
      for _ in inner:gmatch('[^,]+') do n = n + 1 end
      if n ~= 15 then short = short + 1; print('  short vertex literal: ' .. line) end
    end
  end
  check(short == 0, 'every literal vertex matches the fifteen-component format')
  local ground = assert(io.open('src/render/Gen4Ground.lua')):read('*a')
  check(ground:find('function Gen4Ground:lightBandChanged()', 1, true) ~= nil, 'the ground routes a band change through lightBandChanged')
  check(ground:find('if self.lightBand ~= band then self:lightBandChanged() end', 1, true) ~= nil,
        'and the periodic light check calls it instead of dropLitModels')
  check(select(2, ground:gsub('self:bindLight%(%)', '')) >= 5, 'every pass binds the light before drawing')
  local Performance = require('src.core.Performance')
  check(Performance.gen4GpuLight == true, 'G2 is on by default')
end

print(('%d checks, %d failed'):format(PASS + FAIL, FAIL))
if FAIL > 0 then os.exit(1) end
