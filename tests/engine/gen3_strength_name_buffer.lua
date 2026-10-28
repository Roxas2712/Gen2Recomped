-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local C=require('src.script.Commands');require('src.script.Gen3Commands')
local V=require('src.core.GameVersion')
local S=require('src.core.SaveSerializer')
local show=require('src.world.Gen3FieldMove');local old=show.show
for _,edition in ipairs{'ruby','sapphire','emerald','firered','leafgreen'}do
  V.set(edition)
  local mon={species='KECLEON',nickname='A%PLAYER',moves={{id='STRENGTH',pp=15}}}
  local save={party={{species='SCEPTILE'},mon},flags={},vars={}}
  local game={save=save,stringBuffers={'old','second','third','fourth'},data={
    pokemon={KECLEON={name='KECLEON'}},constants={gen3FieldEffects={pokecenterHeal=25},
      gen3FieldMoveText={SURF={effect=9}}}}}
  local yielded,resumed,seen=0,0,0
  local ctx={save=save,game=game,g3FieldEffectArgs={[0]=1},runner={
    yield=function()yielded=yielded+1 end,resume=function()resumed=resumed+1 end}}
  local before=S.encode(save)
  show.show=function(g,m,done)
    T.eq(g,game);T.eq(m,mon);T.eq(g.stringBuffers[1],mon.nickname or 'KECLEON',
      'name is available before asynchronous presentation')
    seen=seen+1;done();return true
  end
  C.g3_field_effect(ctx,40)
  T.eq(game.stringBuffers[1],'A%PLAYER','custom spelling remains literal')
  T.eq(game.stringBuffers[2],'second');T.eq(game.stringBuffers[3],'third');T.eq(game.stringBuffers[4],'fourth')
  T.eq(yielded,1);T.eq(resumed,1);T.eq(seen,1);T.eq(S.encode(save),before,'effect only fills transient text')
  mon.nickname=nil;C.g3_field_effect(ctx,40);T.eq(game.stringBuffers[1],'KECLEON','unnicknamed species label')
  show.show=function()return false end
  game.stringBuffers[1]='other move';C.g3_field_effect(ctx,37)
  T.eq(game.stringBuffers[1],'other move','Rock Smash keeps its script-owned buffer')
  game.stringBuffers=nil;C.g3_field_effect(ctx,40);T.eq(game.stringBuffers[1],'KECLEON','first buffer use')
  ctx.g3FieldEffectArgs={[0]=8};game.stringBuffers[1]='retained';C.g3_field_effect(ctx,40)
  T.eq(game.stringBuffers[1],'retained','missing actor never invents a name')
  ctx.overworld={partyKnows=function(_,move)T.eq(move,'STRENGTH');return mon end}
  C.g3_field_effect(ctx,40);T.eq(game.stringBuffers[1],'KECLEON','existing field actor fallback')
end
show.show=old
T.finish('Gen3 native Strength name buffer, callback, edition and save isolation')
