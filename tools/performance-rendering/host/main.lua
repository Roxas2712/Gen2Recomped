-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
io.stdout:setvbuf('no')
local root=assert(os.getenv('BATTLE_SOURCE_ENGINE'))
package.path=root..'/?.lua;'..root..'/?/init.lua;'..package.path
function love.errorhandler(err)io.stderr:write(debug.traceback(tostring(err),2)..'\n');return function()return 1 end end
function love.load()
 local g=love.graphics;local checks,comparisons,maxDelta=0,0,0
 local function check(v,why)checks=checks+1;assert(v,why)end
 local P=require('src.core.Performance');local M=require('src.render.Gen4Model');local Shade=require('src.render.Gen4Shade')
 local I={1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1}
 local function word(n)n=math.floor(n)%65536;return string.char(n%256,math.floor(n/256))end
 local points={{-.75,-.7,0},{.7,-.65,0},{-.15,.75,0}}
 local function record(shade,skinned)
  local rows={}
  for i,p in ipairs(points)do
   local n=({{127,0,0},{0,127,0},{0,0,127}})[i]
   rows[i]=word(p[1]*4096)..word(p[2]*4096)..word(0)..word(0)..word(0)..string.char(255,255,255,n[1],n[2],n[3])
  end
  return{name='owned_triangle',shade=shade,shapes={{index=1,name='triangle',vertices=table.concat(rows),vertexCount=3,triangleCount=1,indices=word(0)..word(1)..word(2),matrixSlots=skinned and string.char(0,0,0)or nil}}}
 end
 local templates={{lights={{unit={.4,-.8,.2},colour={31,22,13}}},ambient={8,11,5},diffuse={23,20,26}},
 {lights={{unit={-.6,-.3,.4},colour={17,9,31}}},ambient={4,6,12},diffuse={27,25,19}}}
 local canvas,depth=M.newTarget(96,96);check(canvas and depth,'real Gen4 target and depth canvas')
 local function frame(model,template,cached,matrix)
  P.gen4UniformCache=cached;M.light=template
  g.push('all');g.setCanvas({canvas,depthstencil=depth});g.origin();g.setShader();g.setColor(1,1,1,1);g.clear(0,0,0,0,0,1)
  check(model:draw(matrix or I),'actual Gen4 mesh draw');g.setCanvas();g.pop()
  local data=g.readbackTexture(canvas);local bytes=data:getString();data:release();return bytes
 end
 local function compare(a,b,why,tolerance)
  check(#a==#b,why..' byte count');local diff=0;local painted=0
  for i=1,#a do diff=math.max(diff,math.abs(a:byte(i)-b:byte(i)));if i%4==0 and a:byte(i)>0 then painted=painted+1 end end
  maxDelta=math.max(maxDelta,diff);comparisons=comparisons+1
  check(painted>100,why..' nonempty triangle');check(diff<=(tolerance or 0),why..' pixels differ by '..diff)
 end
 local models={}
 for _,template in ipairs(templates)do
  local shade=Shade.forTemplate(template)
  P.gen4GpuLight=false;P.gen4ByteVertices=false
  local cpu=assert(M.new(record(shade)));models[#models+1]=cpu
  local baseline=frame(cpu,nil,false)
  P.gen4GpuLight=true
  for _,packed in ipairs{false,true}do
   P.gen4ByteVertices=packed
   local newMesh=g.newMesh;local usedData
   g.newMesh=function(fmt,vertices,...)usedData=type(vertices)=='userdata'and vertices:typeOf('ByteData');return newMesh(fmt,vertices,...)end
   local ok,model=pcall(M.new,record(shade));g.newMesh=newMesh;check(ok and model,'actual packed/table mesh construction');models[#models+1]=model
   check((usedData==true)==packed,'selected actual vertex allocation path')
   check(model.shapes[1].mesh:getVertexCount()==3,'packed vertex count')
   compare(frame(model,template,false),baseline,'GPU light vs CPU vertex light',1)
   compare(frame(model,template,true),baseline,'cached uniforms vs unconditional draw',1)
   -- A temporary fallback draw must not leave cached values describing an
   -- older shader state when the optimized path is enabled again.
   local cut={unpack(I)};cut[4]=.25
   local moved=frame(model,template,false,cut)
   compare(frame(model,template,true),baseline,'uniform cache re-entry after fallback draw',1)
  end
 end
 P.gen4ByteVertices=true;P.gen4GpuLight=true
 P.gen4GpuSkin=false
 local skinned=assert(M.new(record(Shade.forTemplate(templates[1]),true)));models[#models+1]=skinned
 check(skinned.shapes[1].bindVertices and #skinned.shapes[1].bindVertices==3,'CPU-skinned shape retains table vertices')
 check(skinned.shapes[1].gpuSkin==nil,'CPU-skinned shape carries no joint palette')
 P.gen4GpuSkin=true
 local gpuSkinned=assert(M.new(record(Shade.forTemplate(templates[1]),true)));models[#models+1]=gpuSkinned
 check(gpuSkinned.shapes[1].gpuSkin and #gpuSkinned.shapes[1].gpuSkin.slots==1 and gpuSkinned.shapes[1].gpuSkin.slots[1]==0,'GPU-skinned shape maps its one slot to joint 0')
 check(gpuSkinned.shapes[1].bindVertices==nil,'GPU-skinned shape keeps no table vertices')
 local pose=gpuSkinned:restPose();local palette=(pose.stacks and pose.stacks[1])or pose.stack
 check(gpuSkinned:draw({1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1},pose)==true,'GPU-skinned shape draws through the joint palette')
 check(M.cutsHeight(),'full native height-cut shader compiled')
 local V={};local libs={}
 V.require=function(name)
  if libs[name]then return libs[name]end
  local value=assert(loadfile(root..'/mods/DRAMATIC_SHAPE/lib/'..name..'.lua'))(V);libs[name]=value;return value
 end
 local voxel=V.require('Voxel3D');local variants={}
 for _,tier in ipairs{'high','balanced','low'}do
  P.tier=tier
  for _,stamp in ipairs{false,true}do
   local sh=voxel.shader(false,stamp);check(sh~=nil,'actual '..tier..' shadow shader '..tostring(stamp));variants[tier..tostring(stamp)]=sh
  end
 end
 check(variants.highfalse~=variants.balancedfalse,'tier change selects a separate shader variant')
 check(variants.balancedfalse==variants.lowfalse,'one-tap tiers share their compiled variant')
 for _,m in ipairs(models)do for _,s in ipairs(m.shapes)do s.mesh:release()end end
 canvas:release();depth:release()
 local renderer,version,vendor,device=g.getRendererInfo()
 local report={passed=true,checks=checks,comparisons=comparisons,maxByteDelta=maxDelta,backend=os.getenv('POKEPORT_GRAPHICS_BACKEND'),renderer=renderer,version=version,vendor=vendor,device=device,syntheticGeometry=true,physicalHandheld=false,playerProfilesUsed=false}
 local f=assert(io.open(assert(os.getenv('BATTLE_SOURCE_REPORT')),'w'));f:write(require('src.link.Json').encode(report));f:close()
 print('PERF_NATIVE_GPU_PASS '..checks..' checks, '..comparisons..' comparisons');love.event.quit(0)
end
