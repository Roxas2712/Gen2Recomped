-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local V=require('src.core.GameVersion')
for _,edition in ipairs{'firered','leafgreen','ruby','sapphire','emerald'}do
 local f=require('tests.checkpoint_fixture').boot(edition,3);local g,w=f.game,f.world
 g.data.field.cardKeyDoors={closedDoors={FIX_TOWN={{bx=3,by=3,block=1,open=0,event='OWNED_OPEN'}}}}
 g.save.flags.OWNED_OPEN=true
 for _,case in ipairs{{source='RomExtractorGen3',registered=true,keep=true},
  {source='authored',registered=true,keep=false},
  {source='RomExtractorGen3',registered=false,keep=false}}do
  g.data.map_scripts={source=case.source,maps=case.registered and{FIX_TOWN={}}or{}}
  w.map:setBlock(3,3,1,false)
  local before=require('src.core.SaveSerializer').encode(g.save)
  w:stampClosedDoors()
  T.eq(w.map:blockAt(3,3),case.keep and V.isFRLG()and 1 or 0,'native FRLG scripts own their door art; Hoenn and authored maps retain their existing door rules')
  T.eq(w.map:cellCollision(3,3),0,'native and authored door permissions remain open')
  T.eq(require('src.core.SaveSerializer').encode(g.save),before,'door admission cannot rewrite the save')
 end
 for _,other in ipairs{'red','crystal'}do
  V.set(other);g.data.map_scripts={source='RomExtractorGen3',maps={FIX_TOWN={}}}
  w.map:setBlock(3,3,1,false);w:stampClosedDoors()
  T.eq(w.map:blockAt(3,3),0,'Game Boy door callbacks retain their existing owner')
 end
 V.set(edition);f.close()
end
T.finish('Native FRLG script door ownership after battle, authored fallback and other-edition isolation')
