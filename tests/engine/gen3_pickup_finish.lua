-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local V=require('src.core.GameVersion')
for _,edition in ipairs{'ruby','sapphire','firered','leafgreen','emerald'}do
 local f=require('tools.battle-source-runtime.fixture').new(edition)
 local battle=f.fresh('TACKLE').battle
 local mon=battle.player.mon
 f.data.pokemon.CHARMANDER.abilities={'PICKUP'}
 f.data.items.OWN_POTION={id='OWN_POTION',index=13,name='POTION'}
 local record={schema=1,edition=edition,romSha1=V.info(edition).sha1,
   style=edition=='emerald'and'level'or'fixed',items={},thresholds={}}
 if record.style=='fixed'then
  local n=(edition=='firered'or edition=='leafgreen')and 16 or 10
  for i=1,n do record.items[i]=13;if i<n then record.thresholds[i]=i*5 end end
 else
  record.common={};record.rare={};record.thresholds={30,40,50,60,70,80,90,94,98}
  for i=1,18 do record.common[i]=13 end
  for i=1,11 do record.rare[i]=13 end
 end
 f.data.constants.gen3Pickup=record
 local calls=0;battle.rng=function(lo,hi)
  calls=calls+1;T.eq(lo,0);T.eq(hi,65535);return 0
 end
 battle.result='win';f.game.stack:push(battle)
 battle:finish()
 T.eq(mon.item,'OWN_POTION','ordinary '..edition..' win runs Pickup through actual battle teardown')
 T.eq(calls,2,'one chance roll followed by one table roll')
 mon.item=nil;battle:finish()
 T.eq(mon.item,nil,'re-entering teardown cannot award a second item')
 T.eq(calls,2,'finished battle cannot consume more Pickup RNG')
 f.close()
end
T.finish('GBA ordinary battle teardown runs Pickup once in all five editions')
