-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Real loader/compiler, canvas and backbuffer pixels; no ROM or private mod.
io.stdout:setvbuf('no')
function love.errorhandler(e)io.stderr:write(debug.traceback(tostring(e),2)..'\n');return function()return 1 end end
local root=assert(os.getenv('NATIVE_BALL_ENGINE'))
package.path=root..'/?.lua;'..root..'/?/init.lua;'..package.path
local ready,capturing,finished=false,false,false
local checks,frames=0,0
local jobs,runs,resources={}, {}, {}
local index,phase,reference=1,'reference',nil
local g,windowMesh,windowPixels,scratch,render,paint
local function check(ok,why)checks=checks+1;assert(ok,why)end
local function keep(value)resources[#resources+1]=value;return value end
local function setup()
 g=love.graphics
 check(love.filesystem.getIdentity():match('^oasc%-gen2recomp%-qa%-'),'owned GPU identity')
 check(g.getRendererInfo():lower():find(os.getenv('POKEPORT_GRAPHICS_BACKEND'),1,true),'actual requested backend')
 local rawCompiler=g.newShader
 -- main.lua installs this before loading any mod. Preserve that actual
 -- engine boundary instead of testing an uninstalled graphics subsystem.
 require('src.render.LegacyShaderCompat').install()
 local precedingCompiler=g.newShader
 local T=require('tests.modkit');local Clip=require('src.render.ClipSpaceCompat')
 local pixel='vec4 effect(vec4 c,Image t,vec2 uv,vec2 p){return c;}'
 local manual='uniform mat4 vp;vec4 position(mat4 transform_projection,vec4 p){return vp*p;}'
 local standard='vec4 position(mat4 transform_projection,vec4 p){return transform_projection*p;}'
 local marked=Clip.shader(manual)
 local rawNative=keep(rawCompiler(pixel,manual))
 local markedNative=keep(rawCompiler(pixel,marked))
 local preceding=keep(precedingCompiler(pixel,manual))
 local identity={1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1}
 local rectangles={{2,3,9,7,{1,0,0,1}},{19,21,8,5,{0,0,1,1}}}
 local function mesh(mode,width,height)
  width,height=width or 32,height or 32
  local vertices={}
  for _,r in ipairs(rectangles)do
   for _,p in ipairs{{r[1],r[2]},{r[1]+r[3],r[2]},{r[1]+r[3],r[2]+r[4]},
    {r[1],r[2]},{r[1]+r[3],r[2]+r[4]},{r[1],r[2]+r[4]}}do
    local x,y=p[1],p[2]
    if mode~='pixel'then x,y=x/(width/2)-1,y/(height/2)-1;if mode=='up'then y=-y end end
    vertices[#vertices+1]={x,y,0,0,r[5][1],r[5][2],r[5][3],r[5][4]}
   end
  end
  return keep(g.newMesh(vertices,'triangles','static'))
 end
 local meshes={down=mesh('down'),up=mesh('up'),pixel=mesh('pixel')}
 local width,height=g.getDimensions();windowMesh=mesh('up',width,height);windowPixels=mesh('pixel',width,height)
 scratch=keep(g.newCanvas(32,32,{format='rgba8',msaa=0}))
 paint=function(shader,geometry)
  g.setColor(1,1,1,1);g.setBlendMode('replace');g.setShader(shader)
  if shader and shader:hasUniform('vp')then shader:send('vp',identity)end
  if geometry then g.draw(geometry)else
   for _,r in ipairs(rectangles)do g.setColor(r[5]);g.rectangle('fill',r[1],r[2],r[3],r[4])end
  end
 end
 render=function(canvas,shader,geometry)
  local original=g.getCanvas();g.push('all');g.setCanvas(canvas);g.origin();g.setScissor();g.clear(0,0,0,1)
  paint(shader,geometry);g.setCanvas(original);g.pop();frames=frames+1
  local data=g.readbackTexture(canvas);local bytes=data:getString();data:release();return bytes
 end
 for _,api in ipairs{1,2,3}do
  local code=('local mod=...;mod.exports.raw=love.graphics.newShader(%q,%q);'
   ..'mod.exports.marked=love.graphics.newShader(%q,%q);'
   ..'mod.exports.standard=love.graphics.newShader(%q,%q);'
   ..'mod.exports.options=love.graphics.newShader(%q,%q,{defines={POKEPORT_NATIVE_CLIP_SPACE=1}})')
   :format(pixel,manual,pixel,marked,pixel,standard,pixel,manual)
  local run=T.sdk.loadMods({'mods/clip_probe'},{fs=T.sdk.memfs({
   ['mods/clip_probe/manifest.json']=('{"id":"clip_probe","name":"Clip pixels","version":"1.0.0","api":%d,"entry":"main.lua","affects_link":false}'):format(api),
   ['mods/clip_probe/main.lua']=code,
  })})
  runs[#runs+1]=run;check(#run.errors==0,'real mod shader compilation API '..api)
  local shaders=assert(run.loader.exports.clip_probe)
  for _,dpi in ipairs{1,2}do
   local actual=g.newCanvas(32,32,{format='rgba8',dpiscale=dpi,msaa=0})
   local expected=g.newCanvas(32,32,{format='rgba8',dpiscale=dpi,msaa=0})
   local stock=render(expected)
   check(render(actual,shaders.standard,meshes.pixel)==stock,'standard 2D canvas API '..api..' DPI '..dpi)
   check(render(actual,shaders.marked,meshes.up)==render(expected,markedNative,meshes.up),
    'explicit native canvas contract preserved API '..api..' DPI '..dpi)
   if api<3 then
    check(render(actual,shaders.raw,meshes.down)==stock,'old canvas projection upright API '..api..' DPI '..dpi)
   else
    check(render(actual,shaders.raw,meshes.up)==render(expected,preceding,meshes.up),
     'API 3 canvas retains preceding engine contract DPI '..dpi)
   end
   actual:release();expected:release()
  end
  local function job(name,shader,geometry,baseline,baselineGeometry,optionCanvas)
   jobs[#jobs+1]={name=name..' API '..api,shader=shader,geometry=geometry,
    baseline=baseline,baselineGeometry=baselineGeometry,optionCanvas=optionCanvas}
  end
  job('standard backbuffer',shaders.standard,windowPixels)
  job('native-marked backbuffer',shaders.marked,windowMesh,markedNative,windowMesh)
  job('custom backbuffer',shaders.raw,windowMesh,api==3 and preceding or nil,api==3 and windowMesh or nil)
  job('native compiler-option backbuffer',shaders.options,windowMesh,rawNative,windowMesh,
   function()check(render(scratch,shaders.options,meshes.up)==render(scratch,rawNative,meshes.up),
    'native compiler option bypasses legacy canvas adaptation API '..api)end)
 end
end
function love.draw()
 if finished or capturing then return end
 if not ready then setup();ready=true end
 local job=assert(jobs[index]);g.setCanvas();g.origin();g.setScissor();g.clear(0,0,0,1)
 if phase=='reference'then
  if job.optionCanvas then job.optionCanvas();g.setCanvas();g.origin();g.setScissor();g.clear(0,0,0,1)end
  paint(job.baseline,job.baselineGeometry)
 else
  g.setShader(job.shader)
  -- Enter and leave two real targets before drawing the same program into
  -- the window. The shared graphics owner must restore the target factor.
  g.push('all');g.setCanvas(scratch);g.push('all');g.setCanvas();g.setShader();g.pop();g.pop()
  check(g.getCanvas()==nil and g.getShader()==job.shader,'nested target restoration '..job.name)
  paint(job.shader,job.geometry)
 end
 g.setShader();frames=frames+1;capturing=true
 g.captureScreenshot(function(data)
  local pixels=data:getString();data:release()
  if phase=='reference'then reference=pixels;phase='actual'
  else
   check(pixels==reference,'actual backbuffer pixels '..job.name);index=index+1;phase='reference'
  end
  capturing=false
  if index>#jobs then
   finished=true;g.setCanvas();g.setShader()
   for _,run in ipairs(runs)do run.release()end
   for _,resource in ipairs(resources)do resource:release()end
   print('LEGACY_MOD_SHADER_GPU_OK',checks,frames);love.event.quit(0)
  end
 end)
end
