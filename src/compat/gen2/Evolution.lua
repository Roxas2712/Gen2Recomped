-- Legacy queries delegate to the same evolution registry used by native
-- level-ups and stones. This module does not apply or consume an evolution.
local Native=require('src.pokemon.Evolution')
local E={}
local bound,edition
function E.useRegistry(data)
  bound,edition=data,require('src.core.GameVersion').get()
end
function E.checkMon(data,mon,opts)
  opts=opts or {}
  local species,entry=Native.pendingFor({data=data,save=opts.save or {}},mon,
    {kind=opts.item and 'item' or 'levelup',item=opts.item})
  if not species then return nil end
  return entry
end
function E.markPokedex(save,id,data)
  if not data and edition==require('src.core.GameVersion').get() then data=bound end
  if data then id=require('src.core.Gen2SpeciesNames').registryId(data.pokemon,id)end
  save.pokedex=save.pokedex or {seen={},owned={}}
  save.pokedex.seen=save.pokedex.seen or {}
  save.pokedex.owned=save.pokedex.owned or {}
  save.pokedex.seen[id],save.pokedex.owned[id]=true,true
end

-- Animation arithmetic adapted from Gen1Recomp 535a5ec0; GPLv3 plus
-- Additional Terms, retained in compat/gen1-gsc/LICENSE.MD.
function E.speciesName(data, species)
  local rows = data and data.pokemon
  local id = rows and require('src.core.Gen2SpeciesNames').registryId(rows, species)
  local def = rows and rows[id or species]
  return def and def.name or species or "?"
end
-- EvolveAfterBattle prints EvolvingText ("What? <NICK> is evolving!") and then
-- `ld c, 50 / call DelayFrames` before it clears the top 12 rows and starts
-- the animation.  The text box itself is NOT cleared, so that line stays under
-- the pic for the whole animation.
E.EVOLVING_FRAMES = 50

-- The old mon's cry, then MUSIC_EVOLUTION, then `ld c, 80 / call DelayFrames`
-- before the palette goes to PREDEFPAL_BLACKOUT and the flashing starts.
E.MUSIC_FRAMES = 80

-- Each .ReplaceFrontpic ends in WaitBGMap, i.e. one frame per pic swap, and a
-- "flash" is two of them: the new stage's tiles, then back to the old.
E.SWAP_FRAMES = 1

-- .PlayEvolvedSFX: 32 frames spawning balls of light (two every other frame,
-- 32 in all) and then `ld c, 32` more frames animating them out.
E.BALL_SPAWN_FRAMES = 32
E.BALL_TAIL_FRAMES = 32

-- After the animation: CongratulationsYourPokemonText, EvolvedIntoText,
-- MUSIC_NONE, SFX_CAUGHT_MON, WaitSFX, then `ld c, 40 / call DelayFrames`.
E.CONGRATS_FRAMES = 40

-- `lb bc, 1, 16` then, per round, `inc b / dec c / dec c`: eight rounds of
-- "hold the old pic for c frames (watching for B), then alternate the two pics
-- b times".  The hold shrinks by two frames a round while the alternation gets
-- one flash longer, which is what makes the flicker accelerate.
function E.flashRounds()
  local rounds = {}
  local flashes, wait = 1, 16
  while wait > 0 do
    rounds[#rounds + 1] = { wait = wait, flashes = flashes }
    flashes = flashes + 1
    wait = wait - 2
  end
  return rounds
end

-- How many frames the flashing half of the animation takes, end to end.
function E.flashFrames()
  local total = 0
  for _, round in ipairs(E.flashRounds()) do
    total = total + round.wait + round.flashes * 2 * E.SWAP_FRAMES
  end
  return total
end

-- .GenerateBallOfLight spawns two balls on every EVEN jumptable index over the
-- 32 spawn frames, 180 degrees apart, and AnimSeq_RevealNewMon walks each one
-- out from radius $10 in steps of $08 until it passes $80.
E.BALL_RADIUS_START = 0x10
E.BALL_RADIUS_STEP = 0x08
E.BALL_RADIUS_END = 0x80

-- depixel 9, 11 -- Y TILE FIRST -- and an OAM object draws at (x - 8, y - 16),
-- so the balls come out of (80, 56), just under the middle of the 7x7 pic box
-- at hlcoord 7, 2.
E.BALL_ORIGIN_X = 11 * 8 - 8
E.BALL_ORIGIN_Y = 9 * 8 - 16

return E
