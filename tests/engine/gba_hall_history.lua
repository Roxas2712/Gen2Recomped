-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local H=require('src.core.Gen3HallHistory');local S=require('src.core.SaveSerializer')
local V=require('src.core.GameVersion');local previous=V.get()
local data={pokemon={OWN_TREECKO={index=277},OWN_BULBASAUR={index=1}}}
local function session()
 return{party={{_hostMon={species='OWN_TREECKO'}},{_hostMon={species='OWN_BULBASAUR',isEgg=true}}},
  hallOfFameTeams={{{species=277,nickname='A%{B}',level=50,trainerId=0xABCD1234,otSecretId=123,personality=0xFEDCBA98},
   {species=412,nickname='EGG',level=5,trainerId=123,otSecretId=456,personality=7}}}}
end
local function scene(save)return{game={data=data,save=save},session=session(),saveEnding=true,savingDrawn=true}end
local save={hallOfFame=7,party={{species='OWN_TREECKO',hp=1,heldItem='LEFTOVERS'}},untouched='keep'}
local owner=scene(save);local before=S.encode(owner.session)
local record=H.recordScene(owner)
T.eq(save.hallOfFame,7,'induction count remains numeric and unchanged')
T.eq(record[1].species,'OWN_TREECKO','compact record uses stable host species ID')
T.eq(record[1].nickname,'A%{B}','custom nickname is preserved verbatim')
T.eq(record[1].trainerId,0xABCD1234,'full trainer identity survives')
T.eq(record[1].personality,0xFEDCBA98,'full personality survives')
T.eq(record[2].species,'OWN_BULBASAUR','egg retains its underlying host species identity')
T.eq(record[2].isEgg,true,'unhatched display status is recorded at induction')
T.eq(S.encode(owner.session),before,'recording never changes the native controller session')
T.eq(save.party[1].hp,1,'recording never heals or rewrites the live party')
T.eq(save.party[1].heldItem,'LEFTOVERS','held items are unaffected')
T.eq(H.recordScene(owner),record,'retry reuses the exact compact snapshot')
T.eq(#save.gen3HallOfFameTeams,1,'retry cannot append a second team')
owner.session.hallOfFameTeams[1][1].nickname='CHANGED';owner.session.party[2]._hostMon.isEgg=false
T.eq(record[1].nickname,'A%{B}','history is a snapshot, not a live native-party alias')
T.eq(record[2].isEgg,true,'later hatching cannot rewrite an old induction')
local stored=S.encode(save);local view=assert(H.nativeTeams(save,data))
T.eq(view[1][1].species,277,'native view maps stable ID back to cartridge index')
T.eq(view[1][2].species,412,'egg remains the original Hall egg species')
T.eq(view[1][1].nickname,'A%{B}','read-only view keeps the saved nickname')
T.eq(S.encode(save),stored,'building the PC view never writes the save')
T.eq(#H.nativeTeams({hallOfFame=9},data),0,'old count-only saves do not invent historic rosters')
local invalid=scene(save);invalid.session.hallOfFameTeams[1][1].species=999
T.eq(pcall(H.recordScene,invalid),false,'unsupported native species fails before history changes')
T.eq(S.encode(save),stored,'failed snapshot conversion preserves existing history')
local cap={hallOfFame=0}
for i=1,53 do
 local a=scene(cap);a.session.hallOfFameTeams[1][1].nickname='TEAM '..i;H.recordScene(a)
 T.eq(#cap.gen3HallOfFameTeams,math.min(i,50),'history keeps at most fifty teams')
end
T.eq(cap.gen3HallOfFameTeams[1][1].nickname,'TEAM 4','oldest three teams age out in order')
T.eq(cap.gen3HallOfFameTeams[50][1].nickname,'TEAM 53','newest team remains last')
-- All three actual native save bridges must record before IO, only once even
-- when a writer returns false or raises and the existing retry resumes.
for _,version in ipairs{'ruby','sapphire','emerald','firered','leafgreen'}do
 V.set(version)
 local family=version=='emerald'and'Emerald'or(version=='ruby'or version=='sapphire')and'Rs'or'Frlg'
 local UI=require('src.ui.Gen3'..family..'HallOfFame')
 local IO=require('src.core.Gen3'..family..'EndingSave');local write=IO.write;local calls=0
 local gameSave={hallOfFame=1};local a=scene(gameSave)
 IO.write=function(game)
  calls=calls+1;T.eq(game,a.game,'existing host IO retains ownership: '..version)
  T.eq(#gameSave.gen3HallOfFameTeams,1,'compact team exists before each save attempt')
  if calls==1 then return false,'RETURNED_FAILURE'end
  if calls==2 then error('RAISED_FAILURE')end
  return true
 end
 T.eq(UI.writeEnding(a),false,'returned failure keeps existing retry path')
 T.eq(pcall(UI.writeEnding,a),false,'raised write does not duplicate history')
 T.eq(UI.writeEnding(a),true,'successful retry saves the same record')
 T.eq(UI.writeEnding(a),true,'late repeated callback is harmless')
 T.eq(calls,3,'saved owner cannot issue another write')
 T.eq(#gameSave.gen3HallOfFameTeams,1,'exactly one history entry after all retries')
 T.eq(gameSave.hallOfFame,1,'history must not increment the induction count again')
 IO.write=write
end
V.set(previous)
T.finish('five-edition Hall roster snapshots, stable identities, fifty-team retention and idempotent atomic-save retries')
