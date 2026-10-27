-- Native RS panel/font/cursor composition. BattleState owns input and rules.
-- Geometry follows the pinned Gen1Recomp RS battle/ui.lua and battle_chrome.lua.
local M={};M.__index=M
local function color(v)
  local function channel(n)return (n*8+math.floor(n/4))/255 end
  return {channel(v%32),channel(math.floor(v/32)%32),channel(math.floor(v/1024)%32),1}
end
function M.available(battle)
  local v=require('src.core.GameVersion').get()
  local s=battle and battle.data and battle.data.constants and battle.data.constants.gen3RsBattlePanel
  return (v=='ruby'or v=='sapphire')and type(s)=='table'and s.format==1 and s.version==v and s
end
function M.new(battle)
  if not M.available(battle)then return end
  local context=require('src.ui.Gen3RsSceneContext').new(battle.game)
  local self=setmetatable({context=context,spec=M.available(battle)},M)
  self.font=context.load('src.ui.game3.frlg_font')
  self.chrome=context.load('src.ui.game3.chrome')
  self.cursor=context.load('src.ui.game3.rs.menu_cursor')
  self.menuColors={fg=color(0x2529),shadow=color(0x675a),bg={0,0,0,0}}
  self.messageColors={fg=color(self.spec.palette[2]),shadow=color(self.spec.palette[9]),bg={0,0,0,0}}
  self.images={};for k,path in pairs(self.spec.images)do self.images[k]=require('src.render.Assets').image(path)end
  return self
end
function M:release()
  if self.context.canvas then self.context.canvas:release();self.context.canvas=nil end
end
function M.handles(battle)
  return not battle.safari and require('src.battle.Gen3Battle').width(battle)==240
end
function M:draw(battle)
  -- Preserve the host's optional wide layout and its special Safari UI.
  if not M.handles(battle)then return false end
  local mode=battle.phase=='menu'and'action'or(battle.phase=='moveSelect'or battle.phase=='mimicSelect')and'moves'or'message'
  local g=love.graphics;local F=self.font
  g.setColor(1,1,1,1);g.draw(self.images[mode],0,112)
  self.chrome.setFrameType(math.max(0,((battle.game.save.options or {}).gen3Frame or 1)-1))
  local function text(value,x,y,colors,opts)
    opts=opts or {};opts.colors=colors or self.menuColors;F.draw(tostring(value or ''),x,y,opts)
  end
  if mode=='action'then
    self.chrome.userFrame(self.chrome._frameType or 0,18,15,11,4)
    local chooser=(battle.menuBattler and battle:menuBattler())or battle.player
    local menu=battle.data.constants.gen3BattleMenu or {};local prompt=menu.prompt
    if battle.rsWally then
      local lines={};for line in battle.rsWally:text("BattleText_WallyMenu"):gmatch("[^\n]+")do lines[#lines+1]=line end
      for i,line in ipairs(lines)do text(line,16,120+(i-1)*16,self.messageColors)end
    elseif not battle.demo then
      text(prompt and prompt[1]or'What will',16,120,self.messageColors)
      text((prompt and prompt[2]or'{MON} do?'):gsub('{MON}',chooser and chooser.name or ''),16,136,self.messageColors)
    end
    local labels=menu.rows or {{'FIGHT','BAG'},{'POKéMON','RUN'}}
    local cursor=(battle.menuIndex or 1)-1
    self.cursor.draw(144+46*(cursor%2),120+16*math.floor(cursor/2),42)
    for i=1,4 do local c=(i-1)%2;local r=math.floor((i-1)/2);text(labels[r+1][c+1],144+46*c,120+16*r)end
  elseif mode=='moves'then
    self.chrome.userFrame(self.chrome._frameType or 0,1,15,20,4)
    self.chrome.userFrame(self.chrome._frameType or 0,23,15,6,4)
    local chooser=(battle.menuBattler and battle:menuBattler())or battle.player
    local moves=battle.phase=='mimicSelect'and battle.mimicMoves or chooser and chooser.curMoves or {}
    local selected=battle.phase=='mimicSelect'and battle.mimicIndex or battle.moveIndex or 1
    local cursor=(battle.moveSwapIndex or selected)-1
    self.cursor.draw(8+80*(cursor%2),120+16*math.floor(cursor/2),72)
    for i=1,4 do
      local mv=moves[i];local def=mv and battle.data.moves[mv.id];local colors=self.menuColors
      if battle.moveSwapIndex and i==selected then colors={fg=color(0x7fe0),shadow=colors.shadow,bg=colors.bg}end
      text(def and def.name or'-',8+80*((i-1)%2),120+16*math.floor((i-1)/2),colors)
    end
    if battle.moveSwapIndex then text(self.spec.switch,184,120)
    else
      local mv=moves[selected];local def=mv and battle.data.moves[mv.id]
      if def then
        text(self.spec.pp,184,120)
        local max=def.pp+(mv.ppUps or 0)*math.floor(def.pp/5)
        text(string.char(0xfc,0x11,2,0xfc,0x14,6)..('%2d/%2d'):format(mv.pp or 0,max),200,120)
        text(require('src.battle.TypeChart').displayName(def.type),184,136)
      end
    end
  elseif battle.phase=='targetSelect'then
    local pick=(battle.targetChoices or {})[battle.targetIndex or 1]
    local user=(battle.menuBattler and battle:menuBattler())or battle.player
    local mine=user and pick and pick.isPlayer==user.isPlayer
    text(require('src.core.Strings')('Attack who?'),10,122,self.messageColors)
    text(pick and(mine and require('src.core.Strings')('%s (ally)',pick.name)or pick.name)or'',10,138,self.messageColors)
  elseif battle.phase=='messages'and(battle.current or battle.animPlaying)then
    for li,line in ipairs(battle.shown or {})do
      local x=10;local y=122+(li-1)*16+(battle.scrollPx or 0)
      for _,code in ipairs(line)do x=x+F.drawGlyph(code,x,y,{colors=self.messageColors})end
    end
    if (battle.msgWaiting or battle.msgPrompt)then self.chrome.promptArrow(224,144,math.floor((battle.frame or 0)/6))end
  end
  return true
end
return M
