package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.harness')
local O=require('src.pokemon.Gen3Ownership')
T.eq(O.fateful({}),nil,'unobserved events remain unknown')
local cases={
 {{ribbons=23},false,23},
 {{gen3Ribbons=2147483671},true,2147483671},
 {{ribbons=2147483671,modernFatefulEncounter=false},false,23},
 {{ribbons=23,modernFatefulEncounter=true},true,2147483671},
 {{fatefulEncounter=true},true,2147483648},
 {{ribbons=23,fatefulEncounter=true},false,23},
 {{gen3Ribbons=23,ribbons=2147483671},false,23},
}
local f=require('tests.enemy_actions.party_codec').fixture('.','gen2','firered','canonical')
local Protocol=require('src.link.Protocol')
for _,case in ipairs(cases)do
 local mon=require('src.pokemon.Pokemon').new(f.data,'CHARMANDER',12,function(lo)return lo or 0 end)
 for key,value in pairs(case[1])do mon[key]=value end
 T.eq(O.fateful(case[1]),case[2],'one canonical event interpretation')
 local word,flag=O.ribbonWord(case[1])
 T.eq(word,case[3],'preserve all low ribbon bits')
 T.eq(flag,case[2],'word and boolean agree')
 local packet=Protocol.packMon(mon)
 T.eq(packet.ribbons,case[3],'actual native link encodes effective ribbon word')
 T.eq(packet.modernFatefulEncounter,case[2],'modern wire flag matches ribbon')
 T.eq(packet.fatefulEncounter,case[2],'older wire alias matches ribbon')
 local received,why=Protocol.unpackMon(f.data,packet)
 T.check(received~=nil,'native packet decodes: '..tostring(why))
 T.eq(O.fateful(received),case[2],'event identity survives transfer')
 T.eq(received.gen3Ribbons,case[3],'native save alias survives transfer')
end
local Commands=require('src.script.Commands')
require('src.script.Gen3Commands')
local selected={ribbons=23}
local ctx={save={party={{ribbons=0},selected},gen3Vars={[0x8004]=1}},game=f.game}
Commands.g3_set_fateful(ctx,0x8004)
T.eq(selected.modernFatefulEncounter,true,'event script edits the selected actual party member')
T.eq(selected.gen3Ribbons,2147483671,'event script preserves existing ribbons')
T.eq(ctx.save.party[1].ribbons,0,'other party members keep their own event state')
Commands.g3_check_fateful(ctx,0x8004)
T.eq(ctx.save.gen3Vars[0x800D],1,'event script reads canonical modern state')
Commands.g3_check_fateful(ctx,0)
T.eq(ctx.save.gen3Vars[0x800D],0,'unmarked party slot reports false')
local G=require('src.save_convert.Gen3Save')
G.substructOrders={{0,1,2,3}}
local cw={pokemonIndex={CHARMANDER=4},movesIndex={},itemsIndex={}}
local box=G.buildBoxMon({species='CHARMANDER',level=12,personality=24,otId=7,secretId=8,
 ribbons=23,modernFatefulEncounter=true},cw,{name='OT',strictIdentity=true})
local decoded=G.decodeBoxMon(box,0)
T.eq(decoded.ribbons,2147483671,'actual native GBA export keeps event mark and lower ribbon bits')
f.close()
T.finish('Gen3 event identity across native links')
