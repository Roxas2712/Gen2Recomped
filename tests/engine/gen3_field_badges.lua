-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Rules=require('src.world.Gen3FieldRules')
local X=require('src.import.RomExtractorGen3')
local V=require('src.core.GameVersion')
local OW=require('src.world.OverworldController')
local Party=require('src.ui.Gen3PartyMenu')
local Serialize=require('src.core.SaveSerializer')
local numbers={CUT=15,FLASH=148,FLY=19,STRENGTH=70,SURF=57,ROCK_SMASH=249,WATERFALL=127,DIVE=291,DIG=91}
-- Independent native enum in pokefirered/include/constants/party_menu.h.
local kanto={FLASH=1,CUT=2,FLY=3,STRENGTH=4,SURF=5,ROCK_SMASH=6,WATERFALL=7}
local hoenn={CUT=1,FLASH=2,ROCK_SMASH=3,STRENGTH=4,SURF=5,FLY=6,DIVE=7,WATERFALL=8}
local function fixture(edition,scripts)
 local frlg=edition=='firered'or edition=='leafgreen'
 local order={};for id,n in pairs(numbers)do order[n]=id end
 local written
 local x=setmetatable({manifest={metatileAttributes={bytes=frlg and 4 or 2}},
  _constants={moveOrder=order,trainerOrder={[0]='PROBE'}},
  write=function(_,name,value)T.eq(name,'constants');written=value end},{__index=X})
 x:fieldMoveGates(scripts)
 return x._constants,written
end
for _,edition in ipairs{'ruby','sapphire','emerald','firered','leafgreen'}do
 V.set(edition)
 local frlg=edition=='firered'or edition=='leafgreen'
 local base=frlg and 0x820 or 0x867;local expected=frlg and kanto or hoenn
 local scripts={}
 for _,id in ipairs{'CUT','ROCK_SMASH','STRENGTH'}do
  scripts[id]={{'checkflag',base+expected[id]-1},{'checkflag',base+37},{'checkpartymove',numbers[id]}}
 end
 local constants,written=fixture(edition,scripts)
 T.eq(written,constants,'actual importer publishes the regional field gates')
 for id,n in pairs(expected)do
  local row=constants.gen3FieldMoves[id]
  T.eq(row.move,numbers[id]);T.eq(row.badge,n);T.eq(row.badgeFlag,base+n-1)
  T.eq(Rules.badgeNumber(edition,id),n)
 end
 if frlg then T.eq(constants.gen3FieldMoves.DIVE,nil,'Kanto has no DIVE field action')end
 T.eq(constants.gen3FieldMoves.DIG.move,91);T.eq(constants.gen3FieldMoves.DIG.badgeFlag,nil)
 for i=1,8 do T.eq(constants.gen3BadgeFlags[i],base+i-1)end
 for _,id in ipairs{'CUT','ROCK_SMASH','STRENGTH'}do T.eq(constants.gen3FieldMoves[id].fromScript,true)end
 local data={constants=constants};local bytes=Serialize.encode(data)
 for id,n in pairs(expected)do T.eq(Rules.badgeFlag(data,id,edition),base+n-1)end
 T.eq(Serialize.encode(data),bytes,'fresh metadata is never rewritten by runtime admission')
 -- The legacy extractor used the Hoenn order over the real regional block.
 local legacy={gen3FieldMoves={},gen3BadgeFlags=constants.gen3BadgeFlags}
 for id,n in pairs(hoenn)do legacy.gen3FieldMoves[id]={move=numbers[id],badge=n,badgeFlag=base+n-1}end
 data={constants=legacy};bytes=Serialize.encode(data)
 for id,n in pairs(expected)do T.eq(Rules.badgeFlag(data,id,edition),base+n-1,'legacy regional admission: '..edition..' '..id)end
 T.eq(Serialize.encode(data),bytes,'legacy repair is a view, never a cache or save write')
 local entry=legacy.gen3FieldMoves.FLY;entry.badgeFlag=1234
 T.eq(Rules.badgeFlag(data,'FLY',edition),1234,'an explicit custom flag is retained')
 entry.badgeFlag=nil;T.eq(Rules.badgeFlag(data,'FLY',edition),nil,'absent gates retain older optional metadata behavior')
 local empty=fixture(edition,{})
 T.eq(empty.gen3FieldMoves~=nil,frlg,'only Kanto has the audited fixed badge-block fallback')
 if frlg then T.eq(empty.gen3FieldMoves.FLY.badgeFlag,0x822);T.eq(empty.gen3FieldMoves.FLASH.badgeFlag,0x820)end
end
-- Exercise the actual host admission seam and actual party eligibility over
-- an unchanged legacy import, at the ordinary story's three-badge boundary.
local function bindGame(fn,game,seen)
 seen=seen or{};if seen[fn]then return end;seen[fn]=true
 for i=1,100 do
  local key,old=debug.getupvalue(fn,i);if not key then break end
  if key=='Game'then debug.setupvalue(fn,i,game);return function()debug.setupvalue(fn,i,old)end end
  if type(old)=='function'then local restore=bindGame(old,game,seen);if restore then return restore end end
 end
end
for _,edition in ipairs{'firered','leafgreen'}do
 V.set(edition)
 local moves={};for id,n in pairs(hoenn)do moves[id]={move=numbers[id],badge=n,badgeFlag=0x820+n-1}end
 local order={};for id,n in pairs(numbers)do order[n]=id end
 local game={data={constants={gen3FieldMoves=moves,moveOrder=order},field={flyOrder={'VISITED'}}},
  save={flags={},party={},inventory={HM02=1}}}
 local world={map={def={mapType=3,requiresFlash=true}},gen3HasBadge=OW.gen3HasBadge}
 game.overworld=world
 local mon={species='DODUO',level=18,hp=9,moves={{id='FLY',pp=15},{id='FLASH',pp=20}}};game.save.party={mon}
 local menu=setmetatable({game=game},{__index=Party})
 local restore=assert(bindGame(OW.gen3HasBadge,game))
 local original=Serialize.encode({game.save,game.data})
 for badge=1,8 do
  game.save.flags={[("FLAG_G3_%04X"):format(0x820+badge-1)]=true}
  T.eq(world:gen3HasBadge('FLY'),badge==3,'Fly requires Thunder, not Marsh')
  T.eq(menu:flyUsableBy(mon),badge==3,'actual party Fly eligibility uses the regional gate')
  T.eq(menu:flashUsableBy(mon),badge==1,'actual party Flash requires Boulder, not Cascade')
 end
 game.save.flags={FLAG_G3_0822=true};world.map.def.mapType='INDOOR'
 T.eq(menu:flyUsableBy(mon),false,'correct badge cannot bypass indoor travel refusal')
 world.map.def.mapType=3;mon.hp=0
 T.eq(menu:flyUsableBy(mon),true,'native field moves may be used by a fainted party member')
 mon.hp=9;game.save.flags={}
 T.eq(Serialize.encode({game.save,game.data}),original,'eligibility does not mutate moves, PP, inventory, flags or imported metadata')
 restore()
end
T.finish('GBA regional HM badge import, legacy admission and actual FRLG party gates')
