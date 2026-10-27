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
 check(love.filesystem.getIdentity():match('^oasc%-gen2recomp%-qa%-'),'own identity')
 check(g.getRendererInfo():lower():find(os.getenv('POKEPORT_GRAPHICS_BACKEND'),1,true),'requested backend')
 local Assets=require('src.render.Assets');local Cursor=require('src.ui.Gen3RsMenuCursor')
 local Public=require('src.ui.game3.rs.menu_cursor');local Fx=require('src.core.game3.gba_fx')
 local V=require('src.core.GameVersion');local Writer=require('src.import.LuaWriter')
 local Chrome=require('src.ui.game3.battle_chrome');local Font=require('src.render.Font')
 local Text=require('src.ui.game3.frlg_font')
 local originalImage,originalExists=Assets.image,Assets.exists;local art={}
 Assets.image=function(path)return art[path]or originalImage(path)end
 Assets.exists=function(path)return art[path]~=nil or originalExists(path)end
 local names={'left','middle','wide','right'}
 local widths={left=8,middle=8,wide=32,right=8}
 local function build(part,density)
  local width=widths[part];local d=love.image.newImageData(width*density,16*density)
  local tone=({left={1,0,0},middle={0,1,0},wide={0,0,1},right={1,1,0}})[part]
  for y=0,16*density-1 do for x=0,width*density-1 do
   local xx,yy=math.floor(x/density),math.floor(y/density)
   local alpha=(yy<3 or yy>12 or xx<3 or xx>width-4)and 1 or 0
   d:setPixel(x,y,tone[1],tone[2],tone[3],alpha)
  end end
  local image=g.newImage(d);image:setFilter('nearest','nearest');d:release();return image
 end
 local atlas=love.image.newImageData(128,64)
 for y=0,63 do for x=0,127 do local c=x%8<4 and 0 or 1;atlas:setPixel(x,y,c,c,c,1)end end
 art['qa-font']=g.newImage(atlas);art['qa-font']:setFilter('nearest','nearest');atlas:release()
 for _,part in ipairs(names)do for density=1,3 do art[part..density]=build(part,density)end end
 local plans={
  [42]={{'right',35},{'wide',9},{'wide',1},{'left',-1}},
  [72]={{'right',65},{'wide',33},{'wide',1},{'left',-1}},
 }
 local function setup(canvas)
  g.setCanvas(canvas);g.origin();g.setShader();g.setScissor();g.setColor(1,1,1,1)
  g.setBlendMode('alpha','alphamultiply');g.clear(.125,.25,.5,1)
 end
 local function read(canvas)g.setCanvas();return g.readbackTexture(canvas)end
 local function same(a,b,why)
  local x,y=read(a),read(b);check(x:getString()==y:getString(),why);x:release();y:release()
 end
 local path='data/generated/gba/rse/common_ui/manifest.lua';assert(love.filesystem.createDirectory('data/generated/gba/rse/common_ui'))
 for _,edition in ipairs{'ruby','sapphire'}do
  V.set(edition);local game={data={constants={gen3RsBag={format=1,version=edition,common=path}}}}
  package.loaded['src.core.Game']=game
  for _,dpi in ipairs{1,2}do
   local actual=g.newCanvas(96,32,{dpiscale=dpi,format='rgba8',msaa=0})
   local expected=g.newCanvas(96,32,{dpiscale=dpi,format='rgba8',msaa=0})
   for density=1,3 do
    local manifest={game=edition,layout='rs',menuCursor={}}
    for _,part in ipairs(names)do manifest.menuCursor[part]={png=part..density,w=widths[part],h=16}end
    assert(love.filesystem.write(path,Writer.encode(manifest)));Cursor._service.release()
    for _,width in ipairs{42,72}do for _,fx in ipairs{false,{y=7,color={31,0,17}},{gray=true},{bldy=8}}do
     setup(actual);check(Public.draw(4,8,width,fx),'actual native cursor painter')
     setup(expected)
     for _,row in ipairs(plans[width])do
      Fx.draw(function()g.setColor(1,1,1,1);g.draw(art[row[1]..1],4+row[2],8)end,fx)
     end
     same(actual,expected,'logical cursor density '..density..' dpi '..dpi..' width '..width);frames=frames+1
    end end
   end
   actual:release();expected:release()
  end
 end
 -- The full native font shader must receive the indexed colour record.
 local function rgb(word)
  local out={};for i=1,3 do local n=math.floor(word/32^(i-1))%32;out[i]=(n*8+math.floor(n/4))/255 end
  return out
 end
 for n,edition in ipairs{'firered','leafgreen','emerald','ruby','sapphire'}do
  V.set(edition);local palette={};for i=1,16 do palette[i]=(i*1733+n*523)%32768 end
  local windowPalette,ppPalette={},{}
  for i=1,16 do windowPalette[i]=(palette[i]+173)%32768;ppPalette[i]=(palette[i]+743)%32768 end
  local record={images={},format=1,version=edition,palette=palette,windowPalette=windowPalette,ppPalette=ppPalette}
  local game={data={constants={},font={pages={main={image='qa-font',base=128,preTinted=true}},charmap={{code=128,seq='A'}}}}}
  game.data.constants[(edition=='ruby'or edition=='sapphire')and'gen3RsBattlePanel'or'gen3BattleTextbox']=record
  if edition=='ruby'or edition=='sapphire'then
   game.data.constants.gen3RsBag={format=1,version=edition,palette=windowPalette};ppPalette=windowPalette
  end
  package.loaded['src.core.Game']=game;Font.load(game.data)
  local manifest=Chrome.manifest()
  check(#manifest.windowTextPal==16,'native window palette exposed')
  check(#manifest.ppTextPal==16,'native PP palette exposed')
  for _,dpi in ipairs{1,2}do
   local canvas=g.newCanvas(16,16,{dpiscale=dpi,format='rgba8',msaa=0})
   for fg=0,15 do
    local shadow=15-fg;setup(canvas);Text.draw('A',0,0,{colors=Chrome.textboxColors(fg,shadow)})
    local pixels=read(canvas)
    for _,sample in ipairs{{2,rgb(palette[fg+1])},{6,rgb(palette[shadow+1])}}do
     local r,gg,b,a=pixels:getPixel(sample[1]*dpi,2*dpi)
     for i,value in ipairs{r,gg,b}do check(math.abs(value-sample[2][i])<=1.1/255,'native font palette pixel')end
     check(a>.99,'native font palette alpha')
    end
    pixels:release();frames=frames+1
   end
   for _,name in ipairs{'windowTextPal','ppTextPal'}do for fg=0,15 do
    local shadow=15-fg;local words=manifest[name]
    setup(canvas);Text.draw('A',0,0,{colors={fg=rgb(words[fg+1]),shadow=rgb(words[shadow+1])}})
    local pixels=read(canvas);local native=name=='windowTextPal'and windowPalette or ppPalette
    for _,sample in ipairs{{2,rgb(native[fg+1])},{6,rgb(native[shadow+1])}}do
     local r,gg,b,a=pixels:getPixel(sample[1]*dpi,2*dpi)
     for i,value in ipairs{r,gg,b}do check(math.abs(value-sample[2][i])<=1.1/255,'manifest font palette pixel')end
     check(a>.99,'manifest font palette alpha')
    end
    pixels:release();frames=frames+1
   end end
   canvas:release()
  end
 end
 g.setCanvas();Cursor._service.release();Fx._service.release()
 Assets.image,Assets.exists=originalImage,originalExists
 for _,image in pairs(art)do image:release()end
 print('NATIVE_RS_CURSOR_GPU_OK',checks,frames);love.event.quit(0)
end
