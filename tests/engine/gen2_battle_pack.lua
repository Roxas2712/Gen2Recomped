package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local V=require('src.core.GameVersion')
local Battle=require('src.battle.BattleState')
local Pack=require('src.ui.Gen2PackMenu')
local Pokemon=require('src.pokemon.Pokemon')
local Save=require('src.core.SaveData')
local Bag=require('src.inventory.Bag')
local Screens=require('src.ui.Screens')
local oldVersion=V.get()

local function fixture(version)
  V.set(version);Screens.invalidate()
  local data=T.fixtures.fresh();data.constants.gen=V.generation()
  data.items.POTION={id='POTION',name='POTION',index=18,pocket='ITEM',battleMenu='ITEMMENU_PARTY'}
  require('src.render.Font').load(data)
  local save=Save.newGame();save.options.battleAnimations=false
  -- This older upstream menu branch defaults to Gen1 unlimited enemy PP.
  -- Select its existing finite-PP ruleset for the item-turn assertion.
  save.options.ruleset="modern_clean"
  save.party={Pokemon.new(data,'FIXMON_A',30)}
  Bag.add(save,'POTION',1,data)
  local input={pressed={}}
  function input:wasPressed(key)return self.pressed[key]==true end
  function input:isDown()return false end
  local stack={states={}}
  function stack:top()return self.states[#self.states]end
  function stack:push(s)self.states[#self.states+1]=s end
  function stack:pop()return table.remove(self.states)end
  local world={useFieldItem=function()error('battle PACK reached field effects')end}
  local game={data=data,save=save,input=input,stack=stack,overworld=world,world=world}
  local b=Battle.newWild(game,'FIXMON_C',3)
  b.phase,b.queue,b.current,b.introSlide,b.sendingOut='menu',{},nil,0,false
  b.player.mon.hp=1;b.player.shownHP=1
  b.enemy.mon.moves={{id='FIX_TACKLE',pp=35}};b.enemy.curMoves=b.enemy.mon.moves
  stack:push(b)
  local function step(key)
    input.pressed=key and{[key]=true}or{}
    stack:top():update(1/60)
    input.pressed={}
  end
  local function untilTrue(predicate)
    for tick=1,8000 do
      if predicate()then return true end
      local top=stack:top()
      local key;if not(top==b and b.phase=='menu')then key='a'end
      step(key)
    end
    return false
  end
  local function open()
    for i,choice in ipairs(b:menuActions())do if choice=='item'then b.menuIndex=i end end -- fixture starts at native ITEM
    step('a')
    T.check(untilTrue(function()return stack:top()~=b end),'actual ITEM input opens a child screen')
    return stack:top()
  end
  return b,game,step,untilTrue,open
end

for _,version in ipairs({'gold','silver','crystal','prism','polishedcrystal'})do
  local b,game,step,wait,open=fixture(version)
  local pp,enemyPP=b.player.curMoves[1].pp,b.enemy.curMoves[1].pp
  local pack=open()
  T.eq(getmetatable(pack),Pack,version..' opens the actual native Gen2 PACK controller')
  T.eq(pack.screenId,'Gen2PackMenu','native screen identity matches the Gen2 contract')
  if getmetatable(pack)==Pack then
    T.eq(pack:inBattle(),true,'native PACK uses battle eligibility')
    T.neq(pack.world,game.overworld,'battle PACK cannot invoke the live field world')
    T.eq(type(pack.onChoose),'function','native PACK has a native item-selection continuation')
    T.eq(pack.rows[1].id,'POTION','rows come from the actual native bag')
    local pocket=pack.pocketIndex
    step('right');T.neq(pack.pocketIndex,pocket,'actual input switches native pockets')
    step('left');T.eq(pack.pocketIndex,pocket,'actual input returns to the item pocket')
    step('b')
    T.check(wait(function()return game.stack:top()==b and b.phase=='menu'end),'native cancel releases the queued UI owner')
    T.eq(game.save.inventory.POTION,1,'cancel keeps inventory')
    T.eq(b.player.mon.hp,1,'cancel cannot heal or spend a turn')
    T.eq(b.player.curMoves[1].pp,pp,'cancel keeps move PP')
    pack=open();step('a') -- native USE row
    if game.stack:top()==pack and pack.submenu then step('a')end
    T.check(game.stack:top()~=pack,'actual USE opens native target selection')
    step('a') -- choose the actual first party Pokemon
    T.check(wait(function()return game.stack:top()==b and b.phase=='menu'end),'actual item turn returns to the battle owner')
    T.eq(game.save.inventory.POTION,nil,'actual healing consumes exactly the owned potion')
    T.check(b.player.mon.hp>1,'actual native item effect heals the chosen party Pokemon')
    T.eq(b.player.curMoves[1].pp,pp,'item use does not spend a move PP')
    T.eq(b.enemy.curMoves[1].pp,enemyPP-1,'item use gives the native enemy exactly one action')
    T.eq(game.stack:top(),b,'item/target/message screens leave no orphaned owner')
  end
end
for _,version in ipairs({'red','firered','emerald'})do
  local b,game,step,wait,open=fixture(version)
  local screen=open()
  T.neq(getmetatable(screen),Pack,version..' retains its existing bag controller')
end
V.set(oldVersion);Screens.invalidate()
T.finish('native Gen2 battle PACK selection and item turn ownership')
