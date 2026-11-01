-- Prepared native scene qualification; separate from the ordinary campaign.
return function(game)
 local U=require('tests.drivers.util');local J=require('src.link.Json')
 local Serialize=require('src.core.SaveSerializer');local V=require('src.core.GameVersion')
 local out=assert(os.getenv('EDITION_QA_OUT'));assert(V.get()=='emerald')
 assert(love.filesystem.getIdentity():match('^oasc%-edition%-qa%-emerald%-'))
 assert(require('src.import.RomImporter').readyReport('emerald').ok)
 local report={edition='emerald',status='running',preparedTutorialFixture=true,continuousStory=false,captures={}}
 local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
 local battle
 local function shot(name)
  local save=Serialize.encode(game.save);local rng=love.math.getRandomState()
  local policy=battle and Serialize.encode(battle.rsWally.state)
  local events=battle and Serialize.encode(battle.rsWally.events)
  local top=game.stack:top();local ok,why=require('src.render.GraphicsScope').call(top.draw,top);assert(ok,why)
  assert(save==Serialize.encode(game.save)and rng==love.math.getRandomState(),'Draw changed save/RNG')
  if battle then assert(policy==Serialize.encode(battle.rsWally.state)and events==Serialize.encode(battle.rsWally.events),'Draw advanced the tutorial')end
  assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
 end
 persist()
 local f=assert(io.open(assert(os.getenv('POKEPORT_IMPORT_ROM')),'rb'));local rom=f:read('*a');f:close()
 local load=require('compat.gen1-rs.Loader').new('emerald')
 local S=load('src.import.gba.syms').of('emerald')
 local function u16(s,p)local a,b=s:byte(p+1,p+2);return a+b*256 end
 local function ptr(p)return u16(rom,p)+u16(rom,p+2)*65536-0x08000000 end
 local function lz(p)
  assert(rom:byte(p+1)==16)
  local n=rom:byte(p+2)+rom:byte(p+3)*256+rom:byte(p+4)*65536;local bytes={};p=p+4
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
 local manifest=J.decode(assert(love.filesystem.read('tools/rom_manifest_emerald.json')))
 assert(ptr(manifest.specials.at+303*4)-1==S.funcOff('LoadWallyZigzagoon'))
 assert(ptr(manifest.specials.at+160*4)-1==S.funcOff('StartWallyTutorialBattle'))
 local spec=assert(game.data.constants.gen3EmeraldWally)
 assert(require('src.import.Gen3EmeraldWallyAssets').valid(spec,'emerald'))
 assert(ptr(S.off('gTrainerBackPicTable')+6*8)==S.off('gTrainerBackPic_Wally'))
 local gfx=rom:sub(S.off('gTrainerBackPic_Wally')+1,S.off('gTrainerBackPic_Wally')+8192)
 local pal=lz(S.off('gTrainerPalette_Wally'));local checked=0
 local function compare(img,dx,tileBase)
  for y=0,63 do for x=0,63 do
   local tile=tileBase+math.floor(y/8)*8+math.floor(x/8)
   local byte=gfx:byte(tile*32+(y%8)*4+math.floor((x%8)/2)+1)
   local ix=x%2==0 and byte%16 or math.floor(byte/16)
   local r,g,b,a=img:getPixel(dx+x,y)
   assert(math.floor(a*255+.5)==(ix==0 and 0 or 255),'Original sprite alpha')
   if ix~=0 then local c=u16(pal,ix*2)
    assert(math.floor(r*255+.5)==math.floor(c%32*255/31+.5)
     and math.floor(g*255+.5)==math.floor(math.floor(c/32)%32*255/31+.5)
     and math.floor(b*255+.5)==math.floor(math.floor(c/1024)%32*255/31+.5),'Original Wally pixel')
   end
   checked=checked+1
  end end
 end
 local img=love.image.newImageData(spec.images.strip);assert(img:getWidth()==256 and img:getHeight()==64)
 for frame=0,3 do compare(img,frame*64,frame*64)end;img:release()
 img=love.image.newImageData(spec.images.idle);compare(img,0,spec.anim.rest*64);img:release()
 assert(checked==20480);report.independentRomPixels=checked
 U.freshSave(game);U.teleport(game,'MAP_G00_N17',10,12,'down')
 game.save.party={require('src.pokemon.Pokemon').new(game.data,'TREECKO',10)}
 game.save.inventory={POTION=9,POKE_BALL=8};game.save.player.name='QA'
 game.save.player.gender='girl';game.save.playerGender=1
 local originalParty=Serialize.encode(game.save.party);local originalInventory=Serialize.encode(game.save.inventory)
 local dex=Serialize.decode(Serialize.encode(game.save.pokedex));dex.seen.RALTS=true;local expectedDex=Serialize.encode(dex)
 local C=require('src.script.Gen3Commands');local ctx={game=game,save=game.save}
 C.SPECIALS[40](ctx);C.SPECIALS[303](ctx)
 assert(#game.save.party==1 and game.save.party[1].species=='ZIGZAGOON'and game.save.party[1].level==7)
 local restored=false;ctx.runner={yield=function()end,resume=function()C.SPECIALS[41](ctx);restored=true end}
 C.SPECIALS[160](ctx);battle=game.stack:top();assert(battle.rsWally and battle.rsWally.spec.version=='emerald')
 assert(require('src.battle.Abilities').of(battle.player)==nil,'Original borrowed empty ability slot')
 local seen={};local release=false
 for tick=1,18000 do
  if restored then break end
  local top=game.stack:top()
  if top==battle then
   local w=battle.rsWally;local key
   if battle.phase=='menu'then key='menu-'..w.state.wallyState
   elseif battle.phase=='moveSelect'then key='moves-'..w.state.wallyState
   elseif w.recallFrame then key='recall'
   elseif w.hidden and battle.showPlayerBack then key='wally-returned'end
   if key and not seen[key]then seen[key]=true;shot(key)end
   if battle.gen3Ball then
    local tag='ball-'..tostring(battle.gen3Ball.sendOut or'catch')..'-'..battle.gen3Ball.phase
    if not seen[tag]then seen[tag]=true;shot(tag)end
   end
   if release then game.input:overlayReleased('b');release=false
   elseif battle.phase=='messages'and(battle.msgWaiting or battle.msgPrompt)then game.input:overlayPressed('b');release=true end
  elseif top.emerald and top.wallyTutorial then
   if not top.emeraldFade and not top.emeraldSwitch then
    assert(top.noInput and #top.rows==2 and top.rows[1].qty==1 and top.rows[2].close)
    local key=top.pocket==1 and'potion-pocket'or'ball-pocket'
    if not seen[key]then
     seen[key]=true;shot(key)
     local view=assert(top.emeraldView);local man=view.manifest
     assert(view.images[man.background.png]and view.images[man.sprites.male.png],'Wally uses male art for a female player')
     if top.pocket==2 then
      assert(top.rows[1].id=='POKE_BALL'and battle.player.curMoves[1].pp==33)
      assert(battle.enemy.mon.hp>0 and battle.enemy.mon.hp<18)
      report.beforeThrow={pp=battle.player.curMoves[1].pp,enemyHP=battle.enemy.mon.hp}
     else assert(top.rows[1].id=='POTION')end
    end
   end
  elseif top.emeraldBag and not seen.use then
   assert(top.noInput and top.columns==1 and #top.entries==2 and top.entries[1].kind=='use')
   seen.use=true;shot('tutorial-use-menu')
  end
  U.wait(1)
 end
 assert(restored,'Original tutorial did not finish')
 local times,bagFrames={},{}
 for _,event in ipairs(battle.rsWally.events)do times[event.kind]=event.frame;bagFrames[event.kind]=event.bagFrame end
 assert(times['trainer-slide-start']-times['recall-start']==12)
 assert(times['trainer-slide-end']-times['trainer-slide-start']==48)
 assert(seen['menu-0']and seen['moves-0']and seen['menu-1']and seen['moves-1']and seen['potion-pocket']and seen['ball-pocket']and seen.use)
 assert(battle.rsWally.state.wallyState==4 and battle.player.curMoves[1].pp==33)
 assert(bagFrames['bag-open']==0 and bagFrames['bag-pocket-switch']==102 and bagFrames['bag-use-menu']==204 and bagFrames['bag-use']==306)
 assert(Serialize.encode(game.save.party)==originalParty and Serialize.encode(game.save.inventory)==originalInventory)
 assert(Serialize.encode(game.save.pokedex)==expectedDex and game.save.player.name=='QA'and game.save.player.gender=='girl')
 report.events=battle.rsWally.events;report.borrowedPartyRestored=true;report.noOwnedRaltsOrBallCost=true
 report.nativeRaltsSeenOnly=true;report.drawSaveRngAndPolicyImmutable=true;report.status='pass';persist()
 print('PASS_EMERALD_WALLY_NATIVE');love.event.quit()
end
