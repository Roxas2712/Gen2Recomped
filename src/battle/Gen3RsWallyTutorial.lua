-- Host bridge for the pinned RS Wally policy. Normal battle commands own hits,
-- PP and RNG; this controller supplies only the cartridge's scripted choices.
local M={};M.__index=M
function M.new(battle)
  local v=require('src.core.GameVersion').get()
  if v~='ruby'and v~='sapphire'then return end
  local spec=assert(battle.data.constants.gen3RsWally,'Native RS tutorial resources required')
  assert(battle.player.mon.species=='ZIGZAGOON'and battle.player.mon.level==7,
    'The RS script must lend Wally his own Zigzagoon')
  -- The script explicitly selects ability 2, including ABILITY_NONE. The
  -- ordinary host resolver falls back to slot 1 for empty second slots.
  local ability=battle.player.def.abilities and battle.player.def.abilities[2]
  battle.player.abilityOverride=ability and ability~=0 and ability~='NONE'and ability or false
  local load=require('compat.gen1-rs.Loader').new(v,{
    ['src.core.game3.battle.commands']={playerAction=function(_,_,slot)return {kind='move',slot=slot}end},
    ['src.core.game3.battle.profile']={of=function()return v end,constants=function()
      return {require=function(_,family,key)
        assert(family=='items'and key=='ITEM_POKE_BALL');return 4
      end}
    end},
  })
  local self=setmetatable({battle=battle,spec=spec,load=load,
    state={kinds={tutorial='wally'},wallyState=0},ui={},events={}},M)
  self.policy=load('src.core.game3.battle.tutorial_wally')
  self.ui._openMoveMenu=function()battle:chooseMenu('fight')end
  battle.demoName=self:text('BattleText_Wally');battle.demoBackPath=spec.images.idle
  self.initialEnemyHP=battle.enemy.mon.hp
  return self
end
function M:text(key)
  local b=self.battle
  return self.load('src.core.game3.scripting.text_ir').toAscii(assert(self.spec.textIR[key]),{
    dialect='rs',battle={[0]=b.player.name,[3]=b.enemy.name,[0x13]=assert(b.data.items.POKE_BALL.name)}})
end
function M:record(kind)
  local b=self.battle
  self.events[#self.events+1]={kind=kind,frame=b.frame,stage=self.state.wallyState,
    playerHP=b.player.mon.hp,enemyHP=b.enemy.mon.hp,pp=b.player.curMoves[1].pp,bagFrame=self.bagTicks}
end
function M:openBag()
  local b=self.battle;local game=b.game
  b.phase='messages';b.afterQueue='menu'
  local function row(id)
    local def=assert(b.data.items[id]);return {id=id,label=def.name,description=def.description,qty=1}
  end
  local function selectSound()require('src.core.Sound').play(b.data,'Press_AB')end
  b:ui(function()
    local bag
    bag=require('src.ui.Gen3BagMenu').new(game,{pocket='ITEM',battle=b,rsTutorial=true,
      noInput=true,rows={row('POTION')},script=function(menu)
        self.bagTicks=(self.bagTicks or 0)+1
        -- Scripted menus do not read pad input; advance their existing RS
        -- opening/pocket animations without invoking inventory callbacks.
        for _,key in ipairs({'rsOpen','rsSwitch','rsDrop'})do
          if menu[key]~=nil then menu[key]=menu[key]+1
            if menu[key]>=(key=='rsDrop'and 10 or 16)then menu[key]=nil end
          end
        end
        if menu.rsBall then menu.rsBall.k=menu.rsBall.k+1;if menu.rsBall.k>=32 then menu.rsBall=nil end end
        if self.bagTicks==102 then
          selectSound();menu.pocket=2;menu.scriptRows={row('POKE_BALL')};menu:rebuild()
          menu.rsSwitch=0;menu.rsBall={k=0,dir=1};menu.rsDrop=0;self:record('bag-pocket-switch')
        elseif self.bagTicks==204 then
          selectSound();self:record('bag-use-menu');menu.script=nil
          local labels=assert(b.data.constants.gen3RsBag.text)
          local data=self.load('src.ui.game3.rs.bag_menu_data')
          game.stack:push(require('src.ui.Gen3ItemMenu').new(game,{columns=1,rsBag=menu,noInput=true,
            entries={{kind='use',label=assert(labels[data.ACTION_TEXT.USE])},
              {kind='cancel',label=assert(labels[data.ACTION_TEXT.CANCEL])}},
            script=function(popup)
              self.bagTicks=self.bagTicks+1
              if self.bagTicks==306 then selectSound();popup:close('use')end
            end,
            onPick=function(kind)
              assert(kind=='use');self:record('bag-use');assert(game.stack:top()==bag)
              game.stack:pop();b:oldManThrow()
            end}))
        end
      end})
    bag.rsOpen=0;self.bagTicks=0;self:record('bag-open');return bag
  end)
end
function M:withdraw()
  local b=self.battle;local damage=self.initialEnemyHP-b.enemy.mon.hp
  local percent=math.floor(damage*100/self.initialEnemyHP)
  local scale=damage<=0 and 0 or percent<=29 and 1 or percent<=69 and 2 or 3
  b.phase='messages';b.afterQueue='menu'
  b:say(self:text('BattleText_ComeBackSingle'..(scale+1)))
  b:act(function()
    self.hideHud=true;self.recallFrame=0;self:record('recall-start')
    require('src.core.Sound').playId(b.data,b.data.constants.gen3BallAnim.sounds.open)
  end)
  table.insert(b.queue,{wait=10}) -- queue dispatch occupies the other two ticks
  b:act(function()
    self.recallFrame=nil;self.hidden=true;b.showPlayerBack=true
    if b.backThrow then b.backThrow.playing=false end
    b:slidePic('back',-96,0,2);self:record('trainer-slide-start')
  end)
  table.insert(b.queue,{wait=46}) -- 48 ticks including dispatch
  b:act(function()self:record('trainer-slide-end')end)
  b:say(self:text('BattleText_WallyBall'))
end
function M:tick()
  if self.recallFrame then self.recallFrame=math.min(12,self.recallFrame+1)end
end
function M:updateMenu()
  local b=self.battle;local ui=self.ui
  if not ui._wally then
    ui._wally={timer=0,sub=0};ui._menuIndex=0;b.menuIndex=1
  end
  self.policy.menuStep(ui,self.state,function()require('src.core.Sound').play(b.data,'Press_AB')end)
  if b.phase=='menu'then b.menuIndex=({[0]=1,[1]=3,[2]=2,[3]=4})[ui._menuIndex or 0] end
  local action=ui._pendingCommand
  if action then
    ui._pendingCommand=nil;self:record(action.kind)
    if action.kind=='move'then b:chooseMove(action.slot)
    elseif action.kind=='wally_throw'then self:withdraw()
    else self:openBag()end
  end
end
return M
