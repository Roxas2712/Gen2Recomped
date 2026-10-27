package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local V=require('src.core.GameVersion');local edition=assert(arg[2]);V.set(edition)
local captured={}
require('src.import.LuaWriter').write=function(path,value)captured[path:match('([^/]+)%.lua$')]=value;return true end
require('src.import.CacheFs').write=function()return true end
local IW=require('src.import.ImageWriter');IW.save=function()return true end;IW.fromRGBA8=function(w,h)return{width=w,height=h}end
local X=require(V.generation()==4 and'src.import.RomExtractorGen4'or'src.import.RomExtractorGen5')
local x=assert(X.new(assert(arg[1]),edition))
if x.runStages then x:runStages({'text','species','moves','items','constants'})else x:run()end
x:close()
local data=T.fixtures.fresh();for k,v in pairs(captured)do data[k]=v end
require('src.pokemon.SpeciesRecords').species(data.pokemon);require('src.pokemon.SpeciesRecords').constants(data.constants)
T.sdk.loadNone({data=data});require('src.battle.TypeChart').load(data);T.link.prepare(data)
local ga=T.link.fakeGame(data,25,{name='HOST',level=50});local gb=T.link.fakeGame(data,19,{name='GUEST',level=50})
love.data={hash=function(_,bytes)return require('src.link.Fingerprint').digest(bytes)end,encode=function(_,_,bytes)return bytes end}
for _,game in ipairs({ga,gb})do
 local mon=game.save.party[1];local found
 for i,m in ipairs(mon.moves)do if(data.moves[m.id].power or 0)>0 then found=i;break end end
 assert(found,'A native damaging move is required');mon.moves[1],mon.moves[found]=mon.moves[found],mon.moves[1]
end
local P=require('src.link.Protocol');local L=require('src.link.LinkBattle')
local pa,pb=P.packParty(ga.save.party),P.packParty(gb.save.party)
local na,nb=require('src.link.Net').loopbackPair();local proofs={}
local a=assert(L.newHost(ga,na,{myParty=pa,theirParty=pb,seed=327,forceLevel=50,strict=true,onFinished=function(r)proofs[1]=r end}))
local b=assert(L.newGuest(gb,nb,{myParty=pb,theirParty=pa,seed=327,forceLevel=50,strict=true,onFinished=function(r)proofs[2]=r end}))
ga.stack:push(a);gb.stack:push(b)
for _=1,200000 do
 ga.input.pressed={a=true};ga.stack:update(1/60);gb.input.pressed={a=true};gb.stack:update(1/60)
 if proofs[1]and proofs[2]then break end
end
assert(proofs[1]and proofs[2],'The native DS battle did not complete')
assert(proofs[1].digest==proofs[2].digest,'Native DS participants diverged')
assert(proofs[1].result~=proofs[2].result and proofs[1].result~='draw','DS battle ended without a native winner')
print('NATIVE_DS_LINK_PROOF '..require('src.link.Json').encode(proofs))
T.finish('Native DS link battle')
