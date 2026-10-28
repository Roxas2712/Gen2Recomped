-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local P=require('src.core.game3.pokemon')
local Id=require('src.pokemon.Gen3PictureIdentity')
local original=package.loaded['src.core.Game']
T.eq(P.picSpecies(4),nil);T.eq(P.picBaseSpecies(413),nil)
for _,edition in ipairs{'firered','leafgreen','emerald','ruby','sapphire'}do
 local f=require('tools.battle-source-runtime.fixture').new(edition);local game=f.game
 package.loaded['src.core.Game']=game
 local data=game.data;local copy=require('src.mods.Merge').deepCopy
 local unown=copy(data.pokemon.CHARMANDER);unown.index,unown.dex,unown.id,unown.name=201,201,'UNOWN','UNOWN'
 data.pokemon.UNOWN=unown;data.constants.speciesOrder[201]='UNOWN'
 data.pokemon.SPARSE={index=277,dex=252,name='SPARSE'};data.constants.speciesOrder[277]='SPARSE'
 T.eq(P.picSpecies(4),4);T.eq(P.picSpecies('4'),4);T.eq(P.picSpecies('CHARMANDER'),4)
 T.eq(P.picSpecies(277),277);T.eq(P.picSpecies(252),nil,'National Dex numbers cannot replace cartridge slots')
 T.eq(P.picSpecies(8888),nil);T.eq(P.picBaseSpecies(8888),nil)
 for _,row in ipairs{{0,0},{1,1},{4,0},{256,4},{65536,16},{16777216,8},{4294967295,3},{-1,3}}do
  local personality,letter=row[1],row[2]
  T.eq(P.unownLetter(personality),letter)
  local slot=letter==0 and 201 or 412+letter
  T.eq(P.picSpecies(201,personality),slot)
  local base,form=P.picBaseSpecies(slot);T.eq(base,201);T.eq(form,letter)
 end
 for letter=1,27 do
  local base,form=P.picBaseSpecies(412+letter);T.eq(base,201);T.eq(form,letter)
 end
 T.eq(P.picSpecies(413),413,'picture-slot normalization is idempotent');T.eq(P.picBaseSpecies(440),nil);T.eq(P.picSpecies(201,0/0),nil)
 T.eq(P.picSpecies(201,math.huge),nil);T.eq(P.picSpecies(201,1.5),nil)
 local entry=assert(P.frontPic(4));T.eq(P.frontPic(P.picSpecies(4)),entry)
 T.eq(P.frontPic(413),nil,'unavailable variants cannot silently show Unown A')
 T.eq(P.frontPic(201,0,false,1),nil,'direct personality requests retain the same missing-art boundary')
 T.eq(P.backPic(413),nil)
 local previous=data.constants.speciesOrder
 data.pokemon.EXTRA={index=413,dex=600,name='EXTRA'};data.constants.speciesOrder=setmetatable({[413]='EXTRA'},{__index=previous})
 -- Copy actual entries: identity indices read the imported table, not its
 -- metatable, so both records are made explicit for this collision case.
 for n,k in pairs(previous)do data.constants.speciesOrder[n]=k end
 T.eq(P.picSpecies(201,1),nil,'art aliases cannot replace a registered logical species')
 T.eq(P.picBaseSpecies(413),413,'explicit native content keeps its existing identity')
 T.eq(P.picSpecies(413),413)
 local count=0;for _ in pairs(data.pokemon)do count=count+1 end
 for _=1,8 do P.picSpecies(4);P.picBaseSpecies(413)end
 local after=0;for _ in pairs(data.pokemon)do after=after+1 end;T.eq(after,count,'picture queries never create logical species')
 P.invalidate();f.close()
end
package.loaded['src.core.Game']=original
T.finish('native picture-slot identity, registered species, Unown bit selection and explicit missing-art boundaries')
