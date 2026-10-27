-- Prepared battle fixtures, explicitly separate from continuous-story proof.
return function(game)
  local U=require('tests.drivers.util');local J=require('src.link.Json');local Serialize=require('src.core.SaveSerializer')
  local Battle=require('src.battle.BattleState');local Pokemon=require('src.pokemon.Pokemon')
  local edition=require('src.core.GameVersion').get();local out=assert(os.getenv('EDITION_QA_OUT'))
  assert(love.filesystem.getIdentity():match('^oasc%-edition%-qa%-'..edition..'%-'))
  assert(require('src.import.RomImporter').readyReport(edition).ok)
  local report={edition=edition,status='running',preparedBattleFixture=true,continuousStory=false,captures={}}
  local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
  persist()
  -- Independent LZ/map/tile/palette decoder; compare every panel pixel.
  local f=assert(io.open(assert(os.getenv('POKEPORT_IMPORT_ROM')),'rb'));local rom=f:read('*a');f:close()
  local S=require('compat.gen1-rs.Loader').new(edition)('src.import.gba.syms').of(edition)
  local function u16(bytes,p)local a,b=bytes:byte(p+1,p+2);return a+b*256 end
  local function lz(p)
    assert(rom:byte(p+1)==16);local n=rom:byte(p+2)+rom:byte(p+3)*256+rom:byte(p+4)*65536
    local bytes={};p=p+4
    while #bytes<n do
      local flags=rom:byte(p+1);p=p+1
      for bit=7,0,-1 do
        if #bytes>=n then break end
        if math.floor(flags/2^bit)%2==0 then bytes[#bytes+1]=rom:byte(p+1);p=p+1
        else local a,b=rom:byte(p+1,p+2);p=p+2;local distance=(a%16)*256+b+1
          for _=1,math.floor(a/16)+3 do bytes[#bytes+1]=assert(bytes[#bytes-distance+1])end
        end
      end
    end
    local chars={};for i=1,n do chars[i]=string.char(bytes[i])end;return table.concat(chars)
  end
  local gfx,pal=lz(S.off('gBattleTextboxTiles')),lz(S.off('gBattleTextboxPalette'))
  local map=rom:sub(S.off('gBattleTextboxTilemap')+1,S.off('gBattleTextboxTilemap')+4096)
  local spec=assert(game.data.constants.gen3RsBattlePanel);local pixels=0
  for i,key in ipairs({'message','action','moves'})do
    local im=love.image.newImageData(spec.images[key]);assert(im:getWidth()==240 and im:getHeight()==48)
    for y=0,47 do for x=0,239 do
      local entry=u16(map,((14+(i-1)*20+math.floor(y/8))*32+math.floor(x/8))*2)
      local px,py=x%8,y%8
      if math.floor(entry/1024)%2==1 then px=7-px end
      if math.floor(entry/2048)%2==1 then py=7-py end
      local byte=gfx:byte(entry%1024*32+py*4+math.floor(px/2)+1)or 0
      local index=px%2==0 and byte%16 or math.floor(byte/16)
      if index~=0 then index=index+math.floor(entry/4096)*16 end
      local r,g,b,a=im:getPixel(x,y);assert(math.floor(a*255+.5)==(index==0 and 0 or 255),'Native panel alpha '..key)
      if index~=0 then
        local c=u16(pal,index*2)
        assert(math.floor(r*255+.5)==math.floor(c%32*255/31+.5)
          and math.floor(g*255+.5)==math.floor(math.floor(c/32)%32*255/31+.5)
          and math.floor(b*255+.5)==math.floor(math.floor(c/1024)%32*255/31+.5),'Native panel pixel '..key)
      end
      pixels=pixels+1
    end end
    im:release()
  end
  report.independentPanelPixels=pixels;assert(pixels==34560)
  U.freshSave(game);game.save.options.battleLayout='og'
  local mon=Pokemon.new(game.data,'TREECKO',7);mon.hp=6
  mon.moves={{id='POUND',pp=27},{id='LEER',pp=30},{id='ABSORB',pp=20}}
  game.save.party={mon};game.save.inventory={POKE_BALL=5,POTION=2}
  U.teleport(game,'MAP_G00_N16',10,12,'down')
  local battle=Battle.newWild(game,'WURMPLE',3);game.stack:push(battle);assert(battle.rsBattlePanel)
  local reference=require('tests.rs_battle_panel_reference').new(battle)
  report.referenceCommit='fb7b0366efcb85e703e9e6d5a8a24d01456a109b'
  report.referenceScope='Exact RS action/move/font/cursor/frame draw excerpts over identical independently checked panel pixels; upper field and battle simulation excluded'
  report.referencePixelComparisons={}
  local function press(key,frames)
    game.input:overlayPressed(key);U.wait(1);game.input:overlayReleased(key);U.wait(frames or 8)
  end
  local function shot(name)
    local saved=Serialize.encode(game.save);local rng=love.math.getRandomState()
    local scroll=battle.scrollPx;local private=battle.rsBattlePanel.context.load('src.core.game3.rng')
    local privateBefore=Serialize.encode(private.getState())
    local ok,why=require('src.render.GraphicsScope').call(battle.draw,battle);assert(ok,why)
    assert(saved==Serialize.encode(game.save)and rng==love.math.getRandomState(),'Battle draw changed save or host RNG')
    assert(scroll==battle.scrollPx and privateBefore==Serialize.encode(private.getState()),'Battle draw advanced scroll/private RNG')
    assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
    if game.stack:top()==battle and(battle.phase=='menu'or battle.phase=='moveSelect')then
      local draw=battle.rsBattlePanel.draw;battle.rsBattlePanel.draw=reference
      local ok,why=pcall(U.shot,game,out..'/'..name..'-reference.png');battle.rsBattlePanel.draw=draw;assert(ok and why)
      local function image(path)
        local f=assert(io.open(path,'rb'));local raw=f:read('*a');f:close()
        return love.image.newImageData(love.filesystem.newFileData(raw,'capture.png'))
      end
      local a=image(out..'/'..name..'.png');local b=image(out..'/'..name..'-reference.png')
      local w,h=a:getDimensions();assert(w==b:getWidth()and h==b:getHeight())
      local scale=math.floor(math.min(w/240,h/160));local left=math.floor((w-240*scale)/2);local top=math.floor((h-160*scale)/2)
      local count=0
      for y=top+112*scale,top+160*scale-1 do for x=left,left+240*scale-1 do
        local ar,ag,ab,aa=a:getPixel(x,y);local br,bg,bb,ba=b:getPixel(x,y)
        assert(ar==br and ag==bg and ab==bb and aa==ba,('Reference bottom panel differs %s at %d,%d'):format(name,x,y));count=count+1
      end end
      a:release();b:release();report.referencePixelComparisons[name]=count;persist()
    end
  end
  for _=1,1600 do
    if battle.phase=='messages'and battle.msgWaiting then break end
    U.wait(1)
  end
  shot('battle-native-message')
  for _=1,250 do if battle.phase=='menu'then break end;press('a',5)end
  assert(battle.phase=='menu');shot('battle-action-fight')
  press('right');assert(battle.menuIndex==2);shot('battle-action-bag');press('a',40)
  assert(game.stack:top().rs,'BAG did not open native RS bag');shot('battle-bag-open')
  press('b',50);assert(game.stack:top()==battle and battle.phase=='menu');shot('battle-bag-return')
  press('left');press('down');assert(battle.menuIndex==3);shot('battle-action-pokemon');press('a',40)
  assert(game.stack:top().rsNative,'POKEMON did not open native RS party');shot('battle-party-open')
  press('b',50);assert(game.stack:top()==battle and battle.phase=='menu');shot('battle-party-return')
  press('up');assert(battle.menuIndex==1);press('a',10);assert(battle.phase=='moveSelect');shot('battle-move-pound')
  press('right');assert(battle.moveIndex==2);shot('battle-move-leer')
  press('down');assert(battle.moveIndex==2,'Empty fourth cell must retain the occupied move');shot('battle-move-bottom')
  press('left');assert(battle.moveIndex==1);press('down');assert(battle.moveIndex==3);shot('battle-move-absorb')
  press('b');assert(battle.phase=='menu');shot('battle-move-cancel')
  game.save.options.gen3Frame=20;shot('battle-action-frame20');press('a',10);shot('battle-moves-frame20')
  game.save.options.gen3Frame=1;press('b');press('right');press('down');assert(battle.menuIndex==4);shot('battle-action-run')
  report.hostActionOrderPreserved=true;report.nativeBagPartyReturn=true;report.hostMoveSelectionPreserved=true
  report.drawSaveRngAndScrollImmutable=true;report.frameOptions={1,20};report.status='pass';persist()
  print('PASS_RS_BATTLE_PANEL_NATIVE '..edition);love.event.quit(0)
end
