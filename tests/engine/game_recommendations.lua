-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;'..package.path
local R=require('src.mods.GameRecommendations')
local checks=0
local function check(value,why)assert(value,why);checks=checks+1 end
local function entry(id,games,extra)
 local e={id=id,title=id,games=games,api=3,game_version='>=0.7.0 <1.0.0',downloadURL='https://example.test/'..id..'.zip'}
 for k,v in pairs(extra or {})do e[k]=v end
 return e
end
check(R.supports({games={'red','blue'}},'red'),'exact editions match')
check(not R.supports({games={'red','blue'}},'yellow'),'same generation does not override exact editions')
check(R.supports({games={'gen2'}},'crystal'),'generation tokens expand through the existing target service')
check(R.supports({games={'rse'}},'emerald'),'families expand without reading the mod title')
check(not R.supports({games={'gen3'},supportedGens={1}},'emerald'),'generation restriction intersects edition scope')
check(not R.supports({title='GEN 3 AMAZING MOD'},'emerald'),'titles never supply compatibility')
check(not R.supports({games={'unknown'}},'red'),'unknown game claims fail closed')
check(R.supports({compatibility={{engine='g1r'}}},'red')and not R.supports({compatibility={{engine='g1r'}}},'crystal'),'legacy G1R claim only targets Gen 1')
check(R.supports({},'red',true)and not R.supports({},'red',false),'installed legacy scope is preserved without recommending undeclared online mods')
for _,v in ipairs{'x','y','pinballrs','missing'}do check(not R.supports({games={'gen3','all'}},v,true),'RPG mods never leak into native cartridge '..v)end
check(not R.compatible(entry('api',{'red'},{api=99}),'red'),'unsupported API is excluded')
check(not R.compatible(entry('engine',{'red'},{game_version='>=99.0.0'}),'red'),'wrong engine is excluded')
check(not R.compatible(entry('bad',{'red'},{game_version='potato'}),'red'),'malformed engine range is excluded')
local own={id='owned',name='Owned',enabled=true,games={'red'},gens={false,true}}
local off={id='off',name='Disabled',enabled=false,games={'gen1'}}
local catalogue={mods={entry('owned',{'red'}),entry('other',{'blue'}),entry('ordinary',{'red'}),
 entry('featured',{'gen1'},{catalogueId='weekly'}),entry('experimental',{'red'},{experimental=true}),
 entry('beta',{'red'},{latest={prerelease=true}}),entry('source',{'red'},{update_check='no installable release'}),
 entry('error',{'red'},{update_check='error: offline'}),entry('disabled',{'red'},{update_check='off'}),entry('ordinary',{'red'})}}
local installed,recommended=R.select('red',{off,own,{id='blue-only',games={'blue'}}},catalogue,{catalogue_id='weekly'})
check(#installed==2 and not installed[1].enabled and not installed[2].enabled,'installed rows respect edition and per-generation activation')
check(#recommended==2 and recommended[1].entry.id=='featured'and recommended[1].weekly,'live weekly choice leads only compatible stable candidates')
check(recommended[2].entry.id=='ordinary','installed, duplicate, other-edition, prerelease and unavailable entries are excluded')
local _,blue=R.select('blue',{},catalogue,{catalogue_id='ordinary'})
check(blue[1].entry.id=='other'and not blue[1].weekly,'a weekly mod for another edition cannot escape the scope filter')
local _,none=R.select('red',{}, {mods={{id='no-source',games={'red'}}}})
check(#none==0,'a source-only catalogue row never gets an install recommendation')
local first={id='first',github='author/shared',games={'red'}}
local _,shared=R.select('red',{first},{mods={entry('second',{'red'},{github='AUTHOR/SHARED',_communityResolved=true}),
 entry('old-slug',{'red'},{github='author/shared',catalogueId='slug',resolveUrl='https://example.test/resolve'})}})
check(#shared==1 and shared[1].entry.id=='second','different resolved packages can share a repository; unresolved aliases of an installed package stay hidden')
local before=catalogue.mods[1]
R.select('red',{},catalogue)
check(catalogue.mods[1]==before and not catalogue.mods[1].weekly,'ranking never mutates catalogue order or entries')
local perGeneration={mods={}}
for gen=1,5 do perGeneration.mods[gen]=entry('generation-'..gen,{'gen'..gen})end
for gen,version in ipairs{'red','crystal','emerald','platinum','black'}do
 local _,rows=R.select(version,{},perGeneration)
 check(#rows==1 and rows[1].entry.id=='generation-'..gen,'recommendations stay inside actual generation '..gen)
end
print('Game recommendations: '..checks..' checks passed')
