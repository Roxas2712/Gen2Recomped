-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
io.stdout:setvbuf('no')
local root=assert(os.getenv('BATTLE_SOURCE_ENGINE'))
package.path=root..'/?.lua;'..root..'/?/init.lua;./?/init.lua;'..package.path
function love.errorhandler(err)io.stderr:write(debug.traceback(tostring(err),2)..'\n');return function()return 1 end end
function love.load()
  local T=require('tests.harness').suite('native battle animation GPU')
  local A=require('src.core.game3.battle.anim')
  local Battle=require('src.core.game3.battle')
  local Scope=require('src.render.GraphicsScope')
  local g=love.graphics
  local nativeSource=debug.getinfo(require('src.battle.BattleState').update,'S').source
  T.eq(nativeSource,'@'..root..'/src/battle/BattleState.lua')
  local renderer,version,vendor,device=g.getRendererInfo()
  local backend=assert(os.getenv('POKEPORT_GRAPHICS_BACKEND'))
  T.check(renderer:lower():find(backend,1,true)~=nil,'actual requested GPU backend')
  T.eq(love.filesystem.getIdentity(),os.getenv('POKEPORT_IDENTITY'))
  love.filesystem.createDirectory('tests/fixture_data/assets')
  local pixels=love.image.newImageData(64,64)
  pixels:mapPixel(function(x,y)
    if x<7 or y<5 or x>56 or y>57 then return 0,0,0,0 end
    if y<20 and x<37 then return 1,0,91/255,1 end
    if x>40 and y>35 then return 0,1,125/255,1 end
    return .2,.3,.9,1
  end)
  for _,side in ipairs{'back','front'}do pixels:encode('png','tests/fixture_data/assets/fixmon_a_'..side..'.png')end
  pixels:release()
  local comparisons,readbacks=0,0
  local function read(canvas)
    local data=g.readbackTexture and g.readbackTexture(canvas)or canvas:newImageData()
    local bytes=data:getString();data:release();readbacks=readbacks+1;return bytes
  end
  local function frame(canvas,draw)
    local ok,why=Scope.call(function()
      g.setCanvas(canvas);g.origin();g.setShader();g.setScissor();g.clear(0,0,0,0);g.setColor(1,1,1,1);draw()
    end)
    assert(ok,why);return read(canvas)
  end
  local function same(a,b,label)comparisons=comparisons+1;T.eq(a,b,label)end
  local outerShader=g.newShader('vec4 effect(vec4 c, Image t, vec2 uv, vec2 p) { return Texel(t,uv)*c; }')
  for _,edition in ipairs{'firered','leafgreen','emerald','ruby','sapphire'}do
    A.reset();Battle._service.release()
    local f=require('tools.battle-source-runtime.fixture').new(edition)
    local game=f.game;package.loaded['src.core.Game']=game
    local b=f.fresh('TACKLE').battle;b.enter=false;game.stack:push(b);b.phase='QA_IDLE'
    b.introSlide=0;b.frlgIntro=nil
    local canvas=g.newCanvas(160,144,{format='rgba8',dpiscale=1,msaa=0})
    local preview=g.newCanvas(160,144,{format='rgba8',dpiscale=1,msaa=0})
    local function draw()return b:drawBattlerPic(b.player,20,20,1)end
    local baseline=frame(canvas,draw)
    T.check(baseline:find(string.char(255,0,91,255),1,true)~=nil,'real asymmetric art reaches the native draw')
    local p=A.present(0)
    same(frame(canvas,draw),baseline,'observing a pose preserves native pixels '..edition)
    local expected=frame(canvas,function()g.translate(13,5);draw()end)
    p.ox,p.oy=13,5
    same(frame(canvas,draw),expected,'source offsets compose with native sprite draw '..edition)
    T.check(expected~=baseline);p.ox,p.oy=nil,nil
    local img=b:battlerPic(b.player);local w,h=img:getDimensions();local cx,cy=20+w/2,20+h/2
    expected=frame(canvas,function()
      g.translate(cx,cy);g.rotate(math.pi/2);g.scale(-.75,.5);g.translate(-cx,-cy);g.setColor(1,1,1,.5);draw()
    end)
    p.hFlip,p.rotation,p.scale,p.sx,p.sy,p.alpha=true,math.pi/2,.5,1.5,1,.5
    same(frame(canvas,draw),expected,'flip, rotation, scale and alpha preserve authored orientation '..edition)
    p.hFlip,p.rotation,p.scale,p.sx,p.sy,p.alpha=nil,nil,nil,nil,nil,nil
    same(frame(canvas,draw),baseline,'clearing source overrides restores native pixels '..edition)
    p.visible=false;local hidden=frame(canvas,draw);T.check(hidden~=baseline);T.eq(hidden,string.rep('\0',160*144*4))
    p.visible=nil
    local old=b.drawBattlerPicAt;p.ox=1
    local ok,why=Scope.call(function()
      g.setCanvas(canvas);g.setShader(outerShader)
      local depth=g.getStackDepth()
      b.drawBattlerPicAt=function()g.push();g.setCanvas(preview);error('native sprite draw failure')end
      local success,err=pcall(draw);T.eq(success,false);T.check(tostring(err):find('native sprite draw failure',1,true)~=nil)
      T.eq(g.getCanvas(),canvas);T.eq(g.getShader(),outerShader);T.eq(g.getStackDepth(),depth)
    end)
    assert(ok,why);b.drawBattlerPicAt=old;p.ox=nil
    local base={.8,.2,.35}
    for _,effect in ipairs{'invert','fade_white','fade_black','darken','grayscale','custom_blend'}do
      A.setScreenEffect({type=effect,coeff=.5,targetColor={.2,.4,.6}})
      frame(canvas,function()
        g.setShader(outerShader);T.eq(A.beginScreenEffect(),true)
        local active=g.getShader();T.neq(active,outerShader)
        T.eq(A.beginScreenEffect(),true);T.eq(g.getShader(),active,'repeated begin does not nest')
        local nested=Scope.call(function()
          T.eq(A.beginScreenEffect(),true);T.eq(A.endScreenEffect(),true);T.eq(g.getShader(),active)
        end);T.eq(nested,true)
        g.setColor(base[1],base[2],base[3],1);g.rectangle('fill',0,0,160,144)
        T.eq(A.endScreenEffect(),true);T.eq(g.getShader(),outerShader)
      end)
      local data=g.readbackTexture and g.readbackTexture(canvas)or canvas:newImageData();readbacks=readbacks+1
      local actual={data:getPixel(10,10)};data:release()
      local luma=base[1]*.299+base[2]*.587+base[3]*.114
      for channel=1,3 do
        local target=effect=='fade_white'and 1 or(effect=='grayscale'and luma or(effect=='custom_blend'and({.2,.4,.6})[channel]or 0))
        local value=effect=='invert'and 1-base[channel]or(base[channel]+target)/2
        T.check(math.abs(actual[channel]-value)<2/255,'screen effect GPU colour '..effect..' '..edition)
      end
      T.eq(actual[4],1)
    end
    local priorShader=g.getShader();local depth=g.getStackDepth();local priorCanvas=g.getCanvas()
    ok,why=Scope.call(function()A.beginScreenEffect();g.push();g.setCanvas(preview);error('effect failure')end)
    T.eq(ok,false);T.check(tostring(why):find('effect failure',1,true)~=nil)
    T.eq(g.getShader(),priorShader);T.eq(g.getStackDepth(),depth);T.eq(g.getCanvas(),priorCanvas)
    A.setScreenEffect(nil);T.eq(A.beginScreenEffect(),false)
    canvas:release();preview:release();game.stack.states={};f.close();A.reset();Battle._service.release()
  end
  outerShader:release();T.finish()
  local report={passed=true,checks=T.checks,comparisons=comparisons,readbacks=readbacks,
    backend=backend,renderer=renderer,version=version,vendor=vendor,device=device,
    nativeBattleSource=nativeSource,engineRoot=root,syntheticBattlerArt=true,
    playerProfilesUsed=false,originalModLoaded=false,gameplayProven=false}
  local file=assert(io.open(assert(os.getenv('BATTLE_SOURCE_REPORT')),'w'))
  file:write(require('src.link.Json').encode(report));file:close();love.event.quit(0)
end
