-- Normal NEW GAME inputs; native RS scene, naming and deferred world checks.
return function(game)
  local U=require('tests.drivers.util');local J=require('src.link.Json')
  local Serialize=require('src.core.SaveSerializer');local Music=require('src.core.Music')
  local edition=require('src.core.GameVersion').get()
  assert(love.filesystem.getIdentity():match('^oasc%-edition%-qa%-'..edition..'%-'))
  assert(not require('src.core.SaveData').saveFileExists(edition))
  local female=os.getenv('RS_BIRCH_GENDER')=='girl'
  local out=assert(os.getenv('EDITION_QA_OUT'))
  local report={status='running',edition=edition,gender=female and 'girl'or 'boy',captures={},inputs={},
    noTeleport=true,noPartyInjection=true,noDirectStoryFlagEdits=true,fullStoryTested=false}
  local function persist()
    local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()
  end
  local function press(key,frames)
    report.inputs[#report.inputs+1]={key=key,frame=U.frame()}
    game.input:overlayPressed(key);U.wait(1);game.input:overlayReleased(key);U.wait(frames or 8)
  end
  local function waitFor(fn,limit,label)
    for _=1,limit do if fn()then return end;U.wait(1)end
    error('Native RS timeout: '..label)
  end
  -- Independent decoder: compare every imported portrait pixel directly to
  -- cartridge tiles/palettes without the production boot_gfx/LZ helpers.
  local romFile=assert(io.open(assert(os.getenv('POKEPORT_IMPORT_ROM')),'rb'))
  local rom=romFile:read('*a');romFile:close()
  local syms=require('compat.gen1-rs.Loader').new(edition)('src.import.gba.syms').of(edition)
  local function u16(s,p)local a,b=s:byte(p+1,p+2);return a+b*256 end
  local function ptr(p)return u16(rom,p)+u16(rom,p+2)*65536-0x08000000 end
  local function lz(p)
    assert(rom:byte(p+1)==16)
    local n=rom:byte(p+2)+rom:byte(p+3)*256+rom:byte(p+4)*65536
    local bytes={};p=p+4
    while #bytes<n do
      local flags=rom:byte(p+1);p=p+1
      for bit=7,0,-1 do
        if #bytes>=n then break end
        if math.floor(flags/2^bit)%2==0 then bytes[#bytes+1]=rom:byte(p+1);p=p+1
        else
          local a,b=rom:byte(p+1,p+2);p=p+2
          local length=math.floor(a/16)+3;local distance=(a%16)*256+b+1
          for _=1,length do bytes[#bytes+1]=assert(bytes[#bytes-distance+1])end
        end
      end
    end
    local chars={};for i=1,n do chars[i]=string.char(bytes[i])end
    return table.concat(chars)
  end
  local function compare(key,gfx,pal,folder)
    local im=love.image.newImageData('data/generated/gba/'..(folder or 'birch')..'/'..key..'.png')
    local w,h=im:getDimensions();assert(w==64 and h==#gfx/32)
    for y=0,h-1 do for x=0,w-1 do
      local tile=math.floor(y/8)*8+math.floor(x/8)
      local byte=gfx:byte(tile*32+(y%8)*4+math.floor(x%8/2)+1)
      local index=x%2==0 and byte%16 or math.floor(byte/16)
      local r,g,b,a=im:getPixel(x,y)
      assert(math.floor(a*255+.5)==(index==0 and 0 or 255),key..': alpha')
      if index~=0 then
        local c=u16(pal,index*2)
        assert(math.floor(r*255+.5)==math.floor(c%32*255/31+.5)
          and math.floor(g*255+.5)==math.floor(math.floor(c/32)%32*255/31+.5)
          and math.floor(b*255+.5)==math.floor(math.floor(c/1024)%32*255/31+.5),key..': palette pixel')
      end
    end end
    im:release();return w*h
  end
  local function atSymbol(key,size)local p=syms.off(key);return rom:sub(p+1,p+size)end
  report.independentRomPixels=compare('birch',atSymbol('gSpriteImage_839DC14',2048),atSymbol('gBirchPalette',32))
  for index,key in ipairs({'brendan','may'})do
    report.independentRomPixels=report.independentRomPixels+compare(key,lz(ptr(syms.off('gTrainerFrontPicTable')+(index-1)*8)),
      lz(ptr(syms.off('gTrainerFrontPicPaletteTable')+(index-1)*8)))
  end
  local species=game.data.constants.gen3RsBirch.azurillSpecies
  report.independentRomPixels=report.independentRomPixels+compare('azurill',lz(ptr(syms.off('gMonFrontPicTable')+species*8)),
    lz(ptr(syms.off('gMonPaletteTable')+species*8)))
  persist();press('a',10);press('start',20)
  waitFor(function()local s=game.stack:top();return s and s.kind=='title'and s.scene.phase=='phase3'end,6000,'title')
  press('start',100)
  assert(getmetatable(game.stack:top())==require('src.ui.Gen3MainMenu'))
  assert(game.stack:top().items[1].key=='newGame');press('a',1)
  local screen=game.stack:top()
  assert(getmetatable(screen)==require('src.ui.Gen3RsBirchSpeech'),'Native RS scene was not selected')
  local scene=screen.scene
  local rng=screen.load('src.core.game3.rng')
  local function shot(name)
    assert(game.overworld==nil,'World entered before native Birch finished')
    local saved=Serialize.encode(game.save);local hostRng=love.math.getRandomState()
    local privateRng=Serialize.encode(rng.getState())
    local ok,why=require('src.render.GraphicsScope').call(screen.draw,screen);assert(ok,why)
    assert(saved==Serialize.encode(game.save)and hostRng==love.math.getRandomState(),'Birch draw changed save or host RNG')
    assert(privateRng==Serialize.encode(rng.getState()),'Birch draw advanced private RNG')
    assert(U.shot(game,out..'/'..name..'.png'))
    report.captures[#report.captures+1]=name;persist()
  end
  local function at(state,advance)
    for _=1,2500 do
      if scene.main.func==state then return end
      assert(game.overworld==nil,'World entered during Birch')
      if advance then press('a',3)else U.wait(1)end
    end
    error('Native RS state timeout: '..state..' (at '..tostring(scene.main.func)..')')
  end
  waitFor(function()return scene.showDialogue and scene.bgVisible end,1500,'welcome')
  U.wait(50);shot('birch-welcome')
  report.birchMusic=Music.current()
  assert(report.birchMusic==('SONG_%03X'):format(game.data.constants.gen3RsPresentation.songIds.MUS_ROUTE122))
  local released=false
  for _=1,1500 do
    for _,e in ipairs(scene.events)do if e.name=='azurill_release'then released=true end end
    if released then break end
    press('a',3)
  end
  assert(released,'Azurill release never happened')
  U.wait(15);shot('birch-azurill-release')
  report.ballParticles=#screen.load('src.core.game3.battle.ball_open')._particles
  assert(report.ballParticles>0,'Native ball release omitted its particles')
  at('ChooseGender',true);shot('birch-boy')
  assert(screen.cry,'Azurill cry did not create an audio source')
  local realDraw=scene.draw;local G=love.graphics;local depth=G.getStackDepth()
  local beforeX,beforeY=G.transformPoint(7,11);local oldCanvas=G.getCanvas()
  scene.draw=function()G.push('all');G.translate(17,21);error('RS_BIRCH_GRAPHICS_PROBE')end
  local ok,why=pcall(screen.draw,screen);scene.draw=realDraw
  assert(not ok and tostring(why):find('RS_BIRCH_GRAPHICS_PROBE',1,true))
  local afterX,afterY=G.transformPoint(7,11)
  assert(G.getStackDepth()==depth and G.getCanvas()==oldCanvas and beforeX==afterX and beforeY==afterY)
  press('b',6);assert(scene.main.func=='ChooseGender','B must keep the gender menu open')
  press('down',80);assert(scene.main.func=='ChooseGender'and scene.genderMenu.cursor==1)
  shot('birch-girl')
  if not female then press('up',80);assert(scene.genderMenu.cursor==0)end
  press('a',8);at('ChooseName',true)
  -- B returns to gender, without starting a map or committing a name.
  press('b',6);at('ChooseGender',true)
  assert(scene.genderMenu.cursor==0)
  if female then press('down',80)end
  press('a',8);at('ChooseName',true);shot('birch-name-presets')
  press('a',1)
  waitFor(function()return scene.naming and scene.naming.stage=='input'end,1500,'native naming')
  local naming=screen.load('src.ui.game3.naming')
  local st=assert(naming._state);assert(st.rs and st.name=='')
  shot('birch-naming-keyboard')
  press('a',6);assert(#st.name>0);local first=st.name
  press('b',6);assert(st.name=='','Naming B must delete one character')
  press('select',60);shot('birch-naming-page')
  press('select',60);press('select',60)
  press('a',6);assert(st.name==first)
  press('right',6);press('a',6);assert(#st.name>#first)
  local custom=st.name
  press('start',6);shot('birch-naming-ok');press('a',1)
  at('ProcessNameYesNoMenu',true);assert(scene.playerName==custom)
  shot('birch-name-confirm')
  press('b',6);at('ChooseGender',true)
  if female then press('down',80)end
  press('a',8);at('ChooseName',true)
  -- Exercise the ROM's preset row as well as the custom keyboard path.
  press('down',6);press('a',8);at('ProcessNameYesNoMenu',true)
  local expected=scene:presetNames()[2];assert(scene.playerName==expected)
  press('a',1)
  at('WaitForPlayerShrink',true);shot('birch-shrink')
  report.events=scene.events
  waitFor(function()return game.overworld and game.stack:top()==game.overworld end,2000,'truck')
  local world=game.overworld
  assert(game.save.player.name==expected and game.save.player.gender==report.gender)
  assert(world.map.id=='MAP_G25_N40'and #(game.save.party or {})==0)
  assert(not naming.isOpen(),'Native keyboard remained open after Birch')
  assert(U.shot(game,out..'/birch-truck.png'));report.captures[#report.captures+1]='birch-truck'
  report.player={name=game.save.player.name,gender=game.save.player.gender,rival=game.save.player.rival,
    map=world.map.id,x=world.player.cellX,y=world.player.cellY}
  report.newGameThroughUI=true;report.worldDeferredUntilNameAndGender=true
  report.preparedStarterViews=true;report.actualStarterGranted=false
  local native=require('src.ui.Gen3RsStarterSelect');local host=require('src.ui.Gen3StarterSelect')
  local list=game.data.constants.gen3Starters.species
  local starterSpec=assert(native.available(game));report.starterRomPixels=0
  for _,row in ipairs(starterSpec.species)do
    report.starterRomPixels=report.starterRomPixels+compare('front_'..row.index,
      lz(ptr(syms.off('gMonFrontPicTable')+row.index*8)),
      lz(ptr(syms.off('gMonPaletteTable')+row.index*8)),'starter_choose')
  end
  local callbacks={}
  for target=0,2 do
    local selected;local s=host.new(game,list,function(id)selected=id;callbacks[#callbacks+1]=id end)
    assert(getmetatable(s)==native);game.stack:push(s);U.wait(45)
    assert(s.scene.state=='input'and s.scene.selection==1)
    local function capture(name)
      local saved=Serialize.encode(game.save);local hostRng=love.math.getRandomState()
      local privateRng=Serialize.encode(s.load('src.core.game3.rng').getState())
      local ok,why=require('src.render.GraphicsScope').call(s.draw,s);assert(ok,why)
      assert(saved==Serialize.encode(game.save)and hostRng==love.math.getRandomState())
      assert(privateRng==Serialize.encode(s.load('src.core.game3.rng').getState()))
      assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
    end
    press('b',8);assert(game.stack:top()==s and s.scene.state=='input')
    for _=1,5 do press('left',5)end;assert(s.scene.selection==0)
    for _=1,5 do press('right',5)end;assert(s.scene.selection==2)
    for _=1,2-target do press('left',5)end
    assert(s.scene.selection==target);capture('starter-'..target..'-point')
    press('a',1);waitFor(function()return s.scene.state=='confirm'end,500,'starter confirm')
    assert(s.cry);capture('starter-'..target..'-confirm')
    press('b',8);assert(s.scene.state=='input'and not s.scene.mon and not selected)
    press('a',1);waitFor(function()return s.scene.state=='confirm'end,500,'starter reconfirm')
    press('down',6);assert(s.scene.confirm.cursor==1);press('a',8)
    assert(s.scene.state=='input'and not selected,'NO did not return to the Pokeballs')
    press('a',1);waitFor(function()return s.scene.state=='confirm'end,500,'starter final confirm')
    press('a',6);assert(selected==list[target+1]and game.stack:top()==world)
    assert(#game.save.party==0,'Presentation granted a Pokemon outside the script callback')
  end
  report.starterCallbacks=callbacks;assert(#callbacks==3)
  local menu=require('src.ui.Gen3StartMenu')
  local flags=game.save.flags
  local function rowsFor(values)
    game.save.flags=values;local screen=menu.new(game);local rows={}
    for _,row in ipairs(screen.rows)do rows[row.key]=true end
    game.save.flags=flags;return rows
  end
  assert(not rowsFor({}).pokedex and not rowsFor({}).pokenav)
  local emerald=rowsFor({FLAG_G3_0861=true,FLAG_G3_0862=true})
  assert(not emerald.pokedex and not emerald.pokenav,'Emerald flags leaked into RS menus')
  local dex=rowsFor({FLAG_G3_0801=true});assert(dex.pokedex and not dex.pokenav)
  local both=rowsFor({FLAG_G3_0801=true,FLAG_G3_0802=true});assert(both.pokedex and both.pokenav)
  report.preparedMenuFlagFixtures=true;report.noDirectStoryFlagEdits=false
  report.nativeStartMenuFlags={pokedex=game.data.constants.gen3StartMenu.pokedexFlag,
    pokenav=game.data.constants.gen3StartMenu.pokenavFlag,source=game.data.constants.gen3StartMenu.nativeGateSource}
  report.status='pass';persist();print('PASS_RS_NATIVE_STARTER_AND_BIRCH');love.event.quit(0)
end
