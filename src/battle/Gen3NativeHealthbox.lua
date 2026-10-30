-- FR/LG/E use the pinned native compositor with read-only host battle views.
-- The host remains responsible for battle rules, input, visibility and saves.
local M={}
local Assets=require('src.render.Assets')
local STATUS={'PSN','PAR','SLP','FRZ','BRN'}
function M.available(battle)
  local version=require('src.core.GameVersion').get()
  local hud=battle.data and battle.data.constants and battle.data.constants.gen3BattleHud
  return hud and require('src.import.Gen3NativeHealthboxAssets').valid(hud.native,version)and hud
end
local function context(battle,hud)
  local spec=hud.native;local g=love.graphics;local quads={}
  local function tile(n,x,y,box)
    if not quads[n]then quads[n]=g.newQuad(n%40*8,math.floor(n/40)*8,8,8,320,16)end
    g.setColor(1,1,1,1);g.draw(Assets.image(box and spec.elementsExp or spec.elements),quads[n],x,y)
  end
  local C={}
  function C.drawPlayerBox(x,y)g.setColor(1,1,1,1);g.draw(Assets.image(hud.images.player),x,y)end
  C._playerBox=hud.images.player and Assets.image(hud.images.player)
  function C.drawEnemyBox(x,y)g.setColor(1,1,1,1);g.draw(Assets.image(hud.images.opponent),x,y)end
  function C.drawDoublesBox(player,x,y)
    g.setColor(1,1,1,1);g.draw(Assets.image(player and hud.images.playerDoubles or hud.images.opponentDoubles),x,y)
  end
  C.drawElementTile=tile
  function C.drawHpBar(x,y,hp,max,status)
    local filled=hp>0 and math.max(1,math.floor(math.min(hp,max)*48/math.max(1,max)))or 0
    local base=filled>24 and 3 or filled>9 and 47 or 56
    if status then tile(65,x+8,y)else tile(1,x,y);tile(2,x+8,y)end
    for i=0,5 do tile(base+math.max(0,math.min(8,filled-i*8)),x+16+i*8,y)end
  end
  function C.drawExpBar(x,y,ratio)
    local filled=math.floor(math.max(0,math.min(1,ratio))*64)
    for i=0,7 do tile(12+math.max(0,math.min(8,filled-i*8)),x+i*8,y,true)end
  end
  local face
  local faceLoader={load=function()
    if not face then
      local fg,sh=Assets.image(spec.foreground),Assets.image(spec.shadow)
      local glyphs={}
      for id=0,511 do glyphs[id]=g.newQuad(id%16*16,math.floor(id/16)*16,
        math.max(1,spec.widths[id]),16,256,512)end
      face={name='small',fg=fg,sh=sh,quads=glyphs,widths=spec.widths,height=13,pitch=14,letterSpacing=0}
    end
    return face
  end}
  local function host(side)
    if type(side)=='number'then return battle:battlerAt(side)end
    return side=='player'and battle.player or battle.enemy
  end
  local A={stage=function()return{}end}
  function A.present(side)
    local b=host(side);return{displayStatus=b.shownStatus and battle:statusLabel({status=b.shownStatus})or false,displayLevel=b.mon.level}
  end
  function A.displayHpRatio(side)
    local b=host(side);return b.shownHP/b.mon.stats.hp,b.shownHP,b.mon.stats.hp
  end
  function A.displayExpRatio()return battle:expFraction()end
  local version=require('src.core.GameVersion').get()
  local profile={id=version,ui={},font={faces={small={}},faceLoader='src.ui.game3.healthbox_font'}}
  -- Caught-marker eligibility remains the host's ordinary hook, called by
  -- Gen3Battle after the compositor; the reference must not call it again.
  local st={trainer=true,session={game=battle.game},double=battle:isDouble(),safari=battle.safari~=nil,safariState=battle.safari}
  local Runtime=require('src.mods.Runtime')
  local packages={loaded={['src.core.game3.profile']={forSession=function()return profile end},
    ['src.core.GameVersion']={current=version},['src.core.game3.battle']={_st=st}}}
  local bindings={__package=packages,
    ['src.ui.game3.battle_chrome']=C,['src.ui.game3.healthbox_font']=faceLoader,
    ['src.core.Logger']=require('src.core.Logger'),['src.render.Font']=require('src.render.Font'),
    ['src.core.GameVersion']=require('src.core.GameVersion'),
    ['src.core.game3.battle.state']={displayName=function(b)return b.name end},
    ['src.core.game3.rom_text']={has=function()return false end,plain=function(key)
      return require('src.battle.Gen3Safari').text(battle,key=='gText_SafariBalls'and'balls'or'left')
    end},
    ['src.core.game3.battle.profile']={get=function()return{strings={safariBallsLeft='left'}}end},
    ['src.core.game3.battle.mod_registries']={},['src.core.game3.battle.anim']=A,
    ['src.mods.Runtime']={wantsHook=function(name)
      return name=='pokemon.level_visible'or Runtime.wantsHook(name)
    end},
    ['src.ui.LevelDisplay']={visible=function(_,side)
      return require('src.ui.LevelDisplay').visible(st.hostBattler.mon,side,battle.game)
    end},
    ['src.core.game3.profile']=packages.loaded['src.core.game3.profile'],
    ['src.ui.game3.summary_chrome']={drawStatusIcon=function(x,y,id)
      local path=hud.status[STATUS[id]]
      if path then g.setColor(1,1,1,1);g.draw(Assets.image(path),x,y)end
    end},
    ['src.core.game3.summary_data']={statusAilment=function(mon)
      for id,key in ipairs(STATUS)do if mon.status==key then return id end end;return 0
    end},
  }
  local load=require('compat.gen1-rs.Loader').new('emerald',bindings)
  return{compositor=load('src.core.game3.battle.healthbox'),state=st}
end
-- Older Kanto imports contain battler anchors but no healthbox switch
-- immediates. The same native compositor that paints their boxes supplies
-- those centres; absence of the optional import must not hide all four.
function M.center(battle,id)
  local hud=M.available(battle);if not hud then return end
  local ctx=battle.nativeHealthbox
  if not ctx then ctx=context(battle,hud);battle.nativeHealthbox=ctx end
  ctx.state.double=battle:isDouble()
  local c=ctx.compositor.center(ctx.state,id)
  if c then return c.x,c.y end
end
function M.draw(battle,battler,x,y,player,safari)
  local hud=M.available(battle)
  if not hud or battle.safari and player and not safari then return false end
  if battler.shownStatus then
    local key=battle:statusLabel({status=battler.shownStatus})
    if not hud.status or not hud.status[key]then return false end
  end
  local compact=battle:isDouble()
  if compact and not(hud.images.playerDoubles and hud.images.opponentDoubles)then return false end
  local ctx=battle.nativeHealthbox
  if not ctx then ctx=context(battle,hud);battle.nativeHealthbox=ctx end
  ctx.state.double=battle:isDouble()
  ctx.state.safari=battle.safari~=nil;ctx.state.safariState=battle.safari
  local gender=require('src.pokemon.DayCare').gender(battle.data,battler.mon)
  local def=battle.data.pokemon[battler.mon.species]
  local mon=battler.mon
  ctx.state.hostBattler=battler
  local status=battler.shownStatus and battle:statusLabel({status=battler.shownStatus})
  local view={name=battler.name,mon={species=def.index,name=def.name,nickname=mon.nickname,
    level=mon.level,hp=mon.hp,maxHp=mon.stats.hp,status=status,
    gender=gender=='male'and'M'or gender=='female'and'F'or'U'}}
  local id=battler.position or(player and 0 or 1)
  local center=compact and ctx.compositor.center(ctx.state,id)
    or(player and ctx.compositor.PLAYER_CENTER or ctx.compositor.ENEMY_CENTER)
  local ok,why=require('src.render.GraphicsScope').call(function()
    ctx.compositor.draw(compact and id or(player and'player'or'enemy'),view,
      {st=ctx.state,ox=x-(center.x-32),oy=y-(center.y-16)})
  end)
  if not ok then error(why,0)end
  return true
end
function M.drawSafari(battle,x,y)
  if not battle.gen3Safari then return false end
  return M.draw(battle,battle.player,x,y,true,true)
end
return M
