package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local oldFsLoad=love.filesystem.load;love.filesystem.load=loadfile
local E=require('src.battle.Experience')
local Growth=require('src.pokemon.Growth')
local P=require('src.pokemon.Pokemon')
local Assets=require('src.import.Gen3StatGrowthAssets')
local Battle=require('src.battle.BattleState')
local Font=require('src.ui.game3.frlg_font')
local Window=require('src.ui.game3.window')
local Scope=require('src.render.GraphicsScope')
local oldDraw,oldWindow,oldScope=Font.draw,Window.stdFrame,Scope.call
local drawn={}
Font.draw=function(s)drawn[#drawn+1]=tostring(s)end
Window.stdFrame=function()end;Scope.call=function(fn)return pcall(fn)end
for _,version in ipairs({'firered','leafgreen','emerald','ruby','sapphire'})do
  local f=require('tools.battle-source-runtime.fixture').new(version)
  local game=f.game;game.data.pokemon.CHARMANDER.evYield={}
  local mon=P.new(game.data,'CHARMANDER',30,function(lo)return lo or 0 end)
  local before=mon.stats.hp
  local goal=Growth.expForLevel(game.data.pokemon.CHARMANDER.growthRate,32,game.data.growth_rates)
  local levels,_,changes=E.add(game.data,mon,goal-mon.exp)
  T.same(levels,{31,32});T.eq(changes[31].old.hp,before)
  T.eq(changes[32].old.hp,changes[31].new.hp,'multi-level gains retain consecutive snapshots')
  T.check(changes[31].new~=changes[32].old and changes[32].new~=mon.stats)
  local original=changes[31].new.hp;mon.stats.hp=999;T.eq(changes[31].new.hp,original)
  local rs=version=='ruby'or version=='sapphire'
  local labels={'MAX. HP','ATTACK','DEFENSE','SP. ATK','SP. DEF','SPEED'}
  game.data.constants.gen3StatGrowth={format=1,version=version,labels=labels,
    stats={'hp','attack','defense','spatk','spdef','speed'},box={x=19,y=1,w=10,h=11},
    layout=rs and'rs'or version=='emerald'and'emerald'or'frlg'}
  T.check(Assets.valid(game.data.constants.gen3StatGrowth,version))
  if rs then
    game.stack:push({rsBattlePanel={context={load=function(name)
      if name=='src.ui.game3.frlg_font'then return Font end
      return{stdFrame=function()end}
    end}}})
  end
  game.input.wasPressed=function(_,key)return key=='a'end
  local callbacks=0;local screen=Battle.StatBox.new(game,mon,function()callbacks=callbacks+1 end,changes[31])
  game.stack:push(screen);T.check(screen.native~=nil)
  local w,h=screen:uiSize();T.eq(w,240);T.eq(h,160,'native overlays must not receive the 40px GB centering offset')
  drawn={};screen:draw();local page=table.concat(drawn,' ')
  for _,label in ipairs(labels)do T.check(page:find(label,1,true)~=nil,'six stats include '..label)end
  T.check(page:find('+',1,true)~=nil,'first native page shows increases')
  screen:update();T.eq(game.stack:top(),screen,'first input advances to totals without resuming combat')
  drawn={};screen:draw();T.check(not table.concat(drawn,' '):find('+',1,true),'second page shows totals')
  screen:update();T.neq(game.stack:top(),screen);T.eq(callbacks,1,'close resumes the queue once')
  f.close()
end
Font.draw,Window.stdFrame,Scope.call=oldDraw,oldWindow,oldScope
love.filesystem.load=oldFsLoad
T.finish('Native GBA six-stat growth pages and per-level immutable stat snapshots')
