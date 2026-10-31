-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Prepared component/renderer checks, separate from ordinary campaign saves.
return function(game)
 local U,J=require('tests.drivers.util'),require('src.link.Json')
 local V=require('src.core.GameVersion');local edition=V.get()
 local out=assert(os.getenv('EDITION_QA_OUT'))
 assert(love.filesystem.getIdentity():match('^oasc%-edition%-qa%-'..edition..'%-'))
 for _,event in ipairs{'keypressed','keyreleased','textinput','gamepadpressed','gamepadreleased',
  'joystickpressed','joystickreleased','joystickaxis','joystickhat','touchpressed','touchreleased',
  'touchmoved','mousepressed','mousereleased'}do love[event]=function()end end
 game.input:reset();U.freshSave(game)
 local P=require('src.pokemon.Pokemon');local S=require('src.core.SaveSerializer')
 local M=require('src.world.Gen3FieldPoison');local g=love.graphics
 local report={edition=edition,status='running',preparedFixture=true,continuousStory=false,captures={},gpuPixelChecks=0}
 local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
 local function press(k,n)game.input:overlayPressed(k);U.wait(1);game.input:overlayReleased(k);U.wait(n or 30)end
 local function step(world,k,n)
  local map,x,y=world.map.id,world.player.cellX,world.player.cellY
  press(k,30)
  -- A released d-pad's first tap may only turn. Observe that result before
  -- giving the next ordinary press; never write facing or position.
  if world.map.id==map and world.player.cellX==x and world.player.cellY==y then press(k,n or 30)
  else U.wait(n or 30)end
 end
 local function shot(name)
  local raw,rng=S.encode(game.save),love.math.getRandomState();local top=game.stack:top()
  assert(require('src.render.GraphicsScope').call(top.draw,top))
  assert(raw==S.encode(game.save)and rng==love.math.getRandomState(),'Drawing changed save/RNG')
  assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
 end
 -- Independent GPU oracle: MOSAIC repeats the top-left source pixel of each
 -- N+1 block, including a final partial block and both viewport corners.
 for _,size in ipairs{{43,31},{241,163}}do
  local w,h=size[1],size[2];local data=love.image.newImageData(w,h)
  for y=0,h-1 do for x=0,w-1 do data:setPixel(x,y,x%251/255,y%251/255,(x+y)%251/255,1)end end
  local image=g.newImage(data);image:setFilter('nearest','nearest')
  local target=require('src.render.PixelCanvas').new(w,h,'nearest');local old=g.getCanvas()
  local state={};M.start(state,edition)
  for frame=1,10 do
   local block=M.size(state);g.push('all');g.setCanvas(target);g.origin();g.setShader();g.setColor(1,1,1,1);g.clear(0,0,0,0)
   M.background(state,w,h,function()g.draw(image,0,0)end)
   g.setCanvas(old)
   local actual=target:newImageData()
   for _,x in ipairs{0,1,7,math.floor(w/2),w-2,w-1}do
    for _,y in ipairs{0,1,7,math.floor(h/2),h-2,h-1}do
     local sx,sy=math.floor(x/block)*block,math.floor(y/block)*block
     local r,b,c,a=actual:getPixel(x,y)
     assert(math.abs(r-sx%251/255)<1.5/255 and math.abs(b-sy%251/255)<1.5/255
      and math.abs(c-(sx+sy)%251/255)<1.5/255 and a>.99,'Native GPU mosaic sample mismatch')
     report.gpuPixelChecks=report.gpuPixelChecks+1
    end
   end
   actual:release();g.setCanvas(old);g.pop();M.tick(state)
  end
  assert(state.gen3PoisonMosaic==nil);if state.gen3PoisonCanvas then state.gen3PoisonCanvas:release()end
  image:release();data:release();target:release()
 end
 game.save.party={P.new(game.data,'BLASTOISE',40)}
 game.save.party[1].moves={{id='STRENGTH',pp=15},{id='BITE',pp=25},{id='SURF',pp=15},{id='DIG',pp=10}}
 if V.isFRLG()then
  U.teleport(game,'MAP_G01_N51',10,19,'down');U.wait(30);local world=game.stack:top()
  assert(world.map:sourceBehaviourAt(10,20)==0x67 and world.map:warpPadOrHoleAt(10,20)=='pad')
  step(world,'down',160);assert(world.map.id=='MAP_G01_N55')
  assert(world.player.cellX==22 and world.player.cellY==18,'Native Silph pad auto-stepped off its arrival')
  shot('native-silph-cross-floor-pad-arrival')
  step(world,'left',30);assert(world.player.cellX==21 and world.player.cellY==18)
  step(world,'right',160);assert(world.map.id=='MAP_G01_N51')
  assert(world.player.cellX==10 and world.player.cellY==20,'Return pad arrival displaced the player')
  step(world,'up',30);assert(world.player.cellX==10 and world.player.cellY==19,'Native north exit from pad failed')
  report.nativeCrossFloorTeleporter=true
  local party=require('src.ui.Gen3PartyMenu').new(game,{});game.stack:push(party);U.wait(30);press('a',30)
  local fields={};for _,row in ipairs(assert(party.submenu))do if row.action=='field'then fields[#fields+1]=row.move end end
  assert(table.concat(fields,',')=='STRENGTH,SURF,DIG','Native field submenu omitted owned moves')
  assert(party:actionWords().cancel and party:actionWords().item)
  shot('native-party-strength-surf-dig');press('b',20);press('b',30);assert(game.stack:top()==world)
  report.nativePartyFields=fields
 end
 U.teleport(game,V.isFRLG()and'MAP_G03_N34'or'MAP_G00_N16',10,12,'up');U.wait(30)
 local world=game.stack:top();if edition=='emerald'then game.save.flags.FLAG_G3_4000=nil end
 world.signLandmark=nil;world:updateMapNameSign();assert(world.mapNameSign,'Prepared route popup unavailable')
 U.wait(24);shot('native-field-poison-before')
 local popup=world.mapNameSign;local mon=game.save.party[1];mon.status='PSN';local hp=mon.hp
 world:applyFieldPoisonDamage();assert(mon.hp==hp-1 and world.gen3PoisonMosaic,'Ordinary poison damage did not start mosaic')
 U.wait(3);report.capturedMosaicSize=M.size(world);assert(report.capturedMosaicSize>1)
 assert(world.mapNameSign==popup,'Poison replaced the map popup owner');shot('native-field-poison-mosaic')
 assert(M.size(world)>1,'Capture missed the brief original poison effect: run this visual fixture with --speed 1')
 U.wait(15);assert(world.gen3PoisonMosaic==nil and world.mapNameSign==popup)
 shot('native-field-poison-after');report.nativePoisonDamage=hp-mon.hp
 report.drawPreservesSaveRng=true;report.poisonEffect='BG mosaic; sharp OBJ and BG0 popup';report.status='pass';persist()
 print('PASS_NATIVE_GBA_FIELD_CONTRACT '..edition);love.event.quit(0)
end
