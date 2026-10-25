-- Compatibility spellings, kept separate from the loader's execution policy.
-- Only interchangeable native objects belong in ALIASES. Unsupported modules
-- fail at import with an actionable diagnostic instead of a misleading facade.
local C = {}
C.ALIASES = {
  ['src.world.gen2.WorldAPI'] = 'src.world.WorldAPI',
  ['src.world.gen2.Follower'] = 'src.world.OptionalFollower',
}
C.UNAVAILABLE = {
  ['src.import.pmd.Sprite'] = { 'mystery_dungeon_follower' },
  ['src.world.game3.Follower'] = { 'mystery_dungeon_follower' },
  ['src.core.gen2.Unown'] = { 'mystery_dungeon_follower' },
  ['src.core.game3.pokemon'] = { 'mystery_dungeon_follower' },
  ['src.core.game3.player'] = { 'mystery_dungeon_follower' },
}
function C.unavailable(name)
  local consumers = C.UNAVAILABLE[name]
  if not consumers then return nil end
  return ('Compatibility module %s is unavailable in this engine; affected mods: %s')
    :format(name, table.concat(consumers, ', '))
end
return C
