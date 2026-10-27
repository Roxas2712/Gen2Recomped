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
local core = assert(io.open('src/render/Gen4Unpack.lua')):read('*a')
local renderer = src
src=src..core

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
check(src:find('if count > 0 and (gpuSkin or not shape.matrixSlots) then packedData, packed = packedVertices(count, flags.gen4ByteVertices, FORMAT_FLOATS) end', 1, true) ~= nil,
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

-- Exercise the extracted decoder without any graphics implementation.
if ok then
  local oldLove=love
  love={data={newByteData=function(size)
    local storage=ffi.new('uint8_t[?]',size)
    return {getFFIPointer=function()return storage end,
      getString=function()return ffi.string(storage,size)end}
  end},graphics=setmetatable({}, {__index=function()error('graphics forbidden in unpack')end})}
  local U=require('src.render.Gen4Unpack')
  local function word(n)n=math.floor(n)%65536;return string.char(n%256,math.floor(n/256))end
  local points={{0,0,0},{5,0,0},{5,5,-7},{0,5,-7}}
  local function fixture(stride,slots)
    local bytes={}
    for i,p in ipairs(points)do
      bytes[i]=word(p[1]*4096)..word(p[2]*4096)..word(p[3]*4096)
        ..word((i%2)*16)..word(i*16)..string.char(255,255,255)
        ..(stride==16 and string.char(0,104,73)or string.char(0))
    end
    return {vertices=table.concat(bytes),vertexCount=4,triangleCount=2,
      indices=word(0)..word(1)..word(2)..word(0)..word(2)..word(3),
      matrixSlots=slots,texture='nectgr'}
  end
  local cases=0
  for _,stride in ipairs{14,16}do
    for _,gpuLight in ipairs{false,true}do
      for _,gpuSkin in ipairs{false,true}do
        for _,skin in ipairs{false,true}do
          for _,fog in ipairs{false,true}do
            local shape=fixture(stride,skin and string.char(0,5,0,5)or nil)
            local flags={gen4ByteVertices=false,gen4GpuLight=gpuLight,gen4GpuSkin=gpuSkin}
            local opts={shape=shape,billboard=true,capBack=true,tileUnits=16,
              posScale=1/3,textureWidth=32,textureHeight=64,hasImage=true,
              shade=function()return .25,.5,.75 end,flags=flags,
              fog=fog and {.2,.3,.4}or nil}
            local tables=U.unpack(shape.vertices,opts)
            flags.gen4ByteVertices=true
            local bytes=U.unpack(shape.vertices,opts)
            local expected=ffi.new('float[?]',4*16)
            for i,v in ipairs(tables.vertices)do
              for j=1,16 do expected[(i-1)*16+j-1]=v[j]end
            end
            if bytes.packedData then
              check(bytes.packedData:getString()==ffi.string(expected,4*16*4),
                'packed/table byte equality case '..cases)
            else
              check(skin and not gpuSkin and #bytes.vertices==4,'CPU skin preserves table vertices')
            end
            for axis=1,3 do
              check(tables.lo[axis]==bytes.lo[axis] and tables.hi[axis]==bytes.hi[axis],
                'double precision bounds stay identical')
            end
            check(bytes.stride==stride,'legacy/current stride is measured')
            check(bytes.grassPending and bytes.grassPending.shape==shape,'grass retains live shape identity')
            check(bytes.positions[4][1]==0 and bytes.positions[4][2]==5*(1/3),'classification retains double positions')
            cases=cases+1
          end
        end
      end
    end
  end
  local shape=fixture(16)
  local calls=0
  local opts={shape=shape,flags={gen4ByteVertices=true},shade=function()
    calls=calls+1
    if calls==1 then
      shape.vertices=shape.vertices:sub(1,16)..word(4096)..shape.vertices:sub(19)
      shape.noFog=true
    end
    return .5,.5,.5
  end,fog={1,0,0}}
  local originalBytes=shape.vertices
  local decoded=U.unpack(shape.vertices,opts)
  check(calls==4,'custom shading callback still runs once per lit vertex')
  check(decoded.packed[16]==1,'callback edits to later vertex bytes remain live')
  check(decoded.packed[5]==.5 and decoded.packed[6]==.5,'callback noFog edit applies to the current vertex')
  check(opts.shape==shape and shape.vertices~=originalBytes,'decoder preserves caller identity and callback edits')
  check(renderer:find('Gen4Model.unpack(shape.vertices,',1,true)~=nil,'new uses the extracted decoder')
  love=oldLove
end

print(('%d checks, %d failed'):format(PASS + FAIL, FAIL))
if FAIL > 0 then os.exit(1) end
