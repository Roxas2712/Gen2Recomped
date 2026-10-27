-- Compare native Twinleaf uploads with an immutable pre-extraction renderer.
return function(game)
  local U=require('tests.drivers.util')
  local M=require('src.render.Gen4Model')
  local P=require('src.core.Performance')
  local Ref=assert(loadfile(assert(os.getenv('GEN4_UNPACK_REFERENCE'))))()
  local ffi=require('ffi')
  assert(require('src.core.GameVersion').get()=='platinum')
  assert(love.filesystem.getIdentity():match('^oasc%-gen2recomp%-qa%-perf%-unpack%-'))
  U.freshSave(game)
  game.save.gen4Vars={[0x4086]=2,[0x40A4]=4}
  game.save.flags.FLAG_G4_00EA=true
  U.teleport(game,'T01',15,10,'up');U.wait(30)
  local ow=assert(game.overworld)
  assert(ow.map.def.sourceId=='T01' or ow.map.id=='T01' or ow.map.def.header==411)
  local ground=assert(ow.map.renderer.gen4Ground,'native Twinleaf ground required')
  local function bytes(data)
    if type(data)=='userdata' then return data:getString() end
    local raw=ffi.new('float[?]',#data*16)
    for i,row in ipairs(data)do for j=1,16 do raw[(i-1)*16+j-1]=row[j]end end
    return ffi.string(raw,#data*16*4)
  end
  local function construct(module,record)
    local newMesh=love.graphics.newMesh
    local uploads={}
    love.graphics.newMesh=function(format,data,...)
      uploads[#uploads+1]=bytes(data)
      return newMesh(format,data,...)
    end
    local ok,model=pcall(module.new,record)
    love.graphics.newMesh=newMesh
    assert(ok,model);assert(model,'native model did not build')
    return model,uploads
  end
  local function equal(a,b)
    if type(a)~='table' then return a==b end
    if type(b)~='table' then return false end
    for k,v in pairs(a)do if not equal(v,b[k]) then return false end end
    for k in pairs(b)do if a[k]==nil then return false end end
    return true
  end
  local chunks,shapes,comparisons,totalBytes=0,0,0,0
  local seen={};local digests={}
  for _,land in ipairs(ground.grid.land)do
    if ground.terrain.chunks[land] and not seen[land] then
      seen[land]=true
      local original=M.new
      M.new=function(record)return record end
      local ok,record=pcall(ground.modelFor,ground,land)
      M.new=original
      assert(ok,record);assert(record)
      chunks=chunks+1;shapes=shapes+#record.shapes
      for _,packed in ipairs{false,true}do
        for _,light in ipairs{false,true}do
          P.gen4ByteVertices,P.gen4GpuLight=packed,light
          local before,old=construct(Ref,record)
          local after,new=construct(M,record)
          assert(#old==#new,'mesh upload count changed')
          assert(#before.shapes==#after.shapes and before.cards==after.cards,'shape/card count changed')
          for i,stream in ipairs(old)do
            assert(stream==new[i],'vertex bytes changed in native chunk '..land..' upload '..i)
            comparisons=comparisons+1;totalBytes=totalBytes+#stream
            digests[#digests+1]=love.data.encode('string','hex',love.data.hash('sha256',stream))
          end
          for i,a in ipairs(before.shapes)do
            local b=after.shapes[i]
            for _,key in ipairs{'lo','hi','bindVertices','gpuSkin','name','material','index','alpha'}do
              assert(equal(a[key],b[key]),'native model field changed: '..key)
            end
          end
          for _,model in ipairs{before,after}do
            for _,shape in ipairs(model.shapes)do shape.mesh:release()end
          end
        end
      end
    end
  end
  assert(chunks>0 and shapes>0 and comparisons>0,'empty Twinleaf comparison')
  local report={passed=true,chunks=chunks,shapes=shapes,uploadComparisons=comparisons,
    bytesCompared=totalBytes,uploadSha256=digests,byteDifference=0,
    sourceMap=ow.map.id,sourceHeader=411,playerProfilesUsed=false,
    renderer=love.graphics.getRendererInfo()}
  local f=assert(io.open(assert(os.getenv('GEN4_UNPACK_OUT')),'w'))
  f:write(require('src.link.Json').encode(report));f:close()
  print('GEN4_UNPACK_PASS '..comparisons..' native uploads, zero byte differences')
  love.event.quit(0)
end
