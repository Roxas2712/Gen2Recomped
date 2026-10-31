-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Prepared renderer acceptance only; ordinary campaign saves are not used.
return function(game)
 local U=require('tests.drivers.util');local J=require('src.link.Json')
 local V=require('src.core.GameVersion');local edition=V.get()
 local out=assert(os.getenv('EDITION_QA_OUT'))
 local S=require('src.core.SaveSerializer');local Font=require('src.render.Font')
 local report={edition=edition,status='running',preparedFixture=true,continuousStory=false,captures={}}
 for _,event in ipairs{'keypressed','keyreleased','textinput','gamepadpressed','gamepadreleased',
  'joystickpressed','joystickreleased','joystickaxis','joystickhat','touchpressed','touchreleased',
  'touchmoved','mousepressed','mousereleased'}do love[event]=function()end end
 local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
 game.input:reset();U.freshSave(game)
 local function shot(name)
  local raw,rng=S.encode(game.save),love.math.getRandomState();local top=game.stack:top()
  assert(require('src.render.GraphicsScope').call(top.draw,top))
  assert(raw==S.encode(game.save)and rng==love.math.getRandomState(),'Popup drawing changed save/RNG')
  assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
 end
 local function held(world)
  local s=world.mapNameSign
  if not s then return false end
  if s.rsNative then local task=s.rsNative.native.task;return task and task.state==1 and task.registerOffset==0 end
  if s.emerald then return s.state=='wait'and s.offset==0 end
  return s.frlg and s.frames<=132 and s.frames>30
 end
 local function show(map)
  U.teleport(game,map,10,12,'up');U.wait(30);local world=game.stack:top()
  game.save.flags.FLAG_G3_4000=nil;world.signLandmark=nil;world:updateMapNameSign()
  for _=1,240 do if held(world)then return world end;U.wait(1)end
  error('Native popup hold phase absent')
 end
 local world=show(V.isFRLG()and'MAP_G03_N00'or'MAP_G00_N16')
 if V.isFRLG()then
  local original=Font.drawStandardBox;local seen
  Font.drawStandardBox=function(x,y,w,h,...)
   seen={x,y,w,h};return original(x,y,w,h,...)
  end
  local ok,why=pcall(function()shot('native-popup-pallet-standard')end)
  Font.drawStandardBox=original;assert(ok,why)
  assert(seen and seen[1]==0 and seen[2]==-1 and seen[3]==16 and seen[4]==4,'Popup missed native BG0 standard-frame geometry')
  local saved=game.save.options.gen3Frame
  game.save.options.gen3Frame=10;shot('native-popup-pallet-frame-option-10');game.save.options.gen3Frame=saved
  report.fixedStandardFrame=true;report.visiblePopupBounds={x=0,y=0,width=128,height=24}
 else shot('native-popup-edition-standard')end
 local popup=world.mapNameSign
 require('src.world.Gen3FieldPoison').start(world,edition)
 world.gen3PoisonMosaic.frame=5;shot('native-popup-during-original-poison')
 assert(world.mapNameSign==popup and require('src.world.Gen3FieldPoison').size(world)>1)
 U.wait(15);assert(world.mapNameSign==popup);shot('native-popup-after-original-poison')
 if V.isFRLG()then
  world=show('MAP_G03_N34');shot('native-popup-route')
  -- Exercise the original floor metadata where the imported header has it.
  local floors={}
  for id,def in pairs(game.data.maps)do
   if id:match('^MAP_G%d+_N%d+$')and def.showMapName and tonumber(def.floorNum or 0)~=0 then floors[#floors+1]=id end
  end
  table.sort(floors);report.floorHeaderCount=#floors
  if floors[1]then world=show(floors[1]);shot('native-popup-floor-header')end
 end
 report.drawPreservesSaveRng=true;report.status='pass';persist()
 print('PASS_NATIVE_GBA_MAP_POPUP '..edition);love.event.quit(0)
end
