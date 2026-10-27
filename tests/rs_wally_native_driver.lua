-- Prepared tutorial fixture. Natural field-script acceptance is a separate run.
return function(game)
  local U=require('tests.drivers.util');local J=require('src.link.Json')
  local Serialize=require('src.core.SaveSerializer');local V=require('src.core.GameVersion')
  local edition=V.get();local out=assert(os.getenv('EDITION_QA_OUT'))
  assert(edition=='ruby'or edition=='sapphire')
  assert(love.filesystem.getIdentity():match('^oasc%-edition%-qa%-'..edition..'%-'))
  assert(require('src.import.RomImporter').readyReport(edition).ok)
  local report={edition=edition,status='running',preparedTutorialFixture=true,continuousStory=false,captures={},audio={}}
  local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
  local function shot(name,battle)
    local raw=Serialize.encode(game.save);local rng=love.math.getRandomState()
    if battle then
      local policy=Serialize.encode(battle.rsWally.state);local events=Serialize.encode(battle.rsWally.events)
      local ok,why=require('src.render.GraphicsScope').call(battle.draw,battle);assert(ok,why)
      assert(policy==Serialize.encode(battle.rsWally.state)and events==Serialize.encode(battle.rsWally.events),'Draw changed Wally controller')
    else
      local top=game.stack:top();local ok,why=require('src.render.GraphicsScope').call(top.draw,top);assert(ok,why)
    end
    assert(raw==Serialize.encode(game.save)and rng==love.math.getRandomState(),'Draw changed save/RNG')
    assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
  end
  persist()
  -- Decode the ROM independently of both production graphics extractors.
  local f=assert(io.open(assert(os.getenv('POKEPORT_IMPORT_ROM')),'rb'));local rom=f:read('*a');f:close()
  local S=require('compat.gen1-rs.Loader').new(edition)('src.import.gba.syms').of(edition)
  local function u16(s,p)local a,b=s:byte(p+1,p+2);return a+b*256 end
  local function ptr(p)return u16(rom,p)+u16(rom,p+2)*65536-0x08000000 end
  local function lz(p)
    assert(rom:byte(p+1)==16);local n=rom:byte(p+2)+rom:byte(p+3)*256+rom:byte(p+4)*65536
    local bytes={};p=p+4
    while #bytes<n do local flags=rom:byte(p+1);p=p+1
      for bit=7,0,-1 do if #bytes>=n then break end
        if math.floor(flags/2^bit)%2==0 then bytes[#bytes+1]=rom:byte(p+1);p=p+1
        else local a,b=rom:byte(p+1,p+2);p=p+2;local distance=(a%16)*256+b+1
          for _=1,math.floor(a/16)+3 do bytes[#bytes+1]=assert(bytes[#bytes-distance+1])end
        end
      end
    end
    local chars={};for i=1,n do chars[i]=string.char(bytes[i])end;return table.concat(chars)
  end
  local manifest=J.decode(assert(love.filesystem.read('tools/rom_manifest_'..edition..'.json')))
  assert(ptr(manifest.specials.at+301*4)-1==S.funcOff('PutZigzagoonInPlayerParty'))
  assert(manifest.specialRemap[302]==303 and manifest.specialIndexMap['303']==301)
  report.nativeTutorialSpecialVerified=true
  local spec=game.data.constants.gen3RsWally;local ball=game.data.constants.gen3BallAnim
  local checked=0
  local function compare(img,dx,dy,w,h,gfx,pal,tileBase)
    for y=0,h-1 do for x=0,w-1 do
      local tile=tileBase+math.floor(y/8)*(w/8)+math.floor(x/8)
      local byte=gfx:byte(tile*32+(y%8)*4+math.floor((x%8)/2)+1)
      local ix=x%2==0 and byte%16 or math.floor(byte/16)
      local r,g,b,a=img:getPixel(dx+x,dy+y)
      assert(math.floor(a*255+.5)==(ix==0 and 0 or 255),'Sprite alpha')
      if ix~=0 then local c=u16(pal,ix*2)
        assert(math.floor(r*255+.5)==math.floor(c%32*255/31+.5)
          and math.floor(g*255+.5)==math.floor(math.floor(c/32)%32*255/31+.5)
          and math.floor(b*255+.5)==math.floor(math.floor(c/1024)%32*255/31+.5),'Sprite pixel')
      end
      checked=checked+1
    end end
  end
  local wg,wp=lz(S.off('gTrainerBackPic_Wally')),lz(S.off('gTrainerPalette_Wally'))
  local img=love.image.newImageData(spec.images.strip);assert(img:getWidth()==256 and img:getHeight()==64)
  for frame=0,3 do compare(img,frame*64,0,64,64,wg,wp,frame*64)end;img:release()
  img=love.image.newImageData(spec.images.idle);compare(img,0,0,64,64,wg,wp,3*64);img:release()
  img=love.image.newImageData(ball.images.balls);assert(img:getWidth()==48 and img:getHeight()==192)
  local open=lz(S.off('gUnknown_08D030D0'));assert(#open==128)
  for index=0,11 do
    local gfx=lz(ptr(S.off('pokeball.o:sBallSpriteSheets')+index*8))
    if index~=6 and index~=10 and index~=11 then gfx=gfx:sub(1,256)..open end
    local pal=lz(ptr(S.off('pokeball.o:sBallSpritePalettes')+index*8))
    for frame=0,2 do compare(img,frame*16,index*16,16,16,gfx,pal,frame*4)end
  end
  img:release();report.independentRomPixels=checked;assert(checked==29696)
  local ids=game.data.constants.gen3RsPresentation.songIds
  for _,key in ipairs({'SE_BALL_THROW','SE_BALL_OPEN','SE_BALL_TRADE','MUS_EVOLVED','MUS_CAUGHT'})do
    local song=assert(game.data.audio.songs[('SONG_%03X'):format(ids[key])])
    local engine=require('src.core.M4ASynth').newEngine(game.data,song,{allowLoops=false});local signal=false
    for _=1,44100 do local l,r=engine:sampleStereo();if l~=0 or r~=0 then signal=true;break end end
    assert(signal,'Silent native cue '..key);report.audio[key]={index=ids[key],nonzeroPCM=true}
  end
  assert(game.data.audio.sfx.NativeRsCaughtIntro.m4a==ids.MUS_EVOLVED)
  assert(game.data.audio.sfx.Ball_Toss.m4a==ids.SE_BALL_THROW)
  if os.getenv('RS_WALLY_ASSETS_ONLY')=='1'then
    report.assetOnly=true;report.preparedTutorialFixture=false;report.fullStoryTested=false
    report.status='pass';persist();print('PASS_RS_WALLY_NATIVE_ASSETS_ONLY');love.event.quit();return
  end
  U.freshSave(game);U.teleport(game,'MAP_G00_N17',10,12,'down')
  game.save.party={require('src.pokemon.Pokemon').new(game.data,'TREECKO',10)}
  game.save.inventory={POKE_BALL=2};game.save.player.name='QA'
  game.save.player.gender='girl';game.save.playerGender=1
  local originalParty=Serialize.encode(game.save.party);local expectedDex=Serialize.decode(Serialize.encode(game.save.pokedex))
  local originalInventory=Serialize.encode(game.save.inventory)
  -- Native battle_main marks the opponent seen even in Wally's tutorial.
  expectedDex.seen.RALTS=true
  local originalDex=Serialize.encode(expectedDex)
  local C=require('src.script.Gen3Commands');local ctx={game=game,save=game.save}
  C.SPECIALS[40](ctx);C.SPECIALS[303](ctx)
  assert(#game.save.party==1 and game.save.party[1].species=='ZIGZAGOON'and game.save.party[1].level==7 and game.save.party[1].abilitySlot==2)
  local restored=false;ctx.runner={yield=function()end,resume=function()C.SPECIALS[41](ctx);restored=true end}
  C.SPECIALS[160](ctx);local battle=game.stack:top();assert(battle.rsWally)
  assert(require('src.battle.Abilities').of(battle.player)==nil,'Borrowed Zigzagoon explicitly selects ABILITY_NONE')
  local seen={};local eventCount=0;local release=false
  for tick=1,18000 do
    if restored then break end
    if game.stack:top()==battle then
      local w=battle.rsWally;local key
      if battle.phase=='menu'then key='menu-'..w.state.wallyState
      elseif battle.phase=='moveSelect'then key='moves-'..w.state.wallyState
      elseif w.recallFrame then key='recall'
      elseif w.hidden and battle.showPlayerBack then key='wally-returned'end
      if key and not seen[key]then seen[key]=true;shot(key,battle)end
      if #w.events~=eventCount then eventCount=#w.events;report.events=w.events;persist()end
      if battle.gen3Ball then
        local tag='ball-'..tostring(battle.gen3Ball.sendOut or 'catch')..'-'..battle.gen3Ball.phase
        if not seen[tag]then seen[tag]=true;shot(tag,battle)end
      end
      if release then game.input:overlayReleased('b');release=false
      elseif battle.phase=='messages'and(battle.msgWaiting or battle.msgPrompt) then game.input:overlayPressed('b');release=true end
    else
      local top=game.stack:top()
      if top.rs then
        assert(top.noInput and #top.rows==1 and top.rows[1].qty==1,'Native scripted one-item pocket')
        if top.pocket==1 and not seen.potion then
          assert(top.rows[1].id=='POTION');seen.potion=true;shot('tutorial-potion-pocket')
          assert(top.rsView.view._session.gender=='male'and top.rsView.view._session.playerGender==0,'Wally uses the male bag for a female player')
        elseif top.pocket==2 and not seen.bag then
          assert(top.rows[1].id=='POKE_BALL')
          assert(battle.rsWally.state.wallyState==4 and battle.player.curMoves[1].pp==33)
          assert(battle.enemy.mon.hp>0 and battle.enemy.mon.hp<18)
          report.beforeThrow={pp=battle.player.curMoves[1].pp,enemyHP=battle.enemy.mon.hp,
            playerSpecies=battle.player.mon.species,playerLevel=battle.player.mon.level}
          seen.bag=true;shot('one-ball-bag')
        end
      elseif top.rsBag and not seen.use then
        assert(top.noInput and top.columns==1 and #top.entries==2 and top.entries[1].kind=='use')
        seen.use=true;shot('tutorial-use-menu')
      end
    end
    U.wait(1)
  end
  assert(restored,'Wally never finished')
  local times={}
  for _,event in ipairs(battle.rsWally.events)do times[event.kind]=event.frame end
  assert(times['trainer-slide-start']-times['recall-start']==12,'Native 12-frame withdrawal')
  assert(times['trainer-slide-end']-times['trainer-slide-start']==48,'Native 48-frame trainer return')
  assert(seen['menu-0']and seen['moves-0']and seen['menu-1']and seen['moves-1']and seen.bag and seen.potion and seen.use)
  assert(battle.rsWally.state.wallyState==4 and battle.player.curMoves[1].pp==33)
  assert(Serialize.encode(game.save.party)==originalParty and Serialize.encode(game.save.pokedex)==originalDex)
  assert(Serialize.encode(game.save.inventory)==originalInventory and game.save.player.name=='QA')
  report.nativeRaltsSeenOnly=true
  local bagFrames={}
  for _,event in ipairs(battle.rsWally.events)do bagFrames[event.kind]=event.bagFrame end
  assert(bagFrames['bag-open']==0 and bagFrames['bag-pocket-switch']==102 and bagFrames['bag-use-menu']==204 and bagFrames['bag-use']==306)
  report.bagSequenceFrames={0,102,204,306}
  report.events=battle.rsWally.events;report.borrowedPartyRestored=true;report.noOwnedRaltsOrBallCost=true
  report.drawSaveRngAndPolicyImmutable=true;report.fullStoryTested=false
  report.status='pass';persist();print('PASS_RS_WALLY_NATIVE');love.event.quit()
end
