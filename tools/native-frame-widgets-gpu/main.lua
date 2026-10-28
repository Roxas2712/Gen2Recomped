-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
io.stdout:setvbuf('no')
function love.errorhandler(e)io.stderr:write(debug.traceback(tostring(e),2)..'\n');return function()return 1 end end
local root=assert(os.getenv('NATIVE_BALL_ENGINE'));package.path=root..'/?.lua;'..root..'/?/init.lua;'..package.path
local ran=false
function love.draw()
 if ran then return end;ran=true
 local g=love.graphics;local P=require('src.ui.game3.presentation');local Font=require('src.render.Font')
 local V=require('src.core.GameVersion');local G=require('src.core.Game3');local Assets=require('src.render.Assets')
 local image,exists=Assets.image,Assets.exists;local art={};local checks,frames=0,0
 local function check(on,why)checks=checks+1;assert(on,why)end
 check(love.filesystem.getIdentity():match('^oasc%-gen2recomp%-qa%-'),'owned profile')
 check(g.getRendererInfo():lower():find(os.getenv('POKEPORT_GRAPHICS_BACKEND'),1,true),'requested backend')
 local function texture(name,w,h,seed)
  local data=love.image.newImageData(w,h)
  for y=0,h-1 do for x=0,w-1 do
   data:setPixel(x,y,((x*3+seed)%31)/31,((y*7+seed)%29)/29,((x+5*y+seed)%23)/23,1)
  end end
  art[name]=g.newImage(data);art[name]:setFilter('nearest','nearest');data:release()
 end
 texture('qa-frame-font',128,64,3);texture('qa-frame-user',24,24,5)
 texture('qa-frame-dialogue',144,8,7);texture('qa-frame-standard',144,8,11);texture('qa-frame-sign',144,8,17)
 Assets.image=function(path)return art[path]or image(path)end
 Assets.exists=function(path)return art[path]~=nil or exists(path)end
 local function setup(target,scale)
  Font.clearStyles();g.setCanvas(target);g.origin();g.setShader();g.setScissor();g.setDepthMode()
  g.setBlendMode('alpha','alphamultiply');g.clear(.1,.2,.3,1);g.scale(scale,scale);g.setColor(.2,.3,.4,.5)
 end
 local function read(target)
  g.setCanvas();local data=g.readbackTexture(target);local bytes=data:getString();data:release();return bytes
 end
 for _,edition in ipairs{'firered','leafgreen','emerald','ruby','sapphire'}do
  V.set(edition)
  local game={data={font={pages={main={image='qa-frame-font',base=128}}}},save={},mods={},stack={states={{}}}}
  package.loaded['src.core.Game']=game
  for _,imported in ipairs{false,true}do
   local def=game.data.font
   def.frame='drawn';def.frames=imported and{image='qa-frame-user',count=1,cell=24,tile=8}or nil
   def.dialogueFrame=imported and{image='qa-frame-dialogue',tiles=18}or nil
   def.standardFrame=imported and{image='qa-frame-standard',tiles=18}or nil
   def.signpostFrame=imported and{image='qa-frame-sign',tiles=18}or nil
   Font.load(game.data)
   for _,dpi in ipairs{1,2}do for _,scale in ipairs{1,2}do
    local actual=g.newCanvas(240*scale,160*scale,{dpiscale=dpi,format='rgba8',msaa=0})
    local expected=g.newCanvas(240*scale,160*scale,{dpiscale=dpi,format='rgba8',msaa=0})
    for _,sample in ipairs{{'drawBox','user',2,3,20,12},{'drawStandardBox','standard',2,3,20,12},
      {'drawDialogueBox','dialogue',1,14,28,6},{'drawSignpostBox','sign',1,14,28,6}}do
     local method,style,tx,ty,tw,th=unpack(sample)
     for _,mode in ipairs{'false','borrow','error'}do
      P._service.release();setup(expected,scale);Font[method](tx,ty,tw,th)
      local expectedColor={g.getColor()}
      -- A native label immediately after the frame makes colour leakage
      -- visible, rather than checking only the frame's isolated pixels.
      Font.drawCode(128,24,24)
      local calls=0
      P.register('frames',{enabled=function()return true end,draw=function(kind,ctx)
       calls=calls+1;check(kind=='frame'and ctx.style==style,'actual native frame kind')
       local x,y,w,h=tx*8,ty*8,tw*8,th*8
       if imported and(style=='dialogue'or style=='sign')then x,w=(tx-1)*8,(tw+2)*8 end
       check(ctx.x==x and ctx.y==y and ctx.width==w and ctx.height==h,'actual native painted bounds')
       if mode=='borrow'then Font[method](tx,ty,tw,th);Font[method](tx,ty,tw,th)
       elseif mode=='error'then g.push();g.setScissor(0,0,1,1);error('owned frame provider failure')end
       return false
      end})
      setup(actual,scale);P.begin(game,240,160);local depth=g.getStackDepth()
      Font[method](tx,ty,tw,th)
      local color={g.getColor()};for i=1,4 do check(color[i]==expectedColor[i],'native post-colour')end
      Font.drawCode(128,24,24)
      check(calls==1,'provider sees one native frame, including fallback chains')
      check(g.getCanvas()==actual and g.getStackDepth()==depth,'canvas/stack fence')
      check(read(actual)==read(expected),'native frame+following label pixels '..edition..' '..method..' '..mode)
      P._service.release();frames=frames+1
     end
    end
    actual:release();expected:release()
   end end
  end
  G.release()
 end
 g.setCanvas();Assets.image,Assets.exists=image,exists
 for _,item in pairs(art)do item:release()end
 print('NATIVE_FRAME_WIDGETS_GPU_OK',checks,frames);love.event.quit(0)
end
