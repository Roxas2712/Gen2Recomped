-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Final native compositor pixels and real depth-buffer cutouts. No ROM/mod assets.
io.stdout:setvbuf('no')
function love.errorhandler(e)io.stderr:write(debug.traceback(tostring(e),2)..'\n');return function()return 1 end end
local root=assert(os.getenv('ALPHA_ENGINE'))
package.path=root..'/?.lua;'..root..'/?/init.lua;'..package.path
local g=love.graphics
local P,R,S,actor,texture,quad,canvas,shader,mesh,opaque
local captured=false
local grass
local out=assert(os.getenv('ALPHA_OUT'))
local function save(name,bytes)local f=assert(io.open(out..'/'..name,'wb'));f:write(bytes);f:close()end
function love.load()
 g.setDefaultFilter('nearest','nearest')
 require('src.render.GraphicsStack').install()
 require('src.render.LegacyShaderCompat').install()
 require('src.render.ShaderSpecialization').install()
 require('src.core.GameVersion').set(os.getenv('ALPHA_VERSION') or 'red')
 P=require('src.render.PaletteFX');P.setMode('sgb')
 R=require('src.render.Renderer');R:init()
 local data=love.image.newImageData(16,96)
 for y=0,95 do for x=0,15 do data:setPixel(x,y,1,.1,.2,(x>=6 and x<10) and 1 or 0)end end
 texture=g.newImage(data)
 require('src.render.Assets').image=function()return texture end
 local blade=love.image.newImageData(8,8)
 for y=0,7 do for x=0,7 do local v=y>=5 and .66 or 1;blade:setPixel(x,y,v,v,v,1)end end
 grass=setmetatable({image=g.newImage(blade),quads={[0]=g.newQuad(0,0,8,8,8,8)},map={tileAt=function()return 0 end}}, {__index=require('src.render.TileRenderer')})
 S=require('src.render.SpriteRenderer')
 actor=S.new({id='RGBA_PROBE',image='probe',frames=6,walker=true,trueColor=true})
 canvas=g.newCanvas(32,32,{format='rgba8',dpiscale=1,msaa=0})
 shader=g.newShader([[
 #ifdef VERTEX
 vec4 position(mat4 transform_projection,vec4 p){return transform_projection*p;}
 #endif
 #ifdef PIXEL
 vec4 effect(vec4 c,Image t,vec2 uv,vec2 sc){vec4 p=Texel(t,uv);if(p.a<0.5)discard;return p*c;}
 #endif
 ]])
 local fmt={{'VertexPosition','float',3},{'VertexTexCoord','float',2},{'VertexColor','byte',4}}
 mesh=g.newMesh(fmt,{{0,0,.5,0,0,255,255,255,255},{32,0,.5,1,0,255,255,255,255},{32,32,.5,1,1/6,255,255,255,255},{0,32,.5,0,1/6,255,255,255,255}},'fan','static');mesh:setTexture(texture)
 opaque=g.newMesh(fmt,{{0,0,-.5,0,0,0,255,0,255},{32,0,-.5,0,0,0,255,0,255},{32,32,-.5,0,0,0,255,0,255},{0,32,-.5,0,0,0,255,0,255}},'fan','static')
end
function love.draw()
 if captured then return end
 require('src.render.GraphicsStack').drain()
 R:beginFrame(true);R:beginWorldPass()
 g.setColor(.33,.33,.33,1);g.rectangle('fill',0,0,160,144);g.setColor(1,1,1,1)
 actor:draw(20,24,0,0,'down',0,false)
 local palette={{255,255,255},{0,0,255},{0,255,0},{0,0,0}}
 grass:drawCellBottom(1,1,0,0)
 if P.spriteRedraws()[1]then grass:markCellBottomRedraw(1,1,0,0,palette)end
 R:endWorldPass()
 R:endFrame(nil,{{x=0,y=0,w=160,h=144,colors=palette}})
 g.captureScreenshot(function(image)
  save('world.png',image:encode('png'):getString())
  local r,a,b=image:getPixel(21,21);local cr,cg,cb=image:getPixel(18,21)
  local ar,ag,ab=image:getPixel(27,21)
  local same=math.abs(r-cr)+math.abs(a-cg)+math.abs(b-cb)<.02
  local authored=ar>.95 and ag<.2 and ab<.3
  local fr,fg,fb=image:getPixel(27,30);local foreground=fb>.95 and fr<.05 and fg<.05
  -- Draw the same cutout before foliage into a real persistent depth target.
  g.push('all');g.setCanvas({canvas,depth=true});g.origin();g.setScissor();g.clear(0,0,0,1,true,true)
  g.setDepthMode('less',true);g.setShader(shader);g.setColor(1,1,1,1);g.draw(mesh)
  g.setShader();g.draw(opaque);g.setDepthMode();g.setCanvas();g.pop()
  local depth=g.readbackTexture(canvas);save('depth.png',depth:encode('png'):getString())
  local dr,dg,db=depth:getPixel(2,2);local br,bg,bb=depth:getPixel(15,2)
  local cutout=dg>.95 and dr<.05 and db<.05
  local body=br>.95 and bg<.2 and bb<.3
  local result={renderer={g.getRendererInfo()},version=os.getenv('ALPHA_VERSION')or'red',transparentBackground=same,authoredColor=authored,foregroundGrass=foreground,depthCutout=cutout,depthBody=body,background={r,a,b},control={cr,cg,cb}}
  save('report.json',require('src.link.Json').encode(result))
  print('ALPHA_PIXELS',require('src.link.Json').encode(result))
  love.event.quit(same and authored and foreground and cutout and body and 0 or 1)
 end)
 captured=true
end
