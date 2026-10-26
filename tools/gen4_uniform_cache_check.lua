-- Run:  luajit tools/gen4_uniform_cache_check.lua
--
-- G3 -- THE GEN 4 UNIFORM DEDUP, against a counting stand-in for the shader.
--
-- `Gen4Model:_drawCached` promises two things the unconditional draw does not:
-- a uniform whose value did not change is not uploaded again, and no table is
-- allocated per shape.  Both are checked here on the helpers themselves, with
-- a fake shader that records every `send`, so the check needs no GPU, no ROM
-- and no window.  A third block confirms the only behavioural difference is
-- the number of uploads: whatever reaches the shader is value-identical to
-- what the unconditional path would have sent.

package.path = './?.lua;./?/init.lua;' .. package.path
love = love or require('tests.love_stub')

local PASS, FAIL = 0, 0
local function check(cond, label)
  if cond then PASS = PASS + 1 else FAIL = FAIL + 1; print('FAIL: ' .. label) end
end
local function same(a, b)
  if type(a) ~= 'table' or type(b) ~= 'table' then return a == b end
  if #a ~= #b then return false end
  for i = 1, #a do if a[i] ~= b[i] then return false end end
  return true
end

local Gen4Model = require('src.render.Gen4Model')
local P = assert(Gen4Model._uniformProbe, 'Gen4Model must export its uniform probe')

-- ---------------------------------------------------------- the stand-in
local fake = { sends = 0, log = {} }
function fake:send(name, value)
  self.sends = self.sends + 1
  -- copy, as Shader:send does: a later mutation of a scratch table must not
  -- be visible in what was uploaded
  if type(value) == 'table' then
    local c = {}; for i = 1, #value do c[i] = value[i] end; value = c
  end
  self.log[#self.log + 1] = { name, value }
end
P.bind(fake)

-- ------------------------------------------------------- 1. scalars dedup
P.scalar('yCut', -1e9)
P.scalar('yCut', -1e9)
P.scalar('yCut', -1e9)
check(fake.sends == 1, 'an unchanged scalar is uploaded once, not per draw')
P.scalar('yCut', 40)
check(fake.sends == 2, 'a changed scalar is uploaded again')
check(fake.log[2][2] == 40, 'and carries the new value')

-- -------------------------------------------------------- 2. vectors dedup
fake.sends, fake.log = 0, {}
P.vec('zKeep', 1e9, -1e9)
P.vec('zKeep', 1e9, -1e9)
check(fake.sends == 1, 'an unchanged vec2 is uploaded once')
check(same(fake.log[1][2], { 1e9, -1e9 }), 'vec2 arrives with exactly two components')
P.vec('uvRotScale', 1, 0, 0, 1)
P.vec('uvRotScale', 1, 0, 0, 1)
P.vec('uvRotScale', 0.5, 0, 0, 0.5)
check(fake.sends == 3, 'vec4 identity once, then once more on change')
check(same(fake.log[3][2], { 0.5, 0, 0, 0.5 }), 'vec4 arrives with four components')
P.vec('depthFogC', 0.1, 0.2, 0.3)
check(same(fake.log[4][2], { 0.1, 0.2, 0.3 }), 'vec3 arrives with three components, no trailing slot')
-- the scratch table is reused per name: the fourth component of an earlier
-- vec4 must never leak into a later shorter send under the same name
P.vec('probe', 1, 2, 3, 4)
P.vec('probe', 5, 6)
check(same(fake.log[#fake.log][2], { 5, 6 }), 'a shorter send under a reused name drops stale components')

-- ------------------------------------------------------- 3. matrices dedup
fake.sends, fake.log = 0, {}
local vp = { 1, 0, 0, 0,  0, 1, 0, 0,  0, 0, 1, 0,  0, 0, 0, 1 }
P.matrix('mvp', vp)
P.matrix('mvp', vp)
check(fake.sends == 1, 'the same view-projection for two untransformed shapes uploads once')
local place = { 1, 0, 0, 5,  0, 1, 0, 0,  0, 0, 1, 0,  0, 0, 0, 1 }
local scratch = {}
local viaScratch = P.multiplyInto(scratch, vp, place)
local viaFresh = P.multiply(vp, place)
check(viaScratch == scratch, 'multiplyInto writes into the caller-owned table')
check(same(viaScratch, viaFresh), 'and agrees with the allocating multiply element for element')
P.matrix('mvp', scratch)
check(fake.sends == 2, 'a transformed shape uploads its product')
-- the scratch is overwritten by the next shape; what was uploaded must not
-- change, and the next identical product must still be deduplicated
P.multiplyInto(scratch, vp, place)
P.matrix('mvp', scratch)
check(fake.sends == 2, 'the same product recomputed into the same scratch is not re-uploaded')
check(same(fake.log[2][2], viaFresh), 'the uploaded matrix is the product, not a stale scratch')
P.multiplyInto(scratch, vp, vp)
P.matrix('mvp', scratch)
check(fake.sends == 3, 'a different product is uploaded')

-- ----------------------------------------- 4. the flag and the entry point
local Performance = require('src.core.Performance')
check(Performance.gen4UniformCache == true, 'G3 is on by default')
check(type(Gen4Model._drawCached) == 'function', 'the cached draw body exists')
local src = assert(io.open('src/render/Gen4Model.lua')):read('*a')
check(src:find('if Performance.gen4UniformCache then', 1, true) ~= nil,
      'Gen4Model:draw branches on the flag before the first upload')
check(src:find('shader:send("yCut", tonumber(yCut) or NO_CUT)', 1, true) ~= nil,
      'the unconditional path is still present as the fallback')

-- -------------------------------------------------- 5. shader re-creation
-- a new shader object starts with no remembered values: the first send after
-- a rebind must reach it even if the value equals the last one sent before
local fresh = { sends = 0, log = {} }
fresh.send = fake.send
P.bind(fresh)
P.scalar('yCut', 40)
check(fresh.sends == 1, 'a rebound shader receives the first upload regardless of history')

print(('%d checks, %d failed'):format(PASS + FAIL, FAIL))
if FAIL > 0 then os.exit(1) end
