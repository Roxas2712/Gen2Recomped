-- Native battler data, extracted from BattleState.makeBattler.
-- Existing engine authors' rights and licences remain in effect (NOTICE.md).
-- Data/presentation boundary contributions by Roxas2712; see
-- LICENSE-ROXAS2712.md. This module allocates no picture or animation resource.
local Version = require('src.core.GameVersion')
local Forms = require('src.pokemon.Gen4Forms')
local Held = require('src.battle.HeldItemRead')
local Gen2 = require('src.battle.Gen2BattleRead')
local Battler = {}

function Battler.new(data, mon, isPlayer, save, battle)
  if Version.isGen2() then require('src.pokemon.Gen2MonFields').bind(data,mon) end
  local def = Forms.definition(data, mon)
  local badgeBoosts = data.constants and data.constants.badgeBoosts
  local badges
  if isPlayer and save then
    -- Gen 1 badge stat boosts (x9/8); the badge set follows the merged
    -- badgeBoosts rows so a retuned list changes what gets baked in.
    badges = {}
    for _, row in ipairs(badgeBoosts or require('src.battle.Damage').BADGE_BOOSTS) do
      if save.inventory[row.badge] then badges[row.badge] = true end
    end
  end
  local battler = {
    mon = mon,
    def = def,
    name = mon.nickname or def.name,
    -- Presentation species may later change for Transform or a Tower ghost;
    -- mon.species remains the Pokemon's identity in the save.
    species = mon.species,
    isPlayer = isPlayer,
    badges = badges,
    badgeBoosts = badgeBoosts,
    statuses = data.statuses,
    -- Registry views, not copies: a consumed berry and its nature lookup
    -- must see the live merged records throughout the battle.
    items = data.items,
    natures = data.constants and data.constants.natures,
    shownHP = mon.hp,
    -- HUDs catch up at native refresh edges, not during a move's mutation.
    shownStatus = mon.status,
    toxicCounter = Version.isGen3() and mon.status == 'PSN' and mon.toxic == true and 1 or nil,
    -- A sleep applied outside battle keeps its own remaining count.
    sleepTurns = (mon.status == 'SLP' and mon.sleepTurns) or nil,
    stages = {},
    -- Transform/Conversion/Mimic replace these transient views.
    curStats = mon.stats,
    curTypes = def.types,
    curMoves = mon.moves,
  }
  if Version.isGen2() then require('src.pokemon.Stats').trackBattler(battler) end
  return Gen2.bind(Held.bind(battler, battle), battle)
end

return Battler
