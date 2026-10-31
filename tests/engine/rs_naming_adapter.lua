-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local V=require('src.core.GameVersion')
local Serialize=require('src.core.SaveSerializer')
local Writer=require('src.import.LuaWriter')
local Context=require('src.ui.Gen3RsSceneContext');local originalContext=Context.new
local Party=require('src.ui.Gen3PartyMenu');local originalIcon=Party.iconFor
local originalLoad=love.filesystem.load
local M=require('src.ui.Gen3RsNamingScreen')
local bodies={};local observed,constructed
love.filesystem.load=function(path)
 if bodies[path]then return assert(loadstring(bodies[path]))end
 return originalLoad(path)
end
for _,edition in ipairs{'ruby','sapphire'}do
 V.set(edition)
 for _,answer in ipairs{false,'TENTA','éPK'}do
  local mon={species='OWNED_MON',personality=123,moves={{id='OWNED_MOVE',pp=7}},hp=11,level=6}
  local data=T.fixtures.fresh();data.pokemon.OWNED_MON={name='OWNED MON',index=72,genderRatio=255}
  data.constants.gen3RsBirch={format=1,version=edition}
  local game={data=data,save={party={mon},player={name='PLAYER'},flags={OWNED=true},inventory={OWNED_ITEM=3}}}
  local pops,callbacks,updates,draws,done=0,0,0,0,false
  game.input={wasPressed=function(_,key)return done and key=='a'end}
  game.stack={pop=function()pops=pops+1;game.state:exit()end}
  local scene={}
  scene.templateFromManifest=function(man)return man.templates[3]end
  scene.open=function(opts)observed=opts;return {name='',owner=mon}end
  scene.handleInput=function(input)
   if input:wasPressed('a')then observed.onDone(answer or nil)end
  end
  scene.update=function()updates=updates+1 end
  scene.draw=function()
   draws=draws+1
   local entry=constructed.bindings['src.core.game3.pokemon'].icon(72)
   T.eq(entry.w,32,'Native nickname view owns a single icon frame')
   T.eq(entry.h,32,'The two-frame host sheet is not squashed into the icon')
  end
  scene.dismiss=function()end
  Context.new=function(g,opts)
   constructed=opts
   local canvas=love.graphics.newCanvas(240,160);canvas.release=function()end
   return {game=g,version=edition,canvas=canvas,
    load=function(name)assert(name=='src.ui.game3.naming');return scene end}
  end
  Party.iconFor=function(host,actual)
   T.eq(host.game,game);T.eq(actual,mon,'The naming icon resolves the caught host Pokemon')
   return {getDimensions=function()return 32,64 end},32
  end
  bodies['data/generated/gba/naming/manifest.lua']=Writer.encode({layout='rs',game=edition,
   templates={{},{},{maxChars=10,title="'s own nickname?"}}})
  local before=Serialize.encode(game.save)
  local opts={kind='mon',mon=mon,maxLen=10,onDone=function(name)
   callbacks=callbacks+1;T.eq(pops,1,'Return callback observes the authoritative modal already closed')
   if name and #name>0 then mon.nickname=name end
  end}
  T.check(M.available(game,opts),'Matching RS mon naming is admitted')
  local state=require('src.ui.NamingScreen').new(game,opts);game.state=state
  T.eq(getmetatable(state),M,'Actual shared NamingScreen factory selects the RS controller')
  T.eq(Serialize.encode(game.save),before,'Opening native naming does not rename or write the save')
  state:draw();state:draw();state:update(1/60)
  T.eq(Serialize.encode(game.save),before,'Drawing and idle updates preserve the complete authoritative save')
  T.eq(draws,2);T.eq(updates,1)
  T.check(not pcall(constructed.bindings['src.core.game3.pokemon'].icon,73),'A foreign species cannot supply the nickname icon')
  done=true;state:update(1/60);state:update(1/60)
  T.eq(pops,1);T.eq(callbacks,1,'Confirmation commits the original callback once')
  T.eq(updates,1,'A closing input cannot tick a retired native scene')
  T.eq(mon.nickname,answer or nil,'Blank confirmation keeps the unnamed mon; typed names remain exact')
  T.eq(game.save.player.name,'PLAYER');T.eq(game.save.inventory.OWNED_ITEM,3)
  T.eq(mon.moves[1].pp,7);T.eq(mon.hp,11)
 end
end
for _,edition in ipairs{'emerald','firered','leafgreen','red','crystal'}do
 V.set(edition)
 T.eq(M.available({data={constants={gen3RsBirch={format=1,version=edition}}}},
  {kind='mon',mon={}}),false,'Other editions retain their own naming controller')
end
V.set('ruby')
local game={data={constants={gen3RsBirch={format=1,version='sapphire'}}}}
T.eq(M.available(game,{kind='mon',mon={}}),false,'Sapphire assets cannot admit Ruby naming')
game.data.constants.gen3RsBirch.version='ruby'
T.eq(M.available(game,{kind='player',mon={}}),false,'Birch retains its existing native player-name controller')
Context.new=originalContext;Party.iconFor=originalIcon;love.filesystem.load=originalLoad
T.finish('RS nickname factory, host ownership, render immutability and exact completion callbacks')
