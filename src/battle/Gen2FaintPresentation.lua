-- Native GSC faint presentation, adapted from Gen1Recomp's
-- src/ui/gen2/BattleState.lua. Existing provenance remains under NOTICE.md.
-- Native-controller integration: Roxas2712 (LICENSE-ROXAS2712.md).
-- The existing FX tick owns this slide. No HP, PP, EXP or turn resolution.
local Sound = require('src.core.Sound')
local Faint = {}
local WAIT_CAP = 180
local function busy()
  local journal = package.loaded['src.core.SuspendJournal']
  if journal then return journal.sample('battle.faintSfx', Sound.sfxBusy) end
  return Sound.sfxBusy()
end

local function battler(screen, side, mon)
  assert(side == 'player' or side == 'enemy', 'invalid native Gen2 faint side')
  local b = assert(screen[side], 'native Gen2 faint has no active battler')
  assert(not mon or b.mon == mon, 'stale native Gen2 faint event target')
  return b
end

function Faint.start(screen, event)
  local b = battler(screen, event.side, event.mon)
  local slide = {side=event.side, frames=0, battler=b, mon=b.mon}
  screen.faintSlide = slide
  if busy() then slide.wait = 0
  else screen:faintSound(event.side) end
end

function Faint.step(screen)
  local slide = screen.faintSlide
  if not slide then return end
  battler(screen, slide.side, slide.mon)
  if slide.wait then
    if busy() and slide.wait < WAIT_CAP then
      slide.wait = slide.wait + 1
      return
    end
    slide.wait = nil
    screen:faintSound(slide.side)
  end
  slide.frames = slide.frames + 1
  if slide.frames >= screen:faintSlideFrames(slide.side) then
    slide.battler.fainted = true
    screen.picHidden = screen.picHidden or {}
    screen.picHidden[slide.side] = true
    if slide.side == 'enemy' then
      screen:playSfx('Sfx_Faint')
      screen.showEnemyHud = false
    else screen.showPlayerHud = false end
    screen.faintSlide = nil
  end
end

function Faint.owns(screen, b)
  local slide = screen.faintSlide
  return slide and slide.battler == b and slide.mon == b.mon or false
end

function Faint.install(Screen)
  Screen.PLAYER_PIC_TILES = 6
  Screen.ENEMY_PIC_TILES = 7
  function Screen:faintSlideFrames(side)
    assert(side == 'player' or side == 'enemy', 'invalid native Gen2 faint side')
    return (side == 'player' and Screen.PLAYER_PIC_TILES or Screen.ENEMY_PIC_TILES) * 2
  end
  function Screen:faintSink(side)
    local slide = self.faintSlide
    return slide and slide.side == side and math.floor(slide.frames / 2) * 8 or 0
  end
  function Screen:faintSound(side)
    if side == 'enemy' then self:playSfx('Sfx_Kinesis')
    elseif side == 'player' then self:playCry(self:activeMon('player'))
    else error('invalid native Gen2 faint side') end
  end
end
return Faint
