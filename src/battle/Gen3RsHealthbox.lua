-- Native RS healthbox text rows: pokeruby battle_interface.c and text.c.
-- Coordinates and control bytes follow the pinned Gen1Recomp healthbox.
local M={}
local Assets=require('src.render.Assets')
local OPTS={font='native_4',textMode=0}
local quads={}
local function tile(path,n,x,y)
  if not quads[n]then quads[n]=love.graphics.newQuad(n%40*8,math.floor(n/40)*8,8,8,320,24)end
  love.graphics.setColor(1,1,1,1);love.graphics.draw(Assets.image(path),quads[n],x,y)
end
local function color(word)
  local function c(n)return math.floor(n*255/31+.5)/255 end
  return {c(word%32),c(math.floor(word/32)%32),c(math.floor(word/1024)%32),1}
end
function M.available(battle)
  local v=require('src.core.GameVersion').get()
  local s=battle and battle.data and battle.data.constants and battle.data.constants.gen3RsHealthbox
  return (v=='ruby'or v=='sapphire')and require('src.import.Gen3RsHealthboxAssets').valid(s,v)and s
end
local function aligned(font,value,width)
  local text=tostring(math.max(0,math.floor(value or 0)))
  return string.char(0xfc,0x13,math.max(0,width-font.measure(text,OPTS)))..text
end
local function row(font,text,x,y,width,colors,fill)
  local g=love.graphics;local sx,sy,sw,sh=g.getScissor()
  if sx then
    local left,top=math.max(sx,x),math.max(sy,y)
    g.setScissor(left,top,math.max(0,math.min(sx+sw,x+width)-left),math.max(0,math.min(sy+sh,y+8)-top))
  else g.setScissor(x,y,width,8)end
  if fill then g.setColor(colors.bg);g.rectangle('fill',x,y,width,8)end
  local opts={font='native_4',textMode=0,colors={fg=colors.fg,shadow=colors.shadow,bg={0,0,0,0}}}
  local ok,why=pcall(font.draw,tostring(text or ''),x,y-8,opts)
  if sx then g.setScissor(sx,sy,sw,sh)else g.setScissor()end
  g.setColor(1,1,1,1);if not ok then error(why,0)end
end
function M.draw(battle,battler,x,y,player,font,paint)
  local s=M.available(battle)
  if not s or battle.safari then return false end
  local compact=battle.isDouble and battle:isDouble()
  local bid=battler.position or(player and 0 or 1)
  local status=battler.shownStatus and battle:statusLabel({status=battler.shownStatus})
  local statusPath=status and s.status[bid+1][status]
  if status and not statusPath then return false end -- custom HUD labels keep the host painter
  local colors={fg=color(s.palette[2]),shadow=color(s.palette[4]),bg=color(s.palette[3])}
  local g=love.graphics;local nameX=x+(player and 16 or 8)
  local blank=Assets.image(s.blank)
  g.setColor(1,1,1,1)
  for tile=0,6 do g.draw(blank,nameX+tile*8,y)end
  row(font,battler.name,nameX,y+8,56,colors,true)
  local mon=battler.mon
  local gender=require('src.pokemon.DayCare').gender(battle.data,mon)
  if (mon.species=='NIDORAN_F'or mon.species=='NIDORAN_M')and not mon.nickname then gender=nil end
  if gender=='male'or gender=='female'then
    local offset=font.measure(battler.name,OPTS)
    if offset<56 then
      local ink={fg=color(s.palette[gender=='male'and 12 or 11]),shadow=colors.bg,bg=colors.bg}
      row(font,gender=='male'and '♂'or '♀',nameX+offset,y+8,56-offset,ink,false)
    end
  end
  local side=player and 'battle.player'or 'battle.enemy'
  local levelX=x+(player and 80 or 72)
  local visible=require('src.ui.LevelDisplay').visible(mon,side,battle.game)
  local level=tostring(mon.level)
  if mon.level~=100 then
    level=string.char(0xfc,0x11,1,0xfc,0x14,4)..':'..string.char(0xfc,0x14,0)..level
  end
  if visible then row(font,level,levelX,y+8,16,colors,true)
  else row(font,'',levelX-8,y+8,24,colors,true)end
  local hp,max=paint.hp,math.max(1,mon.stats.hp)
  local filled=hp>0 and math.max(1,math.floor(math.min(hp,max)*48/max))or 0
  local base=filled>24 and 3 or filled>9 and 47 or 56
  if battler.shownStatus and(not player or compact)then
    tile(s.elements,65,x+(player and 40 or 32),y+16)
  else
    tile(s.elements,1,x+(player and 32 or 24),y+16)
    tile(s.elements,2,x+(player and 40 or 32),y+16)
  end
  for i=0,5 do
    tile(s.elements,base+math.max(0,math.min(8,filled-i*8)),x+(player and 48 or 40)+i*8,y+16)
  end
  if battler.shownStatus then
    g.draw(Assets.image(statusPath),x+(player and 16 or 8),y+(player and not compact and 24 or 16))
  end
  if player and compact then tile(s.elementsExp,117,x+96,y+16)end
  if player and not compact then
    row(font,aligned(font,hp,19)..'/',x+56,y+24,24,colors,true)
    row(font,aligned(font,max,15),x+80,y+24,16,colors,true)
    local fraction=battle.expFraction and battle:expFraction()or 0
    local exp=math.floor(math.max(0,math.min(1,fraction))*64)
    for i=0,7 do tile(s.elementsExp,12+math.max(0,math.min(8,exp-i*8)),x+32+i*8,y+32)end
  end
  g.setColor(1,1,1,1)
  return true
end
return M
