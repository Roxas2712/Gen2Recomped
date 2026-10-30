-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path = './?.lua;./?/init.lua;' .. package.path
local T = require('tests.modkit')
local Schemas = require('src.mods.Schemas')
local f = Schemas.f
local map = { value = f.map(f.union{ f.str, f.int(0) }, f.bool) }
T.check(Schemas.check(map, 'probe', 'keys', {name=true,[3]=false}, 'override'), 'composite key validators accept either branch')
local valid, why = Schemas.check(map, 'probe', 'keys', {[-1]=true}, 'override')
T.eq(valid, nil, 'invalid composite key refused')
T.check(why and why:find('<key>', 1, true), 'key failure is attributed')
local called, accepted, problem = pcall(Schemas.check, {value={}}, 'probe', 'bad', {}, 'override')
T.check(called and accepted == nil and type(problem) == 'string', 'malformed validator becomes diagnostic')
local mode
T.check(Schemas.check({value=f.any,extra=function(_,_,m)mode=m end},'probe','mode',1,'base'), 'extra validator succeeds')
T.eq(mode,'base','extra receives validation mode')
local cry = Schemas.REGISTRIES.cries
for _, gen in ipairs({1,2,3}) do
  local shape = Schemas.forGeneration(cry,gen)
  for _, n in ipairs({255,256,65535,65536,-1,1.5,math.huge,0/0}) do
    local ok = Schemas.check(shape,'cries','PROBE',{header={},pitch=n,length=n},'override')
    T.eq(ok == true, n >= 0 and n%1 == 0 and n <= (gen == 2 and 65535 or 255), 'generation-specific cry bounds')
  end
end
T.eq(Schemas.check(cry,'cries','PROBE',{header={},pitch=256,length=1},'override'),nil,'Gen2 selection never mutates shared schema')
local Version = require('src.core.GameVersion')
local Cap = require('src.mods.Capabilities')
for _, version in ipairs({'red','gold','crystal','firered','emerald'}) do
  T.check(Cap.supports('world','startWildBattle',version),'native battle world capability present')
  T.eq(Cap.supports('hooks','map.occupancy_allowed',version),Version.generation(version)==1,'story hook capability is generation-specific')
  if Version.generation(version)==3 then
    T.check(Cap.supports('hooks','battle.enemy_switch_or_item',version),'Gen3 existing native decision producer advertised')
    T.check(Cap.supports('events','happiness.changed',version),'Gen3 existing friendship producer advertised')
  end
end
-- Verify actual consumers, including cueing before transition and retaining
-- the original role used by victory selection. Audio device is the seam.
local Battle = require('src.battle.BattleState')
local Music = require('src.core.Music')
local play, cue = Music.play, Music.playBattle
local observed
Music.play = function(_,song,_,context) observed={song,context};return true end
local battle = setmetatable({kind='wild',data={pokemon={PROBE={battleTheme='Theme_Probe'}},
  audio={battle={wild='Default'}}},enemy={mon={species='PROBE'}},musicKind='wild'}, {__index=Battle})
battle:playBattleTheme()
T.eq(observed[1],'Theme_Probe','native battle theme reaches Music.play')
T.eq(observed[2].kind,'wild','theme does not change native role')
battle.trainer={id='TRAINER_PROBE',battleTheme='Trainer_Theme'}
battle:playBattleTheme()
T.eq(observed[1],'Trainer_Theme','trainer override precedes wild species')
T.eq(observed[2].trainerId,'TRAINER_PROBE','cue retains trainer identity')
battle.trainer=nil;battle.data.pokemon.PROBE.battleTheme=nil
battle:playBattleTheme();T.eq(observed[1],'Default','vanilla role remains the fallback')
Music.play=play;Music.playBattle=cue
Version.set('crystal')
battle.data.pokemon.PROBE.battleScaleFront=0.5
battle.data.pokemon.PROBE.battleScaleBack=3
T.eq(Battle.resolveBattleScale(battle.data,'front','probe.png','PROBE'),0.5,'native front pic consumer uses scale')
T.eq(Battle.resolveBattleScale(battle.data,'back','probe.png','PROBE'),3,'native back pic consumer uses scale')
battle.data.battle_sprite_scales={override={path='probe.png',scale=2}}
T.eq(Battle.resolveBattleScale(battle.data,'front','probe.png','PROBE'),2,'existing image-level override keeps precedence')
for _, version in ipairs({'crystal','red','gold'}) do
  Version.set(version)
  local data=T.fixtures.fresh()
  data.audio=data.audio or {};data.audio.cries=data.audio.cries or {}
  data.audio.cries.PROBE={header={},pitch=1,length=1}
  local run=T.sdk.loadMods({'mods/cry_probe'},{data=data,fs=T.sdk.memfs({
    ['mods/cry_probe/manifest.json']=[[{"id":"cry_probe","name":"Cry probe","version":"1.0.0","api":2,"entry":"main.lua"}]],
    ['mods/cry_probe/main.lua']=[[
      local mod=...
      assert(mod.contentFormat=='native')
      mod.content.cries:patch('PROBE',{pitch=65535,length=256})
    ]],
  })})
  local gen2=Version.generation(version)==2
  T.eq(#run.errors,gen2 and 0 or 1,'real native loader selects cry contract per session')
  T.eq(data.audio.cries.PROBE.pitch,gen2 and 65535 or 1,'accepted patch or failed-entry rollback reaches native audio')
  if gen2 then
    local request=require('src.core.ChipAudio').effectSpec(data,'cry',data.audio.cries.PROBE)
    T.eq(request.options.frequencyOffset,65535,'16-bit pitch reaches actual synth request')
    T.eq(request.options.cryLength,256,'16-bit length reaches actual synth request')
  end
  run.release()
end
T.finish('mod priority schema and native consumers')
