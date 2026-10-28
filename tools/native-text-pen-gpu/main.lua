-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
io.stdout:setvbuf('no')
function love.errorhandler(e)io.stderr:write(debug.traceback(tostring(e),2)..'\n');return function()return 1 end end
local root=assert(os.getenv('NATIVE_BALL_ENGINE'))
package.path=root..'/?.lua;'..root..'/?/init.lua;'..package.path
local ran=false
function love.draw()
 if ran then return end;ran=true
 local g=love.graphics;local checks,frames=0,0
 local function check(ok,why)checks=checks+1;assert(ok,why)end
 check(love.filesystem.getIdentity():match('^oasc%-gen2recomp%-qa%-'),'own profile')
 check(g.getRendererInfo():lower():find(os.getenv('POKEPORT_GRAPHICS_BACKEND'),1,true),'requested backend')
 local Font=require('src.render.Font');local F=require('src.ui.game3.frlg_font')
 local Assets=require('src.render.Assets');local V=require('src.core.GameVersion')
 local old=Assets.image;local art={}
 for _,height in ipairs{8,13}do
  local pixels=love.image.newImageData(128,16*height)
  for y=0,16*height-1 do for x=0,127 do
   local xx,yy=x%8,y%height
   local tile=math.floor(x/8)+16*math.floor(y/height)
   local c=((xx+tile)%8<2 or yy==1+tile%3 or xx==yy%7)and 0 or 1
   pixels:setPixel(x,y,c,c,c,1)
  end end
  art[height]=g.newImage(pixels);art[height]:setFilter('nearest','nearest');pixels:release()
 end
 Assets.image=function(path)return art[path]or old(path)end
 local function code(cmd,n)return string.char(0xfc,cmd,n)end
 local raw=code(0x11,2)..code(0x14,6)..'Aé<PK>'
 local colors={fg={.1,.6,.9,1},shadow={.9,.2,.4,1}}
 local function setup(canvas,scale)
  g.setCanvas(canvas);g.origin();g.scale(scale);g.setShader();g.setScissor();g.setColor(1,1,1,1)
  g.setBlendMode('alpha','alphamultiply');g.clear(.125,.25,.5,1)
 end
 local function read(canvas)g.setCanvas();local d=g.readbackTexture(canvas);local s=d:getString();d:release();return s end
 for _,edition in ipairs{'firered','leafgreen','emerald','ruby','sapphire'}do
  V.set(edition)
  Font.load({font={pages={main={image=8,base=0,glyphWidth=8,glyphHeight=8,advance=4,preTinted=true}},
   faces={small={image=13,base=0,glyphWidth=8,glyphHeight=13,advance=3,preTinted=true}},
   charmap={{seq='A',code=128},{seq='é',code=129},{seq='<PK>',code=130}}}})
  for _,dpi in ipairs{1,2}do for _,scale in ipairs{1,2}do
   local actual=g.newCanvas(64*scale,48*scale,{dpiscale=dpi,format='rgba8'})
   local expected=g.newCanvas(64*scale,48*scale,{dpiscale=dpi,format='rgba8'})
   for _,hd in ipairs{false,true}do Font.hd=hd
   for _,small in ipairs{false,true}do
    local opts={small=small,colors=colors}
    setup(actual,scale);local shader=g.getShader();local depth=g.getStackDepth()
    check(F.draw(raw,5,7,opts)==20,'fixed-cell native width')
    check(g.getCanvas()==actual and g.getShader()==shader and g.getStackDepth()==depth,'graphics ownership')
    setup(expected,scale)
    for i,glyph in ipairs{'A','é','<PK>'}do F.draw(glyph,7+(i-1)*6,7,opts)end
    check(read(actual)==read(expected),'positioned Unicode/ligature pixels '..edition);frames=frames+1
    setup(actual,scale)
    local total=0;for code=0x55,0x59 do total=total+F.advance(code,opts)end
    check(F.draw('{POKEBLOCK}',5,7,opts)==total,'compound uses selected native face metrics')
    setup(expected,scale);local pen=5
    for code=0x55,0x59 do F.drawGlyph(code,pen,7,opts);pen=pen+F.advance(code,opts)end
    check(read(actual)==read(expected),'native compound glyph identities/order/positions '..edition);frames=frames+1
    setup(actual,scale);local ok=pcall(F.draw,'A'..string.char(0xfc,0x11),5,7,opts)
    check(not ok,'truncated raw control refused')
    setup(expected,scale);check(read(actual)==read(expected),'error paints no partial label');frames=frames+1
   end end
   actual:release();expected:release()
  end end
 end
 Font.hd=false;g.setCanvas();Assets.image=old;for _,a in pairs(art)do a:release()end
 print('NATIVE_TEXT_PEN_GPU_OK',checks,frames);love.event.quit(0)
end
