-- Native final-renderer acceptance and independently decoded cartridge pixels.
return function(game)
  local U=require('tests.drivers.util');local J=require('src.link.Json')
  local Serialize=require('src.core.SaveSerializer');local Music=require('src.core.Music')
  local Title=require('src.ui.Gen3TitleFRLG');local Intro=require('src.ui.Gen3IntroFRLG')
  local out=assert(os.getenv('EDITION_QA_OUT'))
  assert(require('src.core.GameVersion').get()=='leafgreen')
  assert(love.filesystem.getIdentity():match('^oasc%-edition%-qa%-'))
  local report={status='running',edition='leafgreen',captures={},assetPixels={},fullStoryTested=false}
  local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
  local function shot(name)
    local screen=assert(game.stack:top());local saved=Serialize.encode(game.save);local rng=love.math.getRandomState()
    local ok,why=require('src.render.GraphicsScope').call(screen.draw,screen);assert(ok,why)
    assert(saved==Serialize.encode(game.save)and rng==love.math.getRandomState(),'Title draw changed save/RNG')
    assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
  end
  local function untilTrue(fn,limit)
    for _=1,limit do if fn()then return end;U.wait(1)end;error('Title condition timed out')
  end
  local function press(key)
    game.input:overlayPressed(key);U.wait(1);game.input:overlayReleased(key);U.wait(1)
  end
  -- This decoder has no production extractor dependency. Addresses follow
  -- the pinned reference INTRO/TITLE_EFFECTS and leafgreen_1_0 symbol map.
  local handle=assert(io.open(assert(os.getenv('POKEPORT_IMPORT_ROM')),'rb'));local raw=handle:read('*a');handle:close()
  assert(love.data.encode('string','hex',love.data.hash('sha1',raw))=='574fa542ffebb14be69902d1d36f1ec0a4afd71e')
  local function byte(at)return assert(raw:byte(at+1))end
  local function u16(at)return byte(at)+byte(at+1)*256 end
  local function lz(at)
    assert(byte(at)==16);local size=byte(at+1)+byte(at+2)*256+byte(at+3)*65536;at=at+4
    local out={}
    while #out<size do local flags=byte(at);at=at+1
      for bit=7,0,-1 do if #out>=size then break end
        if math.floor(flags/2^bit)%2==0 then out[#out+1]=byte(at);at=at+1
        else local a,b=byte(at),byte(at+1);at=at+2;local count=math.floor(a/16)+3;local back=(a%16)*256+b+1
          for _=1,count do out[#out+1]=assert(out[#out-back+1]);if #out==size then break end end
        end
      end
    end
    return out
  end
  local function rgba(pal,index)
    local c=u16(pal+index*2)
    local r,g,b=c%32,math.floor(c/32)%32,math.floor(c/1024)%32
    r,g,b=math.floor(r*255/31+.5),math.floor(g*255/31+.5),math.floor(b*255/31+.5)
    return r,g,b,255
  end
  local paths=game.data.constants.gen3FRLGTitle.images
  local function compare(key,w,h,pixel)
    local p=paths[key];p=type(p)=='table'and p.path or p
    local data=love.image.newImageData(require('src.render.Assets').resolve(p))
    assert(data:getWidth()==w and data:getHeight()==h,key..' dimensions')
    for y=0,h-1 do for x=0,w-1 do
      local er,eg,eb,ea=pixel(x,y);local r,g,b,a=data:getPixel(x,y)
      r,g,b,a=math.floor(r*255+.5),math.floor(g*255+.5),math.floor(b*255+.5),math.floor(a*255+.5)
      assert(r==er and g==eg and b==eb and a==ea,('Reference pixel mismatch %s (%d,%d): %d,%d,%d,%d / %d,%d,%d,%d'):format(key,x,y,r,g,b,a,er,eg,eb,ea))
    end end
    report.assetPixels[key]={pixels=w*h,exact=true};data:release();persist()
  end
  local function map(key,pal,tilesAt,mapAt,bpp,mode)
    local tiles,m=lz(tilesAt),lz(mapAt)
    compare(key,240,160,function(x,y)
      local ci=(math.floor(y/8)*32+math.floor(x/8))*2;local e=m[ci+1]+m[ci+2]*256
      local sx,sy=x%8,y%8;if math.floor(e/1024)%2==1 then sx=7-sx end;if math.floor(e/2048)%2==1 then sy=7-sy end
      local tid=e%1024;local idx
      if bpp==8 then idx=tiles[tid*64+sy*8+sx+1]
      else local b=tiles[tid*32+sy*4+math.floor(sx/2)+1];idx=sx%2==0 and b%16 or math.floor(b/16)end
      if (idx==0 and mode~='opaque')or(mode=='copy'and idx<=5)or(mode=='press'and(idx<1 or idx>5))then return 0,0,0,0 end
      return rgba(pal,idx)
    end)
  end
  map('logo',0xEAB744,0xEAB944,0xEAD508,8)
  map('mon',0xEAD768,0xEAD788,0xEAE1EC,4)
  map('copyrightOnly',0xEAE388,0xEAE3A8,0xEAE668,4,'copy')
  map('pressStart',0xEAE388,0xEAE3A8,0xEAE668,4,'press')
  map('borderNative',0xEAE388,0x3BF56C,0x3BF588,4,'opaque')
  local function sheet(key,at,cols,rows)
    local tiles=lz(at)
    compare(key,cols*8,rows*8,function(x,y)
      local ti=math.floor(y/8)*cols+math.floor(x/8)
      local b=tiles[ti*32+(y%8)*4+math.floor((x%8)/2)+1]
      local idx=x%2==0 and b%16 or math.floor(b/16)
      if idx==0 then return 0,0,0,0 end;return rgba(0x3BF764,idx)
    end)
  end
  sheet('flamesNative',0x3BF784,2,22);sheet('streak',0x3BF89C,4,2);sheet('slash',0x3BF634,8,8)
  report.exactCartridgeAssets=true
  assert(getmetatable(game.stack:top())==Intro);press('b')
  untilTrue(function()local s=game.stack:top();return getmetatable(s)==Title and s.state.title.band~=nil end,30)
  local screen=game.stack:top();shot('title-band')
  untilTrue(function()return screen.state.title.scene==2 and screen.state.title.sceneState==2 end,90);shot('title-gray-fade')
  untilTrue(function()return screen.state.title.win0 and screen.state.title.win0.mode=='border'end,300);shot('title-border-wipe')
  untilTrue(function()return screen.state.title.win0 and screen.state.title.win0.mode=='copyright'end,100);shot('title-copyright-slide')
  untilTrue(function()return screen.phase=='run'end,600);shot('native-title-run')
  untilTrue(function()return screen.state.title.pressStartHidden end,100);shot('native-title-blink-off')
  untilTrue(function()return not screen.state.title.pressStartHidden end,60);shot('native-title-blink-on')
  untilTrue(function()local s=screen.state.title.slash;return s and not s.invisible and s.x>40 and s.x<200 end,650)
  shot('native-title-logo-slash')
  assert(Music.current()=='SONG_116');press('b');assert(screen.phase=='run','B unexpectedly left RUN')
  untilTrue(function()return getmetatable(game.stack:top())==Intro end,3300);shot('attract-return-to-intro')
  report.automaticAttractRestart=true
  press('start');untilTrue(function()return getmetatable(game.stack:top())==Title end,10)
  screen=game.stack:top();U.wait(8);press('b');untilTrue(function()return screen.phase=='run'end,20)
  assert(Music.current()=='SONG_116','Attract title lost music');shot('title-after-attract')
  press('start');untilTrue(function()return getmetatable(game.stack:top())==require('src.ui.Gen3MainMenu')and not game.stack:top().frlgPalette:fadeActive()end,250)
  shot('native-title-main-menu');press('b');screen=game.stack:top();assert(getmetatable(screen)==Title)
  untilTrue(function()return screen.phase=='run'end,1000);shot('native-title-menu-cancel')
  report.nativeTitleController=true;report.menuCancelAndReentry=true;report.drawSaveAndRngImmutable=true
  report.status='pass';persist();print('PASS_LEAFGREEN_NATIVE_TITLE');love.event.quit(0)
end
