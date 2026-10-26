-- Run:  luajit tools/gen4_packed_vertices_check.lua
--
-- G1 -- GEN 4 VERTICES AS ONE BUFFER.  The buffer layout must be exactly the
-- FORMAT newMesh is handed (sixteen floats a vertex, in attribute order), the
-- card pivots must land in the same slots the table path writes them to,
-- and a shape a joint animation re-poses on the CPU must keep its tables.
package.path = './?.lua;./?/init.lua;' .. package.path
local PASS, FAIL = 0, 0
local function check(cond, label)
  if cond then PASS = PASS + 1 else FAIL = FAIL + 1; print('FAIL: ' .. label) end
end
local src = assert(io.open('src/render/Gen4Model.lua')):read('*a')

-- the format, counted the way the module counts it
local fmt = src:match('local FORMAT = {(.-)\n}')
local floats = 0
for n in fmt:gmatch('"float", (%d+)') do floats = floats + tonumber(n) end
check(floats == 16, 'FORMAT is sixteen floats a vertex (' .. floats .. ')')
check(src:find('for _, attr in ipairs(FORMAT) do FORMAT_FLOATS = FORMAT_FLOATS + attr[3] end', 1, true) ~= nil,
      'the stride is derived from FORMAT, not written down twice')

-- attribute order in FORMAT: position(3) texcoord(2) color(4) pivot(3) normal(3)
local order = {}
for name in fmt:gmatch('{ "([%w]+)", "float", %d+ }') do order[#order + 1] = name end
check(table.concat(order, ',') == 'VertexPosition,VertexTexCoord,VertexColor,BillboardPivot,LitNormal,JointSlot',
      'attribute order is position, texcoord, colour, pivot, normal, joint (' .. table.concat(order, ',') .. ')')
-- ...and the packed write follows it slot for slot
check(src:find('packed[o], packed[o + 1], packed[o + 2] = x, y, z', 1, true) ~= nil, 'slots 0-2 position')
check(src:find('packed[o + 3], packed[o + 4] = u, v', 1, true) ~= nil, 'slots 3-4 texcoord')
check(src:find('packed[o + 5], packed[o + 6], packed[o + 7], packed[o + 8] = r / 255, g / 255, b / 255, 1', 1, true) ~= nil, 'slots 5-8 colour')
check(src:find('packed[o + 9], packed[o + 10], packed[o + 11] = 0, 0, 0', 1, true) ~= nil, 'slots 9-11 pivot, cleared')
check(src:find('packed[o + 12], packed[o + 13], packed[o + 14] = lnx, lny, lnz', 1, true) ~= nil, 'slots 12-14 normal')
check(src:find('packed[o + 15] = joint', 1, true) ~= nil, 'slot 15 joint')
check(src:find('packed[o + 9], packed[o + 10], packed[o + 11] = pv[1], pv[2], pv[3]', 1, true) ~= nil,
      'card pivots are written into slots 9-11, where the table path puts v[10..12]')
check(src:find('v[10], v[11], v[12] = pv[1], pv[2], pv[3]', 1, true) ~= nil, 'the table path still writes them')
check(src:find('if count > 0 and (gpuSkin or not shape.matrixSlots) then packedData, packed = packedVertices(count) end', 1, true) ~= nil,
      'a CPU-skinned shape keeps its tables; a GPU-skinned one takes the buffer')
check(src:find('pcall(love.graphics.newMesh, FORMAT, packed and packedData or vertices, "triangles", "static")', 1, true) ~= nil,
      'newMesh takes the buffer when there is one')
check(src:find('bindVertices=(shape.matrixSlots and not gpuSkin) and vertices or nil', 1, true) ~= nil, 'bindVertices still comes from the tables, only for CPU-skinned shapes')
local Performance = require('src.core.Performance')
check(Performance.gen4ByteVertices == true, 'G1 is on by default')

-- the FFI write itself, on a stand-in buffer
local ok, ffi = pcall(require, 'ffi')
if ok then
  local count = 3
  local buf = ffi.new('float[?]', count * 16)
  for i = 0, count - 1 do
    local o = i * 16
    buf[o], buf[o + 1], buf[o + 2] = i, i * 2, i * 3
    buf[o + 3], buf[o + 4] = 0.25, 0.5
    buf[o + 5], buf[o + 6], buf[o + 7], buf[o + 8] = 1, 0.5, 0, 1
    buf[o + 9], buf[o + 10], buf[o + 11] = 0, 0, 0
    buf[o + 12], buf[o + 13], buf[o + 14] = 0, 1, 0
    buf[o + 15] = i
  end
  local o = 1 * 16
  buf[o + 9], buf[o + 10], buf[o + 11] = 7, 8, 1
  check(buf[16] == 1 and buf[17] == 2 and buf[18] == 3, 'vertex 1 position at float offset 16')
  check(buf[25] == 7 and buf[26] == 8 and buf[27] == 1, 'vertex 1 pivot at float offsets 25-27')
  check(buf[28] == 0 and buf[29] == 1 and buf[30] == 0, 'vertex 1 normal at float offsets 28-30')
  check(buf[31] == 1, 'vertex 1 joint at float offset 31')
  check(buf[32] == 2, 'vertex 2 begins at float offset 32')
end

print(('%d checks, %d failed'):format(PASS + FAIL, FAIL))
if FAIL > 0 then os.exit(1) end
