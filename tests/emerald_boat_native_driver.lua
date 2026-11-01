-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Prepared original Emerald voyages; no continuous-story credit or user save.
return function(game)
 local U=require('tests.drivers.util');local J=require('src.link.Json')
 local Music=require('src.core.Music');local C=require('src.script.Commands')
 local out=assert(os.getenv('EDITION_QA_OUT'));local edition=require('src.core.GameVersion').get()
 assert(edition=='emerald'and love.filesystem.getIdentity():match('^oasc%-edition%-qa%-emerald%-'))
 for _,event in ipairs{'keypressed','keyreleased','textinput','gamepadpressed','gamepadreleased','joystickpressed','joystickreleased','touchpressed','touchreleased','mousepressed','mousereleased'}do love[event]=function()end end
 local report={edition=edition,status='running',preparedBoatFixture=true,continuousStory=false,captures={},trips={}}
 local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
 local function shot(name)assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name end
 local file=assert(io.open(assert(os.getenv('POKEPORT_IMPORT_ROM')),'rb'));local rom=file:read('*a');file:close()
 -- Own-ROM byte oracle: the complete path, and its two first-phone-call halves.
 local paths={}
 for _,at in ipairs{0x1ED28C,0x1ED1C8,0x1ED22A}do
  local n,frames=0,0
  for i=0,256 do
   local action=rom:byte(at+i+1);if action==0xFE then break end
   local ticks=(action>=8 and action<=11)and 16 or(action>=0x15 and action<=0x18)and 8 or(action>=0x2D and action<=0x30)and 4
   assert(ticks,'Unexpected original Emerald sailing movement byte');n=n+1;frames=frames+ticks
  end
  paths[at]={tiles=n,frames=frames}
 end
 assert(paths[0x1ED28C].tiles==194 and paths[0x1ED1C8].tiles==97 and paths[0x1ED22A].tiles==97)
 assert(paths[0x1ED28C].frames==paths[0x1ED1C8].frames+paths[0x1ED22A].frames)
 report.originalMovementPaths=paths
 local nativeCommand=Music.nativeCommand;local active
 Music.nativeCommand=function(data,operation,value,keep,context)
  if active and operation=='fadedefaultbgm'and game.overworld and game.overworld.map and game.overworld.map.id=='MAP_G00_N11'then active.explicitLandingDefaultFade=true end
  return nativeCommand(data,operation,value,keep,context)
 end
 persist()
 for _,phone in ipairs{false,true}do
  local label=phone and'first-phone-call'or'repeat-voyage'
  local trip={firstNormanCall=phone,samples=0,maps={},segments={},maxPixelGapError=0};report.trips[#report.trips+1]=trip;active=nil
  U.freshSave(game)
  -- Only this isolated fixture's story setup differs; the voyage is the ROM script.
  game.save.flags.FLAG_G3_0132=not phone or nil
  U.teleport(game,'MAP_G00_N19',13,51,'down');U.wait(120);active=trip
  local world=game.overworld;local ctx=world.runner:makeContext();C.g3_show_object(ctx,7);C.g3_show_object(ctx,8)
  game.save.gen3Vars=game.save.gen3Vars or{};game.save.gen3Vars[16526]=1
  local boat=assert(world:npcByIndex(7));local boatId=boat.id;local seen={};local arrived=false;local phoneShot=false
  for frame=1,6000 do
   U.wait(1)
   if game.save.flags.FLAG_G3_4001 then
    local song=Music.current()
    assert(song=='SONG_1AF'or trip.explicitLandingDefaultFade and song=='SONG_1AB','Original sailing song replaced on '..world.map.id)
    local moving=world.runner.ctx and world.runner.ctx.g3Moving
    if moving and moving[7]and not moving[7].done then
     assert(world.player.hidden,'Player must remain hidden aboard the native boat')
     local count=0;for _,actor in ipairs(world.entities)do if actor==boat then count=count+1 end end
     assert(count==1,'Sailing actor missing or duplicated')
     local tiles,frames=0,0
     for _,step in ipairs(moving[7].steps)do assert(step.kind=='walk');tiles=tiles+step.count;frames=frames+step.count*16*(step.rate or 1)end
     local expected
     for at,path in pairs(paths)do if path.tiles==tiles and path.frames==frames then expected=at end end
     if not expected then trip.unexpectedMovement={tiles=tiles,frames=frames,label=moving[7].label};persist()end
     assert(expected,('Native movement does not match an independent ROM path: %d tiles, %d frames'):format(tiles,frames));trip.segments[tostring(expected)]=true
     local gap=math.max(math.abs((boat.px or 0)-world.player.px),math.abs((boat.py or 0)-world.player.py-16));trip.maxPixelGapError=math.max(trip.maxPixelGapError,gap)
     assert(gap<=8,'Native boat and player separated')
    end
    trip.samples=trip.samples+1
    if not seen[world.map.id]then
     seen[world.map.id]=true;trip.maps[#trip.maps+1]={id=world.map.id,song=song,frame=frame};shot(label..'-sailing-'..world.map.id);persist()
    end
    if phone and world.map.id=='MAP_G00_N20'and game.stack:top()~=world then
     local top=game.stack:top();local page=top.pages and top.pages[top.pageIndex]
     local text=type(page)=='table'and table.concat(page,' ')or''
     if not phoneShot and(text:find('DAD',1,true)or text:find('NORMAN',1,true))then shot(label..'-norman-dialogue');phoneShot=true end
     if frame%30==0 then game.input:overlayPressed('a');U.wait(1);game.input:overlayReleased('a')end
    end
   elseif seen.MAP_G00_N11 and game.stack:top()~=world then arrived=true;break end
  end
  assert(arrived and trip.samples>500,'Original Emerald voyage did not reach its landing dialogue')
  for _,id in ipairs{'MAP_G00_N19','MAP_G00_N20','MAP_G00_N21','MAP_G00_N11'}do assert(seen[id],'Missing original sailing seam '..id)end
  if phone then
   assert(trip.segments[tostring(0x1ED1C8)]and trip.segments[tostring(0x1ED22A)]and phoneShot,'First Norman call must separate both original movement halves')
   assert(game.save.flags.FLAG_G3_0132,'Original call must register Norman')
  else assert(trip.segments[tostring(0x1ED28C)],'Repeat voyage must use the complete original path')end
  assert(Music.current()=='SONG_1AB'and not world.player.hidden and trip.explicitLandingDefaultFade)
  shot(label..'-dewford-landing-dialogue')
  for _=1,60 do
   if game.stack:top()==world and not world.runner:isRunning()then break end
   game.input:overlayPressed('a');U.wait(1);game.input:overlayReleased('a');U.wait(30)
  end
  assert(game.stack:top()==world and not world.runner:isRunning()and #world.scriptMoves==0)
  assert(world.map.id=='MAP_G00_N11'and world.player.cellX==11 and world.player.cellY==9)
  assert(game.save.gen3Vars[16526]==0 and not game.save.flags.FLAG_G3_4001)
  game.input:overlayPressed('left');for _=1,120 do U.wait(1);if world.player.cellX~=11 then break end end;game.input:overlayReleased('left');U.wait(35)
  assert(world.player.cellX==10 and world.player.cellY==9 and not world.player.moving,'Ordinary dock exit must still work')
  shot(label..'-dewford-dock-exit');trip.status='pass';persist()
 end
 Music.nativeCommand=nativeCommand;report.status='pass';persist();print('PASS_EMERALD_BOAT_NATIVE');love.event.quit(0)
end
