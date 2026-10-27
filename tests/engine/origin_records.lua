package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local O=require('src.pokemon.OriginRecord')
local mon={metLevel=0,metLocation=0}
O.stamp({version='ruby',player={gender='girl'}},mon,{level=0,location=0},true)
T.eq(mon.gen3MetGame,2,'new Ruby identities record Ruby instead of the exporter Emerald fallback')
T.eq(mon.otGender,1,'native original-trainer gender is retained')
T.eq(mon.metLevel,0,'the native hatch-level zero is preserved')
O.stamp({version='emerald',player={}},mon,{level=50,location=12},false)
T.eq(mon.gen3MetGame,2,'a destination does not rewrite the game of origin')
local unknown={}
O.stamp({version='emerald',player={}},unknown,{level=50,location=12},false)
T.eq(unknown.gen3MetGame,nil,'missing transferred history stays unknown')
local ds={};O.stamp({version='platinum',player={}},ds,{},true)
T.eq(ds.ndsGame,12,'new DS identities retain the edition origin number')
T.finish('Native origin records')
