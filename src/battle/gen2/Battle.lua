-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- The live Gen2 model boundary of the shared native controller. This is not
-- an alias to the screen and does not construct or advance a second battle.
local Runtime = require('src.mods.Runtime')
local Model = {}
-- IsGymLeader's cartridge list includes the Elite Four, Champion and Red,
-- then falls through into the eight Kanto leaders. Keep this public source
-- predicate distinct from the native badge/Pikachu companion marker.
Model.KANTO_GYM_LEADER_CLASSES = {
  BROCK=true, MISTY=true, LT_SURGE=true, ERIKA=true,
  JANINE=true, SABRINA=true, BLAINE=true, BLUE=true,
}
Model.GYM_LEADER_CLASSES = {
  FALKNER=true, WHITNEY=true, BUGSY=true, MORTY=true,
  PRYCE=true, JASMINE=true, CHUCK=true, CLAIR=true,
  WILL=true, BRUNO=true, KAREN=true, KOGA=true, CHAMPION=true, RED=true,
}
for class in pairs(Model.KANTO_GYM_LEADER_CLASSES) do
  Model.GYM_LEADER_CLASSES[class] = true
end
function Model.isGymLeader(class)
  return class ~= nil and Model.GYM_LEADER_CLASSES[class] == true
end
function Model.isKantoGymLeader(class)
  return class ~= nil and Model.KANTO_GYM_LEADER_CLASSES[class] == true
end
local screens = setmetatable({}, { __mode = 'kv' })
local ended = setmetatable({}, { __mode = 'k' })

local function owner(model)
  return assert(screens[model], 'native Gen2 model is not attached to a battle')
end

function Model.bind(model, screen)
  screens[model] = screen
  rawset(model, '_nativeRandom', function(n) return owner(model).rng(n) - 1 end)
  -- Source GSC's LOVE-style view normalizes missing/small bounds and reversed
  -- ranges. Resolve the current native function at invocation, not at bind:
  -- link setup and scoped native owners can replace that function later.
  rawset(model, '_nativeLoveRng', function(lo, hi)
    local rng = owner(model).rng
    if hi == nil then return rng(math.max(1, lo or 1)) end
    if hi < lo then lo, hi = hi, lo end
    return rng(lo, hi)
  end)
  return model
end

function Model:roller()
  owner(self)
  local roller = rawget(self, '_nativeRoller')
  if not roller then
    -- BattleRandom's zero-based domain over the same existing stream.
    -- Keep the closure on its transient model, never in a global weak-key
    -- cache whose value could root the model on LuaJIT.
    local random = rawget(self, '_nativeRandom')
    roller = function(n) return random(n) end
    rawset(self, '_nativeRoller', roller)
  end
  return roller
end

local function active(screen, mon)
  if screen.player == mon or screen.enemy == mon then return mon end
  if screen.player and screen.player.mon == mon then return screen.player end
  if screen.enemy and screen.enemy.mon == mon then return screen.enemy end
end

local statNames={specialAttack='spatk',specialDefense='spdef'}
local stageAliases={__index=function(t,k)local native=statNames[k];if native then return rawget(t,native)end end,
  __newindex=function(t,k,v)rawset(t,statNames[k]or k,v)end}
function Model:stageTables()
  local screen=owner(self)
  return setmetatable({}, {__index=function(_,side)
    local b=(side=='player' or side=='enemy')and screen[side]
    if b and b.stages then
      if getmetatable(b.stages)==nil then setmetatable(b.stages,stageAliases)end
      return b.stages
    end
  end})
end
local volatileNames={substitute='substituteHP',protect='protecting',mist='mist',
  confusion='confused',confusionTurns='confusionTurns',flinch='flinched',
  -- Canonical source GSC fields must drive the actual shared controller.
  confuseCount='confusedTurns',flinched='flinched',endure='enduring',
  recharge='mustRecharge',protectCount='protectRun',
  focusEnergy='focusEnergy',xAccuracy='xAccuracy'}
function Model:volatile(mon)
  local screen=owner(self)
  local b=assert(active(screen,mon),'volatile state requires an active battler')
  -- A global weak-key cache still roots its battlers on LuaJIT when the
  -- value's closures retain their key. Keep views on the transient model,
  -- never on a serialized battler or party mon, and retire withdrawn owners.
  local views=rawget(self,'_nativeVolatileViews')
  if not views then views={};rawset(self,'_nativeVolatileViews',views)end
  for previous in pairs(views)do
    if previous~=screen.player and previous~=screen.enemy then views[previous]=nil end
  end
  if not views[b] then
    local extensions={}
    views[b]=setmetatable({}, {
      __index=function(_,key)local field=volatileNames[key];if field then return b[field] end;return extensions[key]end,
      __newindex=function(_,key,value)local field=volatileNames[key];if field then b[field]=value else extensions[key]=value end end,
    })
  end
  return views[b]
end

function Model:battlerName(mon)
  local b=active(owner(self),mon)
  return b and b.name or mon and (mon.nickname or mon.species) or ''
end
function Model:battlerTypes(mon)
  local b=active(owner(self),mon)
  return b and b.curTypes or (self:speciesDef(mon)or {}).types or {}
end
function Model:effectiveSpeed(mon)
  return require('src.battle.TurnOrder').effectiveSpeed(assert(active(owner(self),mon)),owner(self))
end
function Model:movePriority(id)
  return require('src.battle.Gen2MovePriority').get(self:moveDef(id))
end
function Model:markMissed()
  return owner(self):markMissed()
end
function Model:emit(event)
  assert(type(event)=='table','battle event must be a table')
  if event.kind=='message' then return owner(self):sayNext(event.text) end
  error('unsupported source battle event: '..tostring(event.kind),2)
end
function Model:accuracyRoll(move,user,target,raw)
  local screen=owner(self)
  return screen:accuracyRoll(move,assert(active(screen,user)),assert(active(screen,target)),raw)
end
function Model:changeStage(target,stat,delta)
  local screen=owner(self)
  local b=assert(active(screen,target),'stage change requires an active battler')
  stat=statNames[stat]or stat
  local before=b.stages[stat]or 0
  local messages=require('src.battle.MoveEffects').changeStage(screen,b,stat,delta,false)
  for _,text in ipairs(messages)do screen:sayNext(text)end
  return (b.stages[stat]or 0)~=before
end
function Model:changeStageAgainstMist(user,target,stat,delta)
  local screen=owner(self)
  local b=assert(active(screen,target))
  if user~=target and delta<0 and b.mist then
    self:emit({kind='message',text=self:battlerName(target).." is protected by MIST."})
    return false
  end
  return self:changeStage(target,stat,delta)
end

function Model:moveDef(move)
  return owner(self):moveDef(move)
end

function Model:speciesDef(mon)
  return mon and self.data.pokemon and self.data.pokemon[mon.species] or nil
end

-- Raw native battle statistics, before stages, badges, status or held items.
-- Those modifiers remain in the actual damage/order owners and run once.
-- A caller's temporary shadow mon uses its own stats without changing a party
-- member. Active Transform statistics remain on the existing native wrapper.
function Model:battleStat(mon, key)
  local screen = screens[self]
  local battler = screen and active(screen, mon)
  local stats = battler and battler.curStats or mon and mon.stats
  return stats and stats[statNames[key]or key]
end

function Model:sideOf(mon)
  local screen = owner(self)
  local battler = active(screen, mon)
  if battler then return battler.isPlayer and 'player' or 'enemy' end
end

-- Finish notification is owned by the native result path. Presentation stays
-- on the native queue; completeBattle/finish perform its actual screen return.
-- Existing native event consumers retain the screen in `battle`; the distinct
-- live model is also provided explicitly. No second save/party snapshot exists.
function Model:endBattle(outcome, details)
  local screen = owner(self)
  -- Link/spectator owners also publish ended/hostWin/guestWin, and a native
  -- extension may carry its own string. Do not narrow the owner's protocol.
  assert(type(outcome) == 'string' and outcome ~= '', 'invalid native Gen2 battle outcome')
  if ended[self] then return false end
  -- Native finish has an event-only fallback when its owner has no result.
  -- Do not persist that fallback into a link owner's different end protocol.
  if not (details and details.nativeNotification) then screen.result = outcome end
  screen:restoreMimicked(screen.player)
  screen:restoreMimicked(screen.enemy)
  ended[self] = true
  local event = { battle=screen, model=self, result=outcome }
  if details and details.skipped then event.skipped = true end
  Runtime.emit('battle.ended', event)
  return true
end

return Model
