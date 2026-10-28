-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local original=package.loaded['src.core.Game']
local Catalog=require('src.battle.Gen3EffectCatalog')
local E=require('src.core.game3.battle.effect_ids')
T.eq(package.loaded['src.core.Game'],original,'constant import cannot bootstrap a game')
local file=assert(io.open('tests/fixtures/gba_move_effects.h','rb'))
local header=file:read('*a');file:close()
-- Parse the separately retained pinned C header, rather than deriving expected
-- positions from the runtime's compact name list. Keep unused slots too.
local reference,seen,count={},{},0
for name,value in header:gmatch('#define%s+EFFECT_([A-Z0-9_]+)%s+(%d+)')do
 local id=tonumber(value);reference[name]=id;count=count+1
 T.eq(seen[id],nil,'canonical IDs are unique');seen[id]=true
 T.eq(Catalog.id(name),id,'native ID matches public header: '..name)
 T.eq(Catalog.name(id),name,'native symbol matches public header: '..name)
 T.eq(E[name],id,'source constant matches the canonical native ID')
end
T.eq(count,214);T.eq(Catalog.count(),214)
for id=0,213 do T.eq(seen[id],true,'canonical dispatch retains slot '..id)end
local keys=0;for name,id in pairs(E)do keys=keys+1;T.eq(reference[name],id)end;T.eq(keys,214)
T.eq(E.HIT,0);T.check(E.HIT,'zero effect remains a real Lua constant')
for _,invalid in ipairs{-1,214,.5,0/0,math.huge,'0',false,{}}do T.eq(Catalog.name(invalid),nil)end
for _,invalid in ipairs{'hit','EFFECT_HIT','UNKNOWN',0,false,{}}do T.eq(Catalog.id(invalid),nil)end
local copy=Catalog.snapshot();copy.HIT=213;E.HIT=213
T.eq(Catalog.id('HIT'),0,'source/snapshot edits cannot change native authority')
T.eq(Catalog.snapshot().HIT,0);E.HIT=0
local Moves=require('src.core.game3.battle.moves')
for _,edition in ipairs{'firered','leafgreen','emerald','ruby','sapphire'}do
 local f=require('tools.battle-source-runtime.fixture').new(edition)
 package.loaded['src.core.Game']=f.game
 local key=f.ids.TACKLE;f.game.data.constants.moveOrder={[33]=key}
 local row=f.game.data.moves[key];row.effect='NATIVE_DISPATCH_NAME'
 for name,id in pairs(reference)do
  row.gen3Effect=id;local move=assert(Moves.get(33))
  T.eq(move.effect,E[name]);T.eq(move.effectSymbol,name)
  T.eq(move.nativeEffect,'NATIVE_DISPATCH_NAME','symbol observations do not rewrite native dispatch')
 end
 -- Unknown custom bytes remain usable metadata; a canonical name must not
 -- invent support or reinterpret a caller's native extension.
 row.gen3Effect=255;T.eq(Moves.get(33).effect,255);T.eq(Moves.get(33).effectSymbol,nil)
 row.gen3Effect=nil;T.eq(Moves.get(33).effectSymbol,nil)
 f.close()
end
package.loaded['src.core.Game']=original
T.finish('canonical native move-effect IDs, source snapshot isolation and live imported symbols')
