-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local original=package.loaded['src.core.Game']
local Dex=require('src.ui.game3.rse.pokedex');local Common=require('src.ui.game3.pokedex')
local Native=require('src.ui.Gen3Pokedex');local Search=require('src.ui.Gen3DexSearch')
local Observation=require('src.compat.gen1.NativeModalObservation');local G=require('src.core.Game3')
local V=require('src.core.GameVersion')
T.eq(package.loaded['src.core.Game'],original,'Hoenn query import does not construct Game')
T.eq(Dex.active(),nil);T.eq(Dex.isOpen(),false)
for _,edition in ipairs{'emerald','ruby','sapphire'}do
 local f=require('tools.battle-source-runtime.fixture').new(edition);local game=f.game
 package.loaded['src.core.Game']=game
 game.save.pokedex={seen={},owned={}};game.save.nationalDex=false
 game.data.constants.gen3HoennDex={native=2,numbers={CHARMANDER=1,QA_EXTRA=2}}
 game.data.pokemon.QA_EXTRA={index=277,dex=252,name='QA EXTRA'}
 local before=game.save.party[1].hp
 local fake=setmetatable({game=game},Native);table.insert(game.stack.states,fake)
 T.eq(Dex.active(),nil,'class identity alone cannot admit a dex');table.remove(game.stack.states)
 local state=Native.new(game);T.eq(Dex.active(),nil,'construction is not an open screen')
 game.stack:push(state);local view=assert(Dex.active())
 T.eq(Common.isOpen(),true);T.eq(Dex.active(),view);T.eq(view.open,true)
 T.eq(view.edition,edition);T.eq(view.nationalEnabled,false);T.eq(view.selected,0);T.eq(view.dexMode,0)
 state:move(1);T.eq(view.selected,1,'native movement owns the zero-based observation')
 game.save.nationalDex=true;T.eq(view.nationalEnabled,true)
 T.eq(view.searchState,nil,'no invented search while the native list is open')
 local child=Search.new(game,{pane='form'});T.eq(view.searchState,nil,'search constructor also waits for stack admission')
 game.stack:push(child);local q=view.searchState
 T.eq(q.phase,'menu');T.eq(q.menuItem,0);T.eq(q.topBar,0)
 child.row=4;child.picking=4;child.pick=5;child.pickTop=2
 q=view.searchState;T.eq(q.phase,'param');T.eq(q.menuItem,3);T.eq(q.cursor[3],2);T.eq(q.scroll[3],2)
 q.cursor[3]=999;q.scroll[3]=999;T.eq(child.pick,5);T.eq(child.pickTop,2)
 T.eq(view.searchState.cursor[3],2,'nested search data is detached')
 child.picking=nil;child.pane='topbar';child.bar=3
 T.eq(view.searchState.phase,'topbar');T.eq(view.searchState.topBar,2)
 T.raises(function()view.selected=4 end,'read-only')
 T.eq(state.index,2,'observations do not change selection')
 local cover={};game.stack:push(cover);T.eq(Dex.active(),view,'covered modal remains the actual owner')
 game.stack:pop();game.stack:pop();T.eq(view.searchState,nil)
 for _,key in ipairs{'data','save','mods','stack'}do
  local old=game[key];game[key]={};T.eq(Dex.active(),nil,key..' replacement retires observation')
  T.eq(view.open,false);T.eq(view.selected,nil);game[key]=old
  local nextView=assert(Dex.active());T.neq(nextView,view);view=nextView
 end
 V.set('firered');T.eq(Dex.active(),nil);T.eq(view.open,false);V.set(edition);view=assert(Dex.active())
 G.release();T.eq(view.open,false,'facade reset retires retained views');view=assert(Dex.active())
 local owned=G._withCallbackOwner('dex-owner',Dex.active)
 Dex._service:releaseOwner('unrelated');T.eq(owned.open,true)
 Dex._service:releaseOwner('dex-owner');T.eq(owned.open,false,'owner cleanup releases only observations')
 T.eq(game.stack:top(),state,'cleanup cannot close a native menu')
 T.eq(game.save.party[1].hp,before,'metadata does not consume HP')
 game.stack:pop();T.eq(Dex.active(),nil);f.close();G.release();Dex._service.release()
end
-- The fork's RS owner stores its real search state inside its isolated native
-- controller. This fixture stamps a typed state explicitly; real constructor/
-- artwork qualification is performed separately against the actual ROM.
local rsFile=io.open('src/ui/Gen3RsPokedex.lua','rb')
if rsFile then
 rsFile:close();local RS=require('src.ui.Gen3RsPokedex')
 for _,edition in ipairs{'ruby','sapphire'}do
  local f=require('tools.battle-source-runtime.fixture').new(edition);local game=f.game
  package.loaded['src.core.Game']=game
  local raw={nationalEnabled=false,selected=0,dexMode=0,fn='Search',state=3,
   searchState={phase='param',topBar=1,menuItem=2,message='native',cursor={[2]=4},scroll={[2]=8}}}
  local state=setmetatable({game=game,state=raw,exit=function(s)s.closed=true end},RS)
  game.stack:push(state);T.eq(Dex.active(),nil)
  Observation.capture(state,game);local view=assert(Dex.active())
  T.eq(Common.isOpen(),true);T.eq(view.nationalEnabled,false);T.eq(view.selected,0);T.eq(view.dexMode,0)
  T.eq(view.fn,'Search');T.eq(view.state,3)
  local q=view.searchState;T.eq(q.phase,'param');T.eq(q.menuItem,2);T.eq(q.topBar,1)
  T.eq(q.cursor[2],4);T.eq(q.scroll[2],8);q.cursor[2]=0;T.eq(raw.searchState.cursor[2],4)
  raw.selected=9;T.eq(view.selected,9);raw.searchState.phase='menu';T.eq(view.searchState.phase,'menu')
  state.state={nationalEnabled=true};T.eq(view.open,false,'replacement RS state retires its old view')
  local nextView=assert(Dex.active());T.eq(nextView.nationalEnabled,true)
  T.eq(nextView.selected,nil,'unavailable fields are not fabricated sentinels')
  game.stack:pop();T.eq(nextView.open,false);T.eq(Dex.active(),nil)
  f.close();G.release();Dex._service.release()
 end
end
for _,edition in ipairs{'firered','leafgreen','red','crystal','platinum','black'}do
 V.set(edition);T.eq(Dex.active(),nil);T.eq(Dex.isOpen(),false)
end
package.loaded['src.core.Game']=original;V.set('firered')
T.finish('native Hoenn dex/search observations, detached cursors and constructor-bound retirement')
