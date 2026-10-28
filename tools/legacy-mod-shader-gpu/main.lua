-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Actual API-boundary compilation and pixels; no ROM, game or private mod.
io.stdout:setvbuf('no')
function love.errorhandler(e)io.stderr:write(debug.traceback(tostring(e),2)..'\n');return function()return 1 end end
local root=assert(os.getenv('NATIVE_BALL_ENGINE'))
package.path=root..'/?.lua;'..root..'/?/init.lua;'..package.path
local ran=false
function love.draw()
 if ran then return end;ran=true
 local g=love.graphics;local nativeCompiler=g.newShader
 local checks,frames=0,0
 local function check(ok,why)checks=checks+1;assert(ok,why)end
 check(love.filesystem.getIdentity():match('^oasc%-gen2recomp%-qa%-'),'owned GPU identity')
 check(g.getRendererInfo():lower():find(os.getenv('POKEPORT_GRAPHICS_BACKEND'),1,true),'requested actual backend')
 local T=require('tests.modkit');local Clip=require('src.render.ClipSpaceCompat')
 local pixel='vec4 effect(vec4 c,Image t,vec2 uv,vec2 p){return c;}'
 local manual='uniform mat4 vp;vec4 position(mat4 transform_projection,vec4 p){return vp*p;}'
 local standard='vec4 position(mat4 transform_projection,vec4 p){return transform_projection*p;}'
 local marked=Clip.shader(manual)
 local rawNative=nativeCompiler(pixel,manual)
 local identity={1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1}
 local rectangles={{2,3,9,7,{1,0,0,1}},{19,21,8,5,{0,0,1,1}}}
 local function mesh(mode)
  local vertices={}
  for _,r in ipairs(rectangles)do
   local points={{r[1],r[2]},{r[1]+r[3],r[2]},{r[1]+r[3],r[2]+r[4]},
    {r[1],r[2]},{r[1]+r[3],r[2]+r[4]},{r[1],r[2]+r[4]}}
   for _,p in ipairs(points)do
    local x,y=p[1],p[2]
    if mode~='pixel'then x,y=x/16-1,y/16-1;if mode=='up'then y=-y end end
    vertices[#vertices+1]={x,y,0,0,r[5][1],r[5][2],r[5][3],r[5][4]}
   end
  end
  return g.newMesh(vertices,'triangles','static')
 end
 local meshes={down=mesh('down'),up=mesh('up'),pixel=mesh('pixel')}
 local function render(canvas,shader,geometry)
  local original=g.getCanvas();g.push('all');g.setCanvas(canvas);g.origin();g.setScissor()
  g.clear(0,0,0,0);g.setColor(1,1,1,1);g.setBlendMode('replace');g.setShader(shader)
  if shader and shader:hasUniform('vp')then shader:send('vp',identity)end
  if geometry then g.draw(geometry)else
   for _,r in ipairs(rectangles)do g.setColor(r[5]);g.rectangle('fill',r[1],r[2],r[3],r[4])end
  end
  g.setCanvas(original);g.pop();frames=frames+1
  local data=g.readbackTexture(canvas);local bytes=data:getString();data:release();return bytes
 end
 for _,api in ipairs{1,2,3}do
  local source=('local mod=...;mod.exports.raw=love.graphics.newShader(%q,%q);'
   ..'mod.exports.marked=love.graphics.newShader(%q,%q);'
   ..'mod.exports.standard=love.graphics.newShader(%q,%q)'):format(pixel,manual,pixel,marked,pixel,standard)
  local run=T.sdk.loadMods({'mods/clip_probe'},{fs=T.sdk.memfs({
   ['mods/clip_probe/manifest.json']=('{"id":"clip_probe","name":"Clip pixels","version":"1.0.0","api":%d,"entry":"main.lua","affects_link":false}'):format(api),
   ['mods/clip_probe/main.lua']=source,
  })})
  check(#run.errors==0,'real mod shader compilation API '..api)
  local shaders=assert(run.loader.exports.clip_probe)
  for _,dpi in ipairs{1,2}do
   local actual=g.newCanvas(32,32,{format='rgba8',dpiscale=dpi,msaa=0})
   local expected=g.newCanvas(32,32,{format='rgba8',dpiscale=dpi,msaa=0})
   local reference=render(expected)
   check(render(actual,shaders.standard,meshes.pixel)==reference,'standard 2D pixels API '..api..' DPI '..dpi)
   check(render(actual,shaders.marked,meshes.up)==reference,'explicit native clip is not normalized twice API '..api..' DPI '..dpi)
   if api<3 then
    check(render(actual,shaders.raw,meshes.down)==reference,'legacy canvas clip reaches upright native pixels API '..api..' DPI '..dpi)
   else
    local untouched=render(expected,rawNative,meshes.up)
    check(render(actual,shaders.raw,meshes.up)==untouched,'API 3 custom clip remains unchanged DPI '..dpi)
   end
   actual:release();expected:release()
  end
  g.setShader();run.release()
 end
 require('src.mods.LegacyShaderCompat').reset();rawNative:release()
 for _,m in pairs(meshes)do m:release()end
 print('LEGACY_MOD_SHADER_GPU_OK',checks,frames);love.event.quit(0)
end
