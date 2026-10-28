-- Prepared PokeNav fixture; ordinary story acquisition is checked separately.
return function(game)
  local U=require('tests.drivers.util');local J=require('src.link.Json')
  local Serialize=require('src.core.SaveSerializer');local Pokemon=require('src.pokemon.Pokemon')
  local Nav=require('src.ui.Gen3RsPokenav');local Generic=require('src.ui.Gen3Pokenav')
  local edition=require('src.core.GameVersion').get();local out=assert(os.getenv('EDITION_QA_OUT'))
  assert(edition=='ruby'or edition=='sapphire')
  assert(love.filesystem.getIdentity():match('^oasc%-edition%-qa%-'..edition..'%-'))
  assert(require('src.import.RomImporter').readyReport(edition).ok)
  local report={edition=edition,status='running',preparedPokenavFixture=true,continuousStory=false,
    captures={},cases={},drawSaveAndRngPreserved=true}
  local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
  persist();U.freshSave(game);U.teleport(game,'MAP_G00_N03',20,25,'down');U.wait(120)
  local world=game.stack:top();assert(world==game.overworld)
  local a=Pokemon.new(game.data,'GROVYLE',18);a.nickname='ABCDEFGHIJ'
  local b=Pokemon.new(game.data,'ZIGZAGOON',2)
  game.save.party={a,b};game.save.boxes={};game.save.boxNames={[14]='LONG BOX'}
  game.save.visited={MAP_G00_N03=true}
  for i=1,14 do game.save.boxes[i]={}end
  for i=1,12 do
    local mon=Pokemon.new(game.data,i%2==0 and 'WURMPLE'or 'TAILLOW',i+5)
    mon.contest={cool=255-i*10,beauty=i,cute=0,smart=0,tough=0,sheen=i*8}
    game.save.boxes[14][i==12 and 30 or i*2]=mon
  end
  local function press(key,delay)
    game.input:overlayPressed(key);U.wait(1);game.input:overlayReleased(key);U.wait(delay or 30)
  end
  local nav;local closed=0
  local function open()
    nav=Generic.new(game,{onCancel=function()closed=closed+1 end});assert(getmetatable(nav)==Nav)
    game.stack:push(nav);U.wait(180);assert(nav.state.phase=='active'and nav.state.menu=='main')
    return nav.state
  end
  local function shot(name)
    local before=Serialize.encode(game.save);local rng=love.math.getRandomState()
    local ok,why=require('src.render.GraphicsScope').call(nav.draw,nav);assert(ok,why)
    assert(before==Serialize.encode(game.save)and rng==love.math.getRandomState(),'PokeNav draw changed save/RNG')
    assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name
  end
  local state=open();local C=nav.mapKit.constants
  local region=nav.load('src.ui.game3.rs.pokenav.gfx').manifest('region_map')
  local nativeData=nav.load('src.ui.game3.rs.pokenav.data')
  local flagsBefore=Serialize.encode(game.save.flags)
  assert(nativeData.mapSecType(region,nav.session,region.mapsecs.RUSTBORO_CITY)==2)
  assert(nativeData.mapSecType(region,nav.session,region.mapsecs.LILYCOVE_CITY)==3)
  assert(flagsBefore==Serialize.encode(game.save.flags))
  report.cases.legacyVisitsWithoutFlagMutation=true
  local condition=nav.load('src.ui.game3.rs.pokenav.gfx').manifest('pokenav_condition')
  local symbols=require('compat.gen1-rs.Loader').new(edition)('src.import.gba.syms').of(edition)
  local rf=assert(io.open(assert(os.getenv('POKEPORT_IMPORT_ROM')),'rb'));local rom=rf:read('*a');rf:close()
  local palAt=symbols.off('gPokenavConditionMenu2_Pal')
  for index,offset in pairs({[177]=2,[181]=16,[191]=30})do
    local lo,hi=rom:byte(palAt+offset+1,palAt+offset+2)
    assert(condition.palettes.condition[index+1]==lo+hi*256,'Condition text palette byte/word mismatch')
  end
  assert(condition.palettes.condition[192]~=0)
  report.cases.nativeConditionPaletteByteOffsets=true
  assert(state.rows[1]and state.rows[2]and state.rows[3]and not state.rows[4]and state.rows[5])
  assert(nav.load('src.ui.game3.rs.pokenav.gfx').manifest('pokenav').features.matchCall==false)
  shot('rs-pokenav-main');report.cases.nativeMainAndRibbonGate=true
  press('a',150);assert(state.menu=='map'and state.feature)
  local x,y=state.feature.x,state.feature.y;shot('rs-pokenav-hoenn-map')
  press('a',90);assert(state.feature.zoomed and state.feature.scale==128)
  shot('rs-pokenav-map-zoom');press('right',90)
  assert(state.feature.scrollX~=x*8-52 or state.feature.scrollY~=y*8-68)
  press('b',90);assert(state.menu=='main'and state.cursor==0)
  report.cases.mapZoomMoveReturn=true
  press('down');press('a',90);assert(state.menu=='condition')
  shot('rs-pokenav-condition-menu');press('a',120);assert(state.menu=='graph_party')
  assert(state.feature.mon==a);shot('rs-pokenav-condition-party')
  press('down');assert(state.feature.mon==b);press('down');assert(state.feature:row().cancel)
  shot('rs-pokenav-condition-cancel');press('a',90);assert(state.menu=='condition')
  report.cases.partyAndCancel=true
  press('down');press('a',90);assert(state.menu=='search');shot('rs-pokenav-search-menu')
  press('a',90);assert(state.menu=='condition_results'and #state.feature.rows==14)
  shot('rs-pokenav-search-results')
  for _=1,9 do press('down')end
  assert(state.feature.index>8);shot('rs-pokenav-search-scrolled')
  press('a',90);assert(state.menu=='graph_search');shot('rs-pokenav-search-graph')
  press('a');assert(state.feature.markings);press('a');assert(state.feature.markings.value==1)
  local marked=state.feature.mon;assert(not marked.markings or marked.markings==0)
  for _=1,4 do press('down')end
  press('a');assert(not state.feature.markings and marked.markings==1)
  shot('rs-pokenav-markings-applied');press('b',90);assert(state.menu=='condition_results')
  press('b',90);assert(state.menu=='search');press('b',90);assert(state.menu=='condition')
  press('b',90);assert(state.menu=='main'and state.cursor==1)
  report.cases.sparseSearchScrollGraphMarkings=true
  press('down');press('a',90);assert(state.menu=='main'and state.helpOverride==7)
  shot('rs-pokenav-no-trainers');press('b');press('b',180)
  assert(game.stack:top()==world and closed==1)
  local detail=assert(love.filesystem.load('data/generated/gba/rse/pokenav_detail/manifest.lua'))()
  for i=0,11 do
    local id=detail.rematches[i].opponentIDs[1]
    game.save.flags[('FLAG_G3_%04X'):format(0x500+id)]=true
  end
  game.save.flags[('FLAG_G3_%04X'):format(C:require('flags','FLAG_SYS_RIBBON_GET'))]=true
  a.ribbons={champion=true,cool=2,effort=true}
  state=open();assert(state.rows[4]);press('down');press('down');press('a',90)
  assert(state.menu=='eyes'and #state.feature.entries==12)
  shot('rs-pokenav-trainers-eyes');for _=1,9 do press('down')end
  assert(state.feature.index==10 and state.feature.top>1);shot('rs-pokenav-trainers-scrolled')
  press('a',90);assert(state.feature.detail);shot('rs-pokenav-trainer-detail')
  press('b',90);assert(not state.feature.detail);press('b',90);assert(state.menu=='main')
  report.cases.trainersEyesListScrollDetail=true
  press('down');press('a',90);assert(state.menu=='ribbons_list'and #state.feature.rows==1)
  shot('rs-pokenav-ribbon-list');press('a',90);assert(state.menu=='ribbons_detail')
  assert(#state.feature.normal==4);shot('rs-pokenav-ribbon-grid')
  press('a',90);assert(state.feature.selecting);shot('rs-pokenav-ribbon-description')
  press('b',90);press('b',90);assert(state.menu=='ribbons_list')
  press('b',90);assert(state.menu=='main');press('b',180)
  assert(game.stack:top()==world and #game.stack.states==1 and closed==2)
  report.cases.ribbonsAndCloseCallback=true
  assert(a.nickname=='ABCDEFGHIJ'and marked.markings==1 and game.save.boxes[14][30])
  report.status='pass';persist();print('PASS_RS_NATIVE_POKENAV');love.event.quit()
end
