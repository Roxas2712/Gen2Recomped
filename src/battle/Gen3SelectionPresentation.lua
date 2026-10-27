-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Selection motion belongs to the native battle frame, never to a UI query.
-- Cartridge reference: pokefirered ce6406d8, battle_main DoBounceEffect /
-- SpriteCB_BounceEffect / SpriteCB_ShowAsMoveTarget / SpriteCB_BlinkVisible.
local M={}
local function selection(b)
 if b.phase=='menu' or b.phase=='moveSelect' then return 'choose' end
 if b.phase=='targetSelect' then return 'target' end
end
local function target(b)
 return b.phase=='targetSelect' and (b.targetChoices or{})[b.targetIndex or 1] or nil
end
local function live(b)
 local c=b._selectionPresentation
 if c and c.refs[1]==b.data and c.refs[2]==b.game.save then return c end
end
local function bind(previous,battler,delta,frame)
 if not battler then return nil end
 if previous and previous.battler==battler and previous.delta==delta then return previous end
 return {battler=battler,delta=delta,from=frame}
end
function M.update(b)
 local mode=selection(b)
 if not mode or not(b.game and b.game.save and b.data and b.menuBattler) then b._selectionPresentation=nil;return end
 local c=live(b)
 if not c then c={refs=setmetatable({b.data,b.game.save},{__mode='v'})};b._selectionPresentation=c end
 local frame=b.frame or 0
 local actor=b:menuBattler();local aimed=target(b)
 c.mon=bind(c.mon,actor,7,frame)
 local highlighted=actor;if mode=='target' then highlighted=aimed end
 c.hb=bind(c.hb,highlighted,mode=='target' and 15 or 7,frame)
 if aimed~=c.target then c.target=aimed;c.targetFrom=frame end
end
function M.hidden(b,battler)
 local c=live(b);local aimed=target(b)
 return c~=nil and battler~=nil and aimed==battler and c.target==battler
  and math.floor(((b.frame or 0)-c.targetFrom)/8)%2==1 or false
end
function M.offset(b,kind,battler)
 local c=live(b);if not c or not selection(b) then return 0 end
 local row=c[kind]
 if not row or row.battler~=battler then return 0 end
 local expected=b:menuBattler()
 if kind=='hb' and selection(b)=='target' then expected=target(b) end
 local delta=kind=='hb' and selection(b)=='target' and 15 or 7
 if expected~=battler or row.delta~=delta then return 0 end
 local sine=b.data.constants and b.data.constants.gen3BattleAnimSine
 local age=math.max(0,(b.frame or 0)-row.from)
 local index=((kind=='hb' and 128 or 192)+age*row.delta)%256
 local value=sine and sine[index]
 -- No imported sine table means no verified displacement. Do not substitute
 -- floating-point trigonometry for the cartridge's signed integer shift.
 if type(value)~='number' then return 0 end
 return math.floor(value/256)+1
end
return M
