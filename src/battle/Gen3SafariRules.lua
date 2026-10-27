-- Edition-specific Safari arithmetic from the retained, byte-exact reference.
-- This module owns no save, UI or battle queue; callers supply native RNG draws.
local M={}
local SUPPORTED={ruby=true,sapphire=true,emerald=true,firered=true,leafgreen=true}
local rules
local function reference()
  if not rules then
    rules=require('compat.gen1-rs.Loader').new('emerald',{
      ['src.core.game3.battle.capabilities']={},['src.core.game3.battle.oak_advice']={},
      ['src.core.game3.battle.link_guard']={fallback=function()error('Native Safari RNG is required')end},
    })('src.core.game3.battle.rules').safari
  end
  return rules
end
function M.isHoenn(version)return version=='ruby'or version=='sapphire'or version=='emerald'end
function M.actions(version)
  assert(SUPPORTED[version],'Unknown native Safari edition')
  return M.isHoenn(version)and{'ball','pokeblock','go_near','run'}or{'ball','bait','rock','run'}
end
function M.new(version,catchRate,fleeRate,balls,spec)
  assert(SUPPORTED[version],'Unknown native Safari edition')
  local R=reference();local sf
  if M.isHoenn(version)then
    assert(spec and spec.escapeFactor and spec.tables,'Missing native Hoenn Safari tables')
    sf=R.newStateRse(catchRate,{balls=balls or R.BALLS,escapeFactor=spec.escapeFactor})
  else sf=R.newState(catchRate,fleeRate)end
  sf.balls=math.max(0,math.floor(balls or R.BALLS));sf.edition=version
  return sf
end
local function raw(rng)
  local n=rng()
  assert(type(n)=='number'and n>=0 and n<=65535 and n%1==0,'Safari requires one native unsigned 16-bit draw')
  return n
end
function M.throwBait(sf,rng)
  assert(not sf.rse,'Hoenn uses Pokeblocks')
  reference().throwBait(sf,function()return raw(rng)%5 end)
end
function M.throwRock(sf,rng)
  assert(not sf.rse,'Hoenn uses Go Near')
  reference().throwRock(sf,function()return raw(rng)%5 end)
end
function M.goNear(sf,spec)
  assert(sf.rse,'Kanto uses rocks')
  return reference().goNear(sf,assert(spec.tables))
end
function M.throwPokeblock(sf,spec,nature,block)
  assert(sf.rse,'Kanto uses bait')
  local R=reference();local tables=assert(spec.tables)
  local gain=R.pokeblockGain(tables,nature,block.flavours)
  return R.throwPokeblock(sf,tables,gain),gain
end
function M.catchRate(sf)return reference().ballCatchRate(sf)end
function M.fleePercent(sf)return reference().fleeRate(sf)end
function M.flees(sf,rng)return raw(rng)%100<M.fleePercent(sf)end
function M.watchStep(sf)return reference().watchStep(sf)end
return M
