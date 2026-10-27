return function(game)
  io.stdout:setvbuf('no')
  local U=require('tests.drivers.util');local J=require('src.link.Json')
  local Serialize=require('src.core.SaveSerializer');local Menu=require('src.ui.Gen3RegionMap')
  local edition=require('src.core.GameVersion').get()
  local identity=love.filesystem.getIdentity()
  assert(identity:match('^oasc%-rs%-bag%-qa%-')or identity:match('^oasc%-edition%-qa%-'..edition..'%-'))
  local c=game.data.constants;assert(c.gen3RsMap.version==edition)
  assert(require('src.import.RomImporter').readyReport(edition).ok)
  assert(c.gen3MapSections[0]=='LITTLEROOT TOWN' and c.gen3MapSections[16]=='ROUTE 101')
  assert(#c.gen3RegionMapLayout.cells==420)
  assert(c.gen3SongNames.source=='ROM:edition-specific mus_/se_ headers matched to native RS symbols')
  local names=0;for _ in pairs(c.gen3SongNames.names)do names=names+1 end;assert(names==365)
  local out=assert(os.getenv('RS_UI_QA_OUT')or os.getenv('EDITION_QA_OUT'))
  local report={edition=edition,status='running',captures={},fullStory=false,fullFlight=false}
  local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
  persist()
  U.teleport(game,'MAP_G00_N17',10,12,'up');local world=game.stack:top()
  local function press(key,wait)
    game.input:overlayPressed(key);U.wait(1);game.input:overlayReleased(key);U.wait(wait or 1)
  end
  local function immutable(screen)
    local saved=Serialize.encode(game.save);local rng=love.math.getRandomState()
    love.graphics.push('all');local ok,why=pcall(screen.draw,screen);love.graphics.pop();assert(ok,why)
    assert(Serialize.encode(game.save)==saved,'Map drawing changed save data')
    assert(love.math.getRandomState()==rng,'Map drawing consumed gameplay RNG')
  end
  local function shot(name,screen)
    immutable(screen or world);assert(U.shot(game,out..'/'..name..'.png'))
    report.captures[#report.captures+1]=name;persist()
  end
  assert(world.mapNameSign and world.mapNameSign.rsNative,'Route popup did not use native RS task')
  local popup=world.rsPopup
  U.wait(20);assert(popup.native.window.name=='ROUTE 102' and popup.native.task.yOffset==0)
  shot('popup-route-wait')
  local timer=popup.native.task.onscreen;world:updateMapNameSignGen3()
  assert(popup.native.task.onscreen==timer,'Same section restarted popup')
  local old=world.map.def
  local town={};for k,v in pairs(game.data.maps.MAP_G00_N09)do town[k]=v end;town.showMapName=true
  world.map.def=town;world:updateMapNameSignGen3();world.map.def=old
  assert(popup.native.task and popup.native.task.state==2,'New section did not queue slide-out: '..tostring(world.signLandmark)..'/'..tostring(world.mapNameSign and world.mapNameSign.rsNative==popup)..'/'..tostring(popup.native.task and popup.native.task.state))
  shot('popup-queued-out')
  U.wait(38);assert(popup.native.window.name=='LITTLEROOT TOWN');shot('popup-queued-town')
  U.wait(180);assert(world.mapNameSign==nil,'Popup never erased')
  game.save.flags.FLAG_G3_4000=true;world.signLandmark=nil;world:updateMapNameSignGen3()
  assert(world.mapNameSign==nil,'Script hide flag ignored');game.save.flags.FLAG_G3_4000=nil
  world.signLandmark=nil;world:updateMapNameSignGen3();U.wait(8);shot('popup-slide-in')
  U.wait(180);assert(world.mapNameSign==nil)
  local originalData=game.data;local reloaded={};for k,v in pairs(originalData)do reloaded[k]=v end
  local priorPopup=world.rsPopup;game.data=reloaded;world:updateMapNameSignGen3()
  assert(world.rsPopup~=priorPopup and world.rsPopup:matches(game),'Reloaded data reused stale popup bridge')
  game.data=originalData;world:updateMapNameSignGen3();assert(world.rsPopup:matches(game))
  local screen
  local function open(opts)
    screen=Menu.new(game,opts or {});assert(screen.rsNative);game.stack:push(screen);U.wait(40)
    assert(screen.rsNative.state.state==(opts and opts.fly and 12 or 4),'Native map fade did not finish')
    return screen.rsNative
  end
  local function close()press('b',40);assert(game.stack:top()==world,'Map did not return to world')end
  local native=open();shot('wall-route-start',screen)
  local realDraw=native.native.draw;local depth=love.graphics.getStackDepth()
  local px,py=love.graphics.transformPoint(7,11)
  native.native.draw=function()love.graphics.push('all');love.graphics.translate(13,17);error('RS_GRAPHICS_PROBE')end
  local ok,why=pcall(screen.draw,screen);native.native.draw=realDraw
  assert(not ok and tostring(why):find('RS_GRAPHICS_PROBE',1,true))
  local ax,ay=love.graphics.transformPoint(7,11)
  assert(love.graphics.getStackDepth()==depth and px==ax and py==ay,'Native map draw error leaked graphics state')
  local x,y=native.state.cursorX,native.state.cursorY
  press('right',6);assert(native.state.cursorX==x+1 and native.state.cursorY==y)
  shot('wall-cursor-right',screen)
  game.input:overlayPressed('left');U.wait(170);game.input:overlayReleased('left');U.wait(6)
  assert(native.state.cursorX==1);shot('wall-left-clamp',screen)
  game.input:overlayPressed('up');U.wait(100);game.input:overlayReleased('up');U.wait(6)
  assert(native.state.cursorY==2);shot('wall-top-clamp',screen)
  press('a',40);assert(game.stack:top()==world,'Wall A did not close')
  open();close()
  local C=native.kit.constants
  local function flag(name,value)game.save.flags[('FLAG_G3_%04X'):format(assert(C:flag(name)))]=value end
  local function mapId(name)local p=assert(C.map_groups.byName[name]);return ('MAP_G%02d_N%02d'):format(p.group,p.num)end
  local little=mapId('MAP_LITTLEROOT_TOWN')
  U.teleport(game,little,5,9,'down');world=game.stack:top();U.wait(180)
  -- Own QA fixtures; never copy these into the player's save.
  game.save.visited={};flag('FLAG_VISITED_LITTLEROOT_TOWN',false)
  native=open({fly=true});assert(native.state.mapSecType==3);shot('fly-unvisited',screen)
  press('a',4);assert(game.stack:top()==screen and native.state.state==12,'Unvisited town was selectable');close()
  local picked,warp
  local function capture(id,destination)picked=id;warp=destination end
  game.save.visited[little]=true;game.save.player.gender='girl'
  native=open({fly=true,onFly=capture});assert(native.state.mapSecType==2 and native.state.female)
  shot('fly-female-littleroot',screen);press('a',40)
  assert(game.stack:top()==world and picked==little and warp.nativeRs and warp.x==14 and warp.y==9,'Female native Littleroot warp lost')
  game.save.player.gender='boy';picked=nil
  native=open({fly=true,onFly=capture});assert(not native.state.female);shot('fly-male-littleroot',screen);press('a',40)
  assert(picked==little and warp.x==5 and warp.y==9,'Male native Littleroot warp lost')
  local oldale=mapId('MAP_OLDALE_TOWN');flag('FLAG_VISITED_OLDALE_TOWN',true)
  U.teleport(game,oldale,7,8,'down');world=game.stack:top();U.wait(180)
  native=open({fly=true,onFly=capture});shot('fly-oldale-native-flag',screen);press('a',40)
  local loc=c.gen3HealLocations[C.heal_locations.byName.HEAL_LOCATION_OLDALE_TOWN]
  assert(picked==loc.map and warp.x==loc.x and warp.y==loc.y,'Ordinary native heal callback lost')
  local sec=C.region_map_sections.byName
  local league=C.heal_locations.byName.HEAL_LOCATION_EVER_GRANDE_CITY_POKEMON_LEAGUE
  flag('FLAG_SYS_POKEMON_LEAGUE_FLY',true)
  local dest=native.native.flyWarpDestination(native.kit.session,sec.MAPSEC_EVER_GRANDE_CITY,0)
  assert(dest.healLocation==league and dest.map==c.gen3HealLocations[league].map)
  dest=native.native.flyWarpDestination(native.kit.session,sec.MAPSEC_EVER_GRANDE_CITY,1)
  assert(dest.healLocation==C.heal_locations.byName.HEAL_LOCATION_EVER_GRANDE_CITY)
  dest=native.native.flyWarpDestination(native.kit.session,sec.MAPSEC_BATTLE_TOWER,0)
  assert(dest.healLocation==C.heal_locations.byName.HEAL_LOCATION_BATTLE_TOWER_OUTSIDE)
  local ever=mapId('MAP_EVER_GRANDE_CITY');flag('FLAG_VISITED_EVER_GRANDE_CITY',true)
  U.teleport(game,ever,10,2,'down');world=game.stack:top();U.wait(180)
  native=open({fly=true,onFly=capture});shot('fly-league-two-line',screen);close()
  flag('FLAG_SYS_POKEMON_LEAGUE_FLY',false)
  native=open({fly=true,onFly=capture});shot('fly-evergrande-no-league',screen);close()
  U.teleport(game,little,5,9,'down');world=game.stack:top();U.wait(180)
  game.save.player.gender='girl'
  local party=require('src.ui.Gen3PartyMenu').new(game);game.stack:push(party);U.wait(35)
  party:useFly(nil);U.wait(40)
  screen=game.stack:top();assert(screen.rsNative and screen.fly,'Party FLY did not open the native map')
  press('a',25);assert(game.stack:top()==world,'Party/map selection did not return to world')
  assert(world.flyDest.map==little and world.flyDest.x==14 and world.flyDest.y==9)
  report.nativeMap=true;report.nativePopup=true;report.sectionNames=88;report.cursorCells=420
  report.nativeCursorClamp=true;report.wallAAndBClose=true;report.flyVisitedGate=true
  report.legacyVisitedReadView=true;report.nativeVisitedFlags=true;report.genderHealWarps=true
  report.ordinaryHealCallback=true;report.leagueAndTowerHealRows=true;report.exactHostFlightCoordinates=true
  report.partyFlyCallback=true;report.drawErrorScopeRestored=true
  report.popupContextReload=true
  report.drawSaveAndRngImmutable=true;report.status='pass';persist()
  print('PASS_RS_MAP_NATIVE '..edition);love.event.quit(0)
end
