-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
io.stdout:setvbuf('no')
function love.errorhandler(e)io.stderr:write(debug.traceback(tostring(e),2)..'\n');return function()return 1 end end
local root=assert(os.getenv('NATIVE_BALL_ENGINE'))
package.path=root..'/?.lua;'..root..'/?/init.lua;'..package.path
local ran=false
function love.draw()
 if ran then return end;ran=true
 local g=love.graphics;local Native=require('src.battle.Gen3Battle');local V=require('src.core.GameVersion')
 local Assets=require('src.render.Assets');local original=Assets.image;local art={}
 local checks,frames=0,0
 local function check(ok,why)checks=checks+1;assert(ok,why)end
 check(love.filesystem.getIdentity():match('^oasc%-gen2recomp%-qa%-'),'own identity')
 check(g.getRendererInfo():lower():find(os.getenv('POKEPORT_GRAPHICS_BACKEND'),1,true),'requested backend')
 local function build(kind,density)
  local width,height=kind=='bar'and 128 or 32,8
  local data=love.image.newImageData(width*density,height*density)
  local tones={{1,0,0},{0,1,0},{0,0,1},{1,1,0}}
  for y=0,height*density-1 do for x=0,width*density-1 do
   local xx,yy=math.floor(x/density),math.floor(y/density)
   if kind=='bar'then data:setPixel(x,y,(xx%31)/31,.5,yy/7,1)
   else local c=tones[math.floor(xx/8)+1];local a=xx%8==0 or yy==0 and 0 or 1;data:setPixel(x,y,c[1],c[2],c[3],a==true and 0 or a)end
  end end
  local image=g.newImage(data);image:setFilter('nearest','nearest');data:release();return image
 end
 for density=1,3 do for _,kind in ipairs{'bar','balls'}do art[kind..density]=build(kind,density)end end
 Assets.image=function(path)return art[path]or original(path)end
 local party={{species='A',hp=5},{species='B',hp=5,status='PAR'},{species='C',hp=0}}
 local packed={player={'alive','status','fainted','empty','empty','empty'},opponent={'empty','empty','empty','fainted','status','alive'}}
 local function setup(canvas)
  g.setCanvas(canvas);g.origin();g.setShader();g.setScissor();g.setColor(1,1,1,1)
  g.setBlendMode('alpha','alphamultiply');g.clear(.125,.25,.5,1)
 end
 local function read(canvas)g.setCanvas();local pixels=g.readbackTexture(canvas);local bytes=pixels:getString();pixels:release();return bytes end
 for _,edition in ipairs{'firered','leafgreen','emerald','ruby','sapphire'}do
  V.set(edition)
  for _,dpi in ipairs{1,2}do for _,width in ipairs{240,320}do
   local actual=g.newCanvas(width,128,{dpiscale=dpi,format='rgba8',msaa=0})
   local expected=g.newCanvas(width,128,{dpiscale=dpi,format='rgba8',msaa=0})
   for density=1,3 do
    local summary={bar='bar'..density,balls='balls'..(4-density),barWidth=128,barHeight=8,ballSide=8,count=6,step=10,
     icons={empty=0,alive=1,status=2,fainted=3},
     player={barX=136,barY=96,ballX=160,ballY=88,packFrom=1,packStep=1},
     opponent={barX=-24,barY=40,ballX=30,ballY=33,packFrom=6,packStep=-1,flip=true}}
    local battle={introBalls=true,introBallsFrom=100,kind='trainer',playerParty=party,enemyParty=party,
     data={constants={gen3BattleHud={partySummary=summary}}},game={save={party=party}},gen3SurfaceWidth=function()return width end}
    for _,player in ipairs{true,false}do for _,age in ipairs{0,7,14,18,30,40}do for _,custom in ipairs{false,true}do
     local side=summary[player and'player'or'opponent'];local edge=player and width-240 or 0
     local dx=(side.flip and -1 or 1)*(1-math.min(1,age/14))^2*144
     local anchor=side.barX+(side.flip and 128 or edge)
     local opts=custom and{x=anchor+5,y=side.barY+3,ox=2,alpha=.5,slots={'status','alive','fainted','empty','alive','status'},
      ballHidden={false,true,false,true,false,true},ballOx={1,2,3,4,5,6}}or nil
     battle.frame=100+age;setup(actual)
     check(Native.paintPartySummary(battle,player,opts),'actual native party painter')
     setup(expected)
     local offsetX,offsetY,alpha=custom and 5 or 0,custom and 3 or 0,custom and .5 or 1
     dx=custom and 2 or dx;g.setColor(1,1,1,alpha)
     if side.flip then g.draw(art.bar1,anchor+dx+offsetX,side.barY+offsetY,0,-1,1)
     else g.draw(art.bar1,anchor+dx+offsetX,side.barY+offsetY)end
     local slots=custom and opts.slots or packed[player and'player'or'opponent']
     for slot=1,6 do
      local visible=custom and not opts.ballHidden[slot]or not custom and age>=14+(slot-1)*4
      if visible then
       local quad=g.newQuad(summary.icons[slots[slot]]*8,0,8,8,32,8)
       local ox=custom and opts.ballOx[slot]or dx
       g.draw(art.balls1,quad,side.ballX+edge+(slot-1)*10+ox+offsetX,side.ballY+offsetY)
      end
     end
     check(read(actual)==read(expected),'native party pixels '..edition..' dpi '..dpi..' width '..width..' density '..density)
     check(battle.frame==100+age and battle.introBallsFrom==100,'painting leaves native clocks unchanged');frames=frames+1
    end end end
   end
   actual:release();expected:release()
  end end
 end
 g.setCanvas();Assets.image=original
 for _,image in pairs(art)do image:release()end
 print('NATIVE_PARTY_SUMMARY_GPU_OK',checks,frames);love.event.quit(0)
end
